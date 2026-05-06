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

        public async Task Typing(string chatId, int userId)
        {
            // 🛡️ Проверка, что ты — это ты, и ты в этом чате
            if (userId == CurrentUserId)
            {
                await Clients.Group(chatId).SendAsync("UserTyping", chatId, userId);
            }
        }

        public async Task SendReaction(string chatId, long messageId)
        {
            // 🛡️ Проверка: является ли пользователь участником этого чата
            if (int.TryParse(chatId, out int id))
            {
                var isParticipant = await _context.ChatParticipants
                    .AnyAsync(cp => cp.ChatID == id && cp.UserID == CurrentUserId);

                if (isParticipant)
                {
                    await Clients.Group(chatId).SendAsync("UpdateReaction", messageId);
                }
            }
        }

        // 🔔 ГАЛОЧКИ ПРОЧТЕНИЯ
        public async Task MarkAsRead(string chatId, long messageId)
        {
            var msg = await _context.Messages.FindAsync(messageId);
            if (msg != null && msg.ChatID.ToString() == chatId)
            {
                msg.IsRead = true;
                msg.ReadAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();
                await Clients.Group(chatId).SendAsync("MessageRead", messageId);
            }
        }
    }
}
