using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using WebApplication1.Data;
using WebApplication1.Models;

namespace WebApplication1.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class StoriesController : ControllerBase
    {
        private readonly AppDbContext _context;

        public StoriesController(AppDbContext context)
        {
            _context = context;
        }

        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // 1. ПОЛУЧЕНИЕ СТОРИС (своих и друзей)
        [HttpGet]
        public async Task<IActionResult> GetStories()
        {
            var now = DateTime.UtcNow;
            
            // Получаем сторис, которые не истекли и не удалены
            var stories = await _context.Stories
                .Include(s => s.User)
                .Where(s => !s.IsDeleted && s.ExpiresAt > now)
                .OrderByDescending(s => s.CreatedAt)
                .Select(s => new {
                    s.StoryID,
                    s.MediaUrl,
                    s.Caption,
                    s.CreatedAt,
                    User = new {
                        s.User.UserID,
                        s.User.DisplayName,
                        s.User.AvatarUrl
                    }
                })
                .ToListAsync();

            return Ok(stories);
        }

        // 2. СОЗДАНИЕ СТОРИС
        [HttpPost]
        public async Task<IActionResult> PostStory([FromBody] string mediaUrl, [FromQuery] string? caption = null, [FromQuery] bool isPinned = false)
        {
            var newStory = new Story
            {
                UserID = CurrentUserId,
                MediaUrl = mediaUrl,
                Caption = caption,
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = isPinned ? DateTime.UtcNow.AddYears(100) : DateTime.UtcNow.AddHours(24)
            };

            _context.Stories.Add(newStory);
            await _context.SaveChangesAsync();

            return Ok(newStory);
        }

        // 3. УДАЛЕНИЕ СТОРИС
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteStory(int id)
        {
            var story = await _context.Stories.FindAsync(id);
            if (story == null) return NotFound();
            if (story.UserID != CurrentUserId) return Forbid();

            story.IsDeleted = true;
            await _context.SaveChangesAsync();
            return Ok();
        }
    }
}
