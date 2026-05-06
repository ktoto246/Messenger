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
                var isParticipant = await _context.ChatParticipants
                    .AnyAsync(cp => cp.ChatID == chatId && cp.UserID == CurrentUserId);

                if (isParticipant)
                {
                    var msg = await _context.Messages.FindAsync(messageId);
                    if (msg != null && msg.ChatID == chatId)
                    {
                        msg.IsRead = true;
                        msg.ReadAt = DateTime.UtcNow;
                        await _context.SaveChangesAsync();
                        await Clients.Group(chatIdStr).SendAsync("MessageRead", messageId);
                    }
                }
            }
        }
    }
}
