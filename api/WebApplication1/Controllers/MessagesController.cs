using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WebApplication1.Data;
using WebApplication1.DTOs;
using System.Threading.Tasks;
using WebApplication1.Models;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace WebApplication1.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class MessagesController : ControllerBase
    {
        private readonly AppDbContext _context;

        public MessagesController(AppDbContext context)
        {
            _context = context;
        }

        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // PUT: api/messages/5
        [HttpPut("{messageId}")]
        public async Task<IActionResult> EditMessage(long messageId, [FromBody] string newText)
        {
            if (string.IsNullOrWhiteSpace(newText)) return BadRequest("Текст сообщения не может быть пустым.");

            var message = await _context.Messages.FindAsync(messageId);
            if (message == null || message.IsDeleted) return NotFound();

            // 🛡️ Только автор может редактировать
            if (message.SenderUserID != CurrentUserId) return Forbid();

            // 🛡️ Ограничения: только текстовые сообщения, лимит 48 часов
            if (message.MessageType != "Text") return BadRequest("Редактировать можно только текст.");
            if (message.SentAt < DateTime.UtcNow.AddHours(-48)) return BadRequest("Время для редактирования истекло (48ч).");
            if (message.IsViewOnce) return BadRequest("Одноразовые сообщения нельзя редактировать.");

            // Сохраняем историю
            _context.MessageHistories.Add(new MessageHistory
            {
                MessageID = messageId,
                OldContent = message.ContentText,
                EditedAt = DateTime.UtcNow
            });

            message.ContentText = newText;
            message.IsEdited = true;
            await _context.SaveChangesAsync();

            return Ok(new { success = true });
        }

        // DELETE: api/messages/5
        [HttpDelete("{messageId}")]
        public async Task<IActionResult> DeleteMessage(long messageId)
        {
            var message = await _context.Messages.Include(m => m.Chat).FirstOrDefaultAsync(m => m.MessageID == messageId);
            if (message == null || message.IsDeleted) return NotFound();

            // 🛡️ Проверяем участие в чате
            var isParticipant = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId);
            if (!isParticipant) return Forbid();

            // 🛡️ Удаление для всех: Только автор сообщения или админ группы может удалить
            bool canDeleteForEveryone = message.SenderUserID == CurrentUserId;
            
            if (!canDeleteForEveryone && message.Chat.IsGroup)
            {
                var isAdmin = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId && cp.IsAdmin);
                canDeleteForEveryone = isAdmin;
            }

            if (!canDeleteForEveryone) return Forbid();

            // 🛡️ Удаление файлов с диска (если есть ImageUrl)
            if (!string.IsNullOrEmpty(message.ImageUrl))
            {
                try {
                    var fileName = Path.GetFileName(message.ImageUrl);
                    var filePath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", fileName);
                    if (System.IO.File.Exists(filePath)) System.IO.File.Delete(filePath);
                } catch { /* Игнорируем ошибки удаления файла */ }
            }

            message.IsDeleted = true;
            await _context.SaveChangesAsync();

            return Ok(new { success = true });
        }

        // PUT: api/messages/5/pin
        [HttpPut("{messageId}/pin")]
        public async Task<IActionResult> TogglePin(long messageId)
        {
            var message = await _context.Messages.Include(m => m.Chat).FirstOrDefaultAsync(m => m.MessageID == messageId);
            if (message == null || message.IsDeleted) return NotFound();

            // 🛡️ Проверяем, что юзер вообще в этом чате (ЗАЩИТА ОТ IDOR)
            var isParticipant = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId);
            if (!isParticipant) return Forbid();

            // 🛡️ В группах только админ может пинить. В личках - оба.
            if (message.Chat.IsGroup)
            {
                var isAdmin = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId && cp.IsAdmin);
                if (!isAdmin) return Forbid();
            }

            message.IsPinned = !message.IsPinned;
            await _context.SaveChangesAsync();

            return Ok(new { success = true, isPinned = message.IsPinned });
        }

        // POST: api/messages/5/reactions
        [HttpPost("{messageId}/reactions")]
        public async Task<IActionResult> ToggleReaction(long messageId, [FromBody] string emoji)
        {
            if (string.IsNullOrWhiteSpace(emoji)) return BadRequest();

            var message = await _context.Messages.FindAsync(messageId);
            if (message == null || message.IsDeleted) return NotFound();

            // Проверяем, что юзер в этом чате
            var isParticipant = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId);
            if (!isParticipant) return Forbid();

            var existingReaction = await _context.MessageReactions
                .FirstOrDefaultAsync(r => r.MessageID == messageId && r.UserID == CurrentUserId && r.Emoji == emoji);

            if (existingReaction != null)
            {
                _context.MessageReactions.Remove(existingReaction);
                await _context.SaveChangesAsync();
                return Ok(new { action = "removed", emoji });
            }
            else
            {
                // Можно добавить логику: один юзер - один эмодзи (удалить старые если есть)
                // Но пока разрешим несколько разных эмодзи от одного юзера
                var reaction = new MessageReaction
                {
                    MessageID = messageId,
                    UserID = CurrentUserId,
                    Emoji = emoji
                };
                _context.MessageReactions.Add(reaction);
                await _context.SaveChangesAsync();
                return Ok(new { action = "added", emoji });
            }
        }

        // GET: api/messages/search?query=hello
        [HttpGet("search")]
        public async Task<IActionResult> SearchMessages([FromQuery] string query)
        {
            if (string.IsNullOrWhiteSpace(query)) return BadRequest();

            // Ищем сообщения во всех чатах, где состоит пользователь
            var userChatIds = await _context.ChatParticipants
                .Where(cp => cp.UserID == CurrentUserId)
                .Select(cp => cp.ChatID)
                .ToListAsync();

            var messages = await _context.Messages
                .Where(m => userChatIds.Contains(m.ChatID) && !m.IsDeleted && m.ContentText != null && m.ContentText.Contains(query))
                .OrderByDescending(m => m.SentAt)
                .Select(m => new
                {
                    m.MessageID,
                    m.ChatID,
                    ChatName = m.Chat.IsGroup ? m.Chat.GroupName : 
                               m.Chat.Participants.Where(p => p.UserID != CurrentUserId).Select(p => p.User.DisplayName).FirstOrDefault() ?? "Личный чат",
                    m.SenderUserID,
                    SenderName = m.SenderUser.DisplayName,
                    m.ContentText,
                    m.SentAt,
                    m.MessageType
                })
                .Take(50)
                .ToListAsync();

            return Ok(messages);
        }

        // POST: api/messages/5/view-once
        [HttpPost("{messageId}/view-once")]
        public async Task<IActionResult> MarkViewOnceAsViewed(long messageId)
        {
            var message = await _context.Messages.FindAsync(messageId);
            if (message == null) return NotFound();

            // Проверка участия
            var isParticipant = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId);
            if (!isParticipant) return Forbid();

            if (message.IsViewOnce && message.ViewedAt == null)
            {
                message.ViewedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }

            return Ok(new { success = true });
        }

        // POST: api/messages/5/translate
        [HttpPost("{messageId}/translate")]
        public async Task<IActionResult> TranslateMessage(long messageId)
        {
            var message = await _context.Messages.FindAsync(messageId);
            if (message == null) return NotFound();

            // 🛡️ Проверка участия (IDOR FIX)
            var isParticipant = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId);
            if (!isParticipant) return Forbid();

            if (string.IsNullOrEmpty(message.ContentText)) return BadRequest("Нет текста для перевода");

            // 🪄 Имитация перевода (или интеграция с внешним API)
            // В реальности здесь будет вызов Google Translate или DeepL
            message.TranslatedText = "[Перевод: EN -> RU] " + message.ContentText;
            await _context.SaveChangesAsync();

            return Ok(new { translatedText = message.TranslatedText });
        }
        // POST: api/messages/5/transcribe
        [HttpPost("{messageId}/transcribe")]
        public async Task<IActionResult> TranscribeMessage(long messageId)
        {
            var message = await _context.Messages.FindAsync(messageId);
            if (message == null) return NotFound();

            // 🛡️ Проверка участия
            var isParticipant = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId);
            if (!isParticipant) return Forbid();

            if (message.MessageType != "Audio" && message.MessageType != "VoiceNote") 
                return BadRequest("Сообщение не является голосовым.");

            if (!string.IsNullOrEmpty(message.TranscriptionText))
                return Ok(new { transcription = message.TranscriptionText });

            // 🪄 Имитация расшифровки (Speech-to-Text)
            string mockTranscription = "Это расшифрованное голосовое сообщение. В реальности здесь будет текст, полученный через Whisper AI.";
            
            message.TranscriptionText = mockTranscription;
            await _context.SaveChangesAsync();

            return Ok(new { transcription = message.TranscriptionText });
        }

        // GET: api/messages/5/history
        [HttpGet("{messageId}/history")]
        public async Task<IActionResult> GetEditHistory(long messageId)
        {
            var message = await _context.Messages.FindAsync(messageId);
            if (message == null) return NotFound();

            var isParticipant = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId);
            if (!isParticipant) return Forbid();

            var history = await _context.MessageHistories
                .Where(h => h.MessageID == messageId)
                .OrderByDescending(h => h.EditedAt)
                .Select(h => new { Content = h.OldContent, EditedAt = h.EditedAt })
                .ToListAsync();

            return Ok(history);
        }
    }
}