using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WebApplication1.Data;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace WebApplication1.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class MediaController : ControllerBase
    {
        private readonly AppDbContext _context;

        public MediaController(AppDbContext context)
        {
            _context = context;
        }

        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        [HttpGet("{fileName}")]
        public async Task<IActionResult> GetMedia(string fileName)
        {
            // 🛡️ Проверка: есть ли сообщение с таким URL и состоит ли юзер в этом чате
            // URL может быть как полным, так и относительным, поэтому ищем по вхождению имени файла
            var message = await _context.Messages
                .FirstOrDefaultAsync(m => m.ImageUrl != null && m.ImageUrl.Contains(fileName));

            if (message == null) return NotFound();

            var isParticipant = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == message.ChatID && cp.UserID == CurrentUserId);
            if (!isParticipant) return Forbid();

            // 🛡️ Если IsViewOnce и уже просмотрено - не отдаем
            if (message.IsViewOnce && message.ViewedAt != null) return Forbid();

            var filePath = Path.Combine(Directory.GetCurrentDirectory(), "App_Data", "uploads", fileName);
            if (!System.IO.File.Exists(filePath)) return NotFound();

            var fileBytes = await System.IO.File.ReadAllBytesAsync(filePath);
            
            return File(fileBytes, GetContentType(fileName));
        }

        private string GetContentType(string fileName)
        {
            var ext = Path.GetExtension(fileName).ToLowerInvariant();
            return ext switch
            {
                ".jpg" or ".jpeg" => "image/jpeg",
                ".png" => "image/png",
                ".gif" => "image/gif",
                ".mp4" => "video/mp4",
                ".mp3" => "audio/mpeg",
                ".wav" => "audio/wav",
                ".m4a" => "audio/mp4",
                _ => "application/octet-stream",
            };
        }
    }
}
