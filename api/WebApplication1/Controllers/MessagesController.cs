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
            if (message == null) return NotFound();

            // 🛡️ Только автор может редактировать
            if (message.SenderUserID != CurrentUserId) return Forbid();

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
            if (message == null) return NotFound();

            // 🛡️ Только автор сообщения или админ группы может удалить
            bool canDelete = message.SenderUserID == CurrentUserId;
            
            if (!canDelete && message.Chat.IsGroup)
            {
                var isAdmin = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId && cp.IsAdmin);
                canDelete = isAdmin;
            }

            if (!canDelete) return Forbid();

            _context.Messages.Remove(message);
            await _context.SaveChangesAsync();

            return Ok(new { success = true });
        }

        // PUT: api/messages/5/pin
        [HttpPut("{messageId}/pin")]
        public async Task<IActionResult> TogglePin(long messageId)
        {
            var message = await _context.Messages.Include(m => m.Chat).FirstOrDefaultAsync(m => m.MessageID == messageId);
            if (message == null) return NotFound();

            // 🛡️ В группах только админ может пинить. В личках - оба.
            bool canPin = !message.Chat.IsGroup;
            if (!canPin)
            {
                var isAdmin = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId && cp.IsAdmin);
                canPin = isAdmin;
            }
            // Личные чаты: проверяем, что юзер вообще в этом чате
            if (!canPin)
            {
                canPin = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId);
            }

            if (!canPin) return Forbid();

            message.IsPinned = !message.IsPinned;
            await _context.SaveChangesAsync();

            return Ok(new { success = true, isPinned = message.IsPinned });
        }
    }
}