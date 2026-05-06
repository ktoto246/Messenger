using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WebApplication1.Data;
using WebApplication1.DTOs;
using WebApplication1.Models;
using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using WebApplication1.Services;

namespace WebApplication1.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize] // 🛡️ Включаем авторизацию для всех методов
    public class ChatsController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly PushNotificationService _pushService;
        private readonly Microsoft.AspNetCore.SignalR.IHubContext<WebApplication1.Hubs.ChatHub> _hubContext;

        public ChatsController(AppDbContext context, PushNotificationService pushService, Microsoft.AspNetCore.SignalR.IHubContext<WebApplication1.Hubs.ChatHub> hubContext)
        {
            _context = context;
            _pushService = pushService;
            _hubContext = hubContext;
        }

        // Хелпер для получения ID текущего пользователя из JWT
        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // ==========================================
        // 1. ПОЛУЧЕНИЕ СПИСКА ЧАТОВ
        // ==========================================
        [HttpGet]
        public async Task<IActionResult> GetChats()
        {
            var userId = CurrentUserId; // Берем из токена, а не из параметров

            var chats = await _context.ChatParticipants
                .Where(cp => cp.UserID == userId)
                .Select(cp => new
                {
                    cp.Chat.ChatID,
                    cp.Chat.IsGroup,
                    cp.Chat.GroupName,
                    cp.IsPinned,
                    OtherUser = cp.Chat.Participants
                        .Where(p => p.UserID != userId)
                        .Select(p => new
                        {
                            p.User.UserID,
                            p.User.DisplayName,
                            p.User.AvatarUrl,
                            p.User.IsOnline,
                            p.User.LastActive
                        })
                        .FirstOrDefault(),
                    cp.Chat.AvatarUrl,
                    LastMessageText = cp.Chat.Messages
                        .OrderByDescending(m => m.SentAt)
                        .Select(m => m.ContentText)
                        .FirstOrDefault(),
                    LastMessageTime = cp.Chat.Messages
                        .OrderByDescending(m => m.SentAt)
                        .Select(m => (DateTime?)m.SentAt)
                        .FirstOrDefault(),
                    UnreadCount = cp.Chat.Messages
                        .Count(m => m.SenderUserID != userId && !m.IsRead)
                })
                .ToListAsync();

            var result = chats.Select(x => new
            {
                ChatId = x.ChatID,
                ChatName = x.IsGroup ? x.GroupName : (x.OtherUser?.DisplayName ?? "Unknown"),
                AvatarUrl = x.IsGroup ? x.AvatarUrl : x.OtherUser?.AvatarUrl,
                OtherUserId = x.IsGroup ? null : (int?)x.OtherUser?.UserID,
                IsOnline = x.IsGroup ? false : (x.OtherUser?.IsOnline ?? false),
                LastActive = x.IsGroup ? null : x.OtherUser?.LastActive,
                LastMessage = x.LastMessageText ?? "",
                LastMessageTime = x.LastMessageTime,
                UnreadCount = x.UnreadCount,
                IsPinned = x.IsPinned
            })
            .OrderByDescending(x => x.LastMessageTime)
            .ToList();

            return Ok(result);
        }

        // ==========================================
        // 2. ИСТОРИЯ СООБЩЕНИЙ В ЧАТЕ
        // ==========================================
        [HttpGet("{chatId}/messages")]
        public async Task<IActionResult> GetMessages(int chatId, [FromQuery] int skip = 0, [FromQuery] int take = 30)
        {
            // 🛡️ Проверка: является ли пользователь участником этого чата
            var isParticipant = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId);
            if (!isParticipant) return Forbid();

            var rawMessages = await _context.Messages
                .Where(m => m.ChatID == chatId && (m.ScheduledAt == null || m.ScheduledAt <= DateTime.UtcNow))
                .OrderByDescending(m => m.SentAt)
                .Skip(skip)
                .Take(take)
                .Include(m => m.SenderUser) // 🛡️ Загружаем отправителя
                .ToListAsync();

            var messages = rawMessages.Select(m => {
                // Безопасно достаем данные ответа
                string? replyText = null;
                string? replySender = null;
                
                if (m.ReplyToMessageId != null) {
                    var rMsg = _context.Messages.Include(x => x.SenderUser).FirstOrDefault(x => x.MessageID == m.ReplyToMessageId);
                    if (rMsg != null) {
                        replySender = rMsg.SenderUser?.DisplayName;
                        replyText = !string.IsNullOrEmpty(rMsg.ContentText) ? rMsg.ContentText : 
                                    (rMsg.MessageType == "Image" ? "📷 Фотография" : "📎 Медиафайл");
                    }
                }

                return new {
                    m.MessageID,
                    m.SenderUserID,
                    m.ContentText,
                    m.SentAt,
                    m.IsRead,
                    m.IsEdited,
                    m.ImageUrl,
                    m.IsPinned,
                    m.MessageType,
                    m.ReplyToMessageId,
                    ReplyToMessageText = replyText,
                    ReplyToMessageSender = replySender,
                    Reactions = _context.MessageReactions
                        .Where(r => r.MessageID == m.MessageID)
                        .GroupBy(r => r.Emoji)
                        .Select(g => new { Emoji = g.Key, Count = g.Count(), UserReacted = g.Any(r => r.UserID = CurrentUserId) })
                        .ToList(),
                    m.IsViewOnce,
                    IsExpired = m.IsViewOnce && m.ViewedAt != null,
                    m.TranslatedText
                };
            }).ToList();

            return Ok(messages);
        }

        // ==========================================
        // 3. ОТПРАВКА СООБЩЕНИЯ
        // ==========================================
        [HttpPost("{chatId}/messages")]
        public async Task<IActionResult> SendMessage(int chatId, [FromBody] SendMessageDto dto)
        {
            // 🛡️ Проверка участия
            var isParticipant = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId);
            if (!isParticipant) return Forbid();

            // 📢 Проверка Канала (только админы пишут)
            var chat = await _context.Chats.FindAsync(chatId);
            if (chat != null && chat.IsChannel)
            {
                var participant = await _context.ChatParticipants.FirstOrDefaultAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId);
                if (participant == null || !participant.IsAdmin) return Forbid();
            }

            var newMessage = new Message
            {
                ChatID = chatId,
                SenderUserID = CurrentUserId, 
                ContentText = dto.Content ?? "",
                SentAt = dto.ScheduledAt ?? DateTime.UtcNow,
                ScheduledAt = dto.ScheduledAt, // Если есть - планируем
                IsRead = false,
                IsEdited = false,
                ImageUrl = dto.MediaUrl,
                ReplyToMessageId = dto.ReplyToMessageId,
                MessageType = dto.MessageType,
                IsViewOnce = dto.IsViewOnce
            };

            _context.Messages.Add(newMessage);
            await _context.SaveChangesAsync();

            // ⚡️ РЕАЛЬНОЕ ВРЕМЯ (SignalR): Уведомляем участников чата
            await _hubContext.Clients.Group(chatId.ToString()).SendAsync("ReceiveMessage");

            // 🔔 ОТПРАВКА PUSH-УВЕДОМЛЕНИЙ
            _ = Task.Run(async () => {
                try {
                    var participants = await _context.ChatParticipants
                        .Where(cp => cp.ChatID == chatId && cp.UserID != CurrentUserId)
                        .Include(cp => cp.User)
                        .ToListAsync();

                    var tokens = participants
                        .Where(p => !string.IsNullOrEmpty(p.User.FcmToken))
                        .Select(p => p.User.FcmToken)
                        .ToList();

                    if (tokens.Any()) {
                        // 🔔 РЕАЛЬНАЯ ОТПРАВКА ЧЕРЕЗ СЕРВИС
                        var sender = await _context.Users.FindAsync(CurrentUserId);
                        var chat = await _context.Chats.FindAsync(chatId);
                        string title = chat?.IsGroup == true ? (chat.GroupName ?? "Группа") : (sender?.DisplayName ?? "Новое сообщение");
                        string body = chat?.IsGroup == true ? $"{sender?.DisplayName}: {newMessage.ContentText}" : (newMessage.ContentText ?? "Медиафайл");
                        
                        await _pushService.SendNotificationAsync(tokens, title, body, newMessage.ImageUrl);
                    }
                } catch { /* Игнорируем ошибки пушей */ }
            });

            return Ok(newMessage);
        }

        // ==========================================
        // 4. ПРОЧИТАТЬ СООБЩЕНИЯ
        // ==========================================
        [HttpPost("{chatId}/read")]
        public async Task<IActionResult> MarkAsRead(int chatId)
        {
            var userId = CurrentUserId;
            var unreadMessages = await _context.Messages
                .Where(m => m.ChatID == chatId && m.SenderUserID != userId && !m.IsRead)
                .ToListAsync();

            if (unreadMessages.Any())
            {
                foreach (var msg in unreadMessages)
                {
                    msg.IsRead = true;
                }
                await _context.SaveChangesAsync();
            }

            return Ok();
        }

        // ==========================================
        // 5. СОЗДАНИЕ ПРИВАТНОГО ЧАТА
        // ==========================================
        [HttpPost("private")]
        public async Task<IActionResult> CreatePrivateChat([FromBody] int targetUserId)
        {
            var currentUserId = CurrentUserId;

            var targetUserExists = await _context.Users.AnyAsync(u => u.UserID == targetUserId);
            if (!targetUserExists) return BadRequest("Пользователь не найден");

            var existingChat = await _context.Chats
                .Where(c => !c.IsGroup &&
                       c.Participants.Any(p => p.UserID == currentUserId) &&
                       c.Participants.Any(p => p.UserID == targetUserId))
                .FirstOrDefaultAsync();

            if (existingChat != null) return Ok(new { chatId = existingChat.ChatID });

            var newChat = new Chat { IsGroup = false };
            _context.Chats.Add(newChat);
            await _context.SaveChangesAsync();

            _context.ChatParticipants.Add(new ChatParticipant { ChatID = newChat.ChatID, UserID = currentUserId });
            _context.ChatParticipants.Add(new ChatParticipant { ChatID = newChat.ChatID, UserID = targetUserId });
            await _context.SaveChangesAsync();

            return Ok(new { chatId = newChat.ChatID });
        }

        // ==========================================
        // ЗАГРУЗКА КАРТИНКИ (С ПРОВЕРКОЙ)
        // ==========================================
        [HttpPost("uploadMedia")]
        public async Task<IActionResult> UploadMedia(IFormFile file)
        {
            if (file == null || file.Length == 0) return BadRequest("Файл пуст");
            
            // 🛡️ Ограничение размера (50MB)
            if (file.Length > 50 * 1024 * 1024) return BadRequest("Файл слишком большой");

            // 🛡️ Белый список расширений
            var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".mp4", ".mp3", ".wav" };
            var extension = Path.GetExtension(file.FileName).ToLower();
            if (!allowedExtensions.Contains(extension)) return BadRequest("Недопустимый тип файла");

            var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads");
            if (!Directory.Exists(uploadsFolder)) Directory.CreateDirectory(uploadsFolder);
            
            var uniqueFileName = Guid.NewGuid().ToString() + extension;
            var filePath = Path.Combine(uploadsFolder, uniqueFileName);

            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }
            return Ok(new { mediaUrl = $"/uploads/{uniqueFileName}" });
        }

        [HttpPut("{chatId}/pin")]
        public async Task<IActionResult> TogglePinChat(int chatId)
        {
            var participant = await _context.ChatParticipants
                .FirstOrDefaultAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId);

            if (participant == null) return NotFound();

            participant.IsPinned = !participant.IsPinned;
            await _context.SaveChangesAsync();
            return Ok(new { isPinned = participant.IsPinned });
        }

        [HttpDelete("{chatId}")]
        public async Task<IActionResult> DeleteChat(int chatId)
        {
            var participant = await _context.ChatParticipants
                .FirstOrDefaultAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId);

            if (participant == null) return NotFound();

            _context.ChatParticipants.Remove(participant);
            await _context.SaveChangesAsync();

            // 🛡️ Очистка "осиротевших" чатов
            var remainingParticipants = await _context.ChatParticipants.CountAsync(cp => cp.ChatID == chatId);
            if (remainingParticipants == 0)
            {
                var chat = await _context.Chats.FindAsync(chatId);
                if (chat != null) _context.Chats.Remove(chat);
                await _context.SaveChangesAsync();
            }

            return Ok(new { success = true });
        }

        [HttpPost("saved-messages")]
        public async Task<IActionResult> GetOrCreateSavedMessages()
        {
            var userId = CurrentUserId;
            var savedChat = await _context.Chats
                .Include(c => c.Participants)
                .Where(c => c.IsGroup == false && c.Participants.Count == 1 && c.Participants.Any(p => p.UserID == userId))
                .FirstOrDefaultAsync();

            if (savedChat != null) return Ok(new { chatId = savedChat.ChatID });

            var newChat = new Chat { IsGroup = false };
            _context.Chats.Add(newChat);
            await _context.SaveChangesAsync(); 

            _context.ChatParticipants.Add(new ChatParticipant { ChatID = newChat.ChatID, UserID = userId });
            await _context.SaveChangesAsync();
            return Ok(new { chatId = newChat.ChatID });
        }

        [HttpPost("group")]
        public async Task<IActionResult> CreateGroupChat([FromBody] CreateGroupRequest request)
        {
            var chat = new Chat { IsGroup = true, GroupName = request.GroupName };
            _context.Chats.Add(chat);
            await _context.SaveChangesAsync();

            _context.ChatParticipants.Add(new ChatParticipant { ChatID = chat.ChatID, UserID = CurrentUserId, IsAdmin = true });

            // 🛡️ Защита от несуществующих пользователей (Фантомов)
            var validUserIds = await _context.Users
                .Where(u => request.MemberUserIds.Contains(u.UserID))
                .Select(u => u.UserID)
                .ToListAsync();

            foreach (var userId in validUserIds)
            {
                if (userId != CurrentUserId)
                {
                    _context.ChatParticipants.Add(new ChatParticipant { ChatID = chat.ChatID, UserID = userId });
                }
            }
            await _context.SaveChangesAsync();
            return Ok(new { chatId = chat.ChatID });
        }

        [HttpGet("{chatId}/members")]
        public async Task<IActionResult> GetMembers(int chatId)
        {
            // 🛡️ Проверка участия
            var isParticipant = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId);
            if (!isParticipant) return Forbid();

            var members = await _context.ChatParticipants
                .Where(cp => cp.ChatID == chatId)
                .Select(cp => new { cp.UserID, cp.User.DisplayName, cp.User.AvatarUrl, cp.IsAdmin, cp.User.IsOnline, cp.User.LastActive })
                .ToListAsync();

            return Ok(members);
        }

        [HttpPut("{chatId}")]
        public async Task<IActionResult> UpdateGroup(int chatId, [FromBody] UpdateGroupDto dto)
        {
            // 🛡️ Проверка на Админа
            var admin = await _context.ChatParticipants.FirstOrDefaultAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId && cp.IsAdmin);
            if (admin == null) return Forbid();

            var chat = await _context.Chats.FindAsync(chatId);
            if (chat == null || !chat.IsGroup) return NotFound();

            if (!string.IsNullOrEmpty(dto.GroupName)) chat.GroupName = dto.GroupName;
            if (!string.IsNullOrEmpty(dto.AvatarUrl)) chat.AvatarUrl = dto.AvatarUrl;

            await _context.SaveChangesAsync();
            return Ok(new { chat.ChatID, chat.GroupName, chat.AvatarUrl });
        }

        [HttpPost("{chatId}/participants")]
        public async Task<IActionResult> AddParticipants(int chatId, [FromBody] List<int> userIds)
        {
            // 🛡️ Проверка на Админа
            var admin = await _context.ChatParticipants.FirstOrDefaultAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId && cp.IsAdmin);
            if (admin == null) return Forbid();

            // 🛡️ Защита от несуществующих пользователей
            var validUserIds = await _context.Users
                .Where(u => userIds.Contains(u.UserID))
                .Select(u => u.UserID)
                .ToListAsync();

            foreach (var userId in validUserIds)
            {
                if (!await _context.ChatParticipants.AnyAsync(p => p.ChatID == chatId && p.UserID == userId))
                {
                    _context.ChatParticipants.Add(new ChatParticipant { ChatID = chatId, UserID = userId });
                }
            }

            await _context.SaveChangesAsync();
            return Ok(new { success = true });
        }

        [HttpDelete("{chatId}/participants/{userId}")]
        public async Task<IActionResult> KickParticipant(int chatId, int userId)
        {
            // 🛡️ Проверка на Админа
            var admin = await _context.ChatParticipants.FirstOrDefaultAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId && cp.IsAdmin);
            if (admin == null) return Forbid();

            var participant = await _context.ChatParticipants.FirstOrDefaultAsync(cp => cp.ChatID == chatId && cp.UserID == userId);
            if (participant == null) return NotFound();

            _context.ChatParticipants.Remove(participant);
            await _context.SaveChangesAsync();
            return Ok(new { success = true });
        }

        public class UpdateGroupDto { public string? GroupName { get; set; } public string? AvatarUrl { get; set; } }
        public class CreateGroupRequest { public string GroupName { get; set; } = string.Empty; public List<int> MemberUserIds { get; set; } = new(); }
    }
}