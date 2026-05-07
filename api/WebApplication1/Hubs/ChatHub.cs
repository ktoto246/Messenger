using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using WebApplication1.Data;
using System.Security.Claims;

namespace WebApplication1.Hubs
{
    [Authorize] // 🛡️ Только авторизованные могут подключаться к сокетам
    public class ChatHub : Hub
    {
        private readonly AppDbContext _context;

        public ChatHub(AppDbContext context)
        {
            _context = context;
        }

        private int CurrentUserId => int.Parse(Context.User!.FindFirstValue(ClaimTypes.NameIdentifier)!);

        public override async Task OnConnectedAsync()
        {
            var user = await _context.Users.FindAsync(CurrentUserId);
            if (user != null)
            {
                user.IsOnline = true;
                user.LastActive = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var user = await _context.Users.FindAsync(CurrentUserId);
            if (user != null)
            {
                // Мы не сбрасываем IsOnline сразу, так как может быть переподключение
                // Но для простоты пока сбросим. OnlineStatusWorker подстрахует.
                user.IsOnline = false;
                user.LastActive = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }
            await base.OnDisconnectedAsync(exception);
        }

        public async Task Heartbeat()
        {
            var user = await _context.Users.FindAsync(CurrentUserId);
            if (user != null)
            {
                user.LastActive = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }
        }

        public async Task JoinChat(string chatIdStr)
        {
            if (int.TryParse(chatIdStr, out int chatId))
            {
                // 🛡️ Проверка: является ли пользователь участником этого чата
                var isParticipant = await _context.ChatParticipants
                    .AnyAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId);

                if (isParticipant)
                {
                    await Groups.AddToGroupAsync(Context.ConnectionId, chatIdStr);
                }
            }
        }

        public async Task LeaveChat(string chatId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, chatId);
        }

        public async Task Typing(string chatIdStr, int userId)
        {
            if (int.TryParse(chatIdStr, out int chatId) && userId == CurrentUserId)
            {
                var isParticipant = await _context.ChatParticipants
                    .AnyAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId);

                if (isParticipant)
                {
                    await Clients.Group(chatIdStr).SendAsync("UserTyping", chatIdStr, userId);
                }
            }
        }

        public async Task SendReaction(string chatIdStr, long messageId)
        {
            if (int.TryParse(chatIdStr, out int chatId))
            {
                var isParticipant = await _context.ChatParticipants
                    .AnyAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId);

                if (isParticipant)
                {
                    await Clients.Group(chatIdStr).SendAsync("UpdateReaction", messageId);
                }
            }
        }

        // 🔔 ГАЛОЧКИ ПРОЧТЕНИЯ
        public async Task MarkAsRead(string chatIdStr, long messageId)
        {
            if (int.TryParse(chatIdStr, out int chatId))
            {
                var participant = await _context.ChatParticipants
                    .FirstOrDefaultAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId);

                if (participant != null)
                {
                    var msg = await _context.Messages.FindAsync(messageId);
                    if (msg != null && msg.ChatID == chatId)
                    {
                        // 1. Помечаем само сообщение как прочитанное (только для личек)
                        var chat = await _context.Chats.FindAsync(chatId);
                        if (chat != null && !chat.IsGroup)
                        {
                            msg.IsRead = true;
                            msg.ReadAt = DateTime.UtcNow;
                        }

                        // 2. Обновляем курсор прочтения пользователя
                        if (participant.LastReadMessageId < messageId)
                        {
                            participant.LastReadMessageId = messageId;
                        }

                        // 3. Добавляем ReadReceipt (для групп)
                        if (!await _context.ReadReceipts.AnyAsync(rr => rr.MessageID == messageId && rr.UserID == CurrentUserId))
                        {
                            _context.ReadReceipts.Add(new ReadReceipt { MessageID = messageId, UserID = CurrentUserId });
                        }

                        await _context.SaveChangesAsync();
                        await Clients.Group(chatIdStr).SendAsync("MessageRead", messageId);
                    }
                }
            }
        }
    }
}
