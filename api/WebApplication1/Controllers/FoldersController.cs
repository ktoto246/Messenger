using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WebApplication1.Data;
using WebApplication1.Models;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace WebApplication1.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class FoldersController : ControllerBase
    {
        private readonly AppDbContext _context;

        public FoldersController(AppDbContext context)
        {
            _context = context;
        }

        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        [HttpGet]
        public async Task<IActionResult> GetFolders()
        {
            var folders = await _context.ChatFolders
                .Where(f => f.UserID == CurrentUserId)
                .Include(f => f.Chats)
                .Select(f => new {
                    f.FolderID,
                    f.FolderName,
                    f.IconName,
                    ChatIds = f.Chats.Select(c => c.ChatID).ToList()
                })
                .ToListAsync();
            return Ok(folders);
        }

        [HttpPost]
        public async Task<IActionResult> CreateFolder([FromBody] CreateFolderDto dto)
        {
            var folder = new ChatFolder
            {
                UserID = CurrentUserId,
                FolderName = dto.FolderName,
                IconName = dto.IconName ?? "folder"
            };

            if (dto.ChatIds != null)
            {
                var userChatIds = await _context.ChatParticipants
                    .Where(cp => cp.UserID == CurrentUserId)
                    .Select(cp => cp.ChatID)
                    .ToListAsync();

                var chats = await _context.Chats
                    .Where(c => dto.ChatIds.Contains(c.ChatID) && userChatIds.Contains(c.ChatID))
                    .ToListAsync();

                foreach (var chat in chats) folder.Chats.Add(chat);
            }

            _context.ChatFolders.Add(folder);
            await _context.SaveChangesAsync();

            return Ok(folder);
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteFolder(int id)
        {
            var folder = await _context.ChatFolders.FindAsync(id);
            if (folder == null) return NotFound();
            if (folder.UserID != CurrentUserId) return Forbid();

            _context.ChatFolders.Remove(folder);
            await _context.SaveChangesAsync();
            return Ok();
        }

        [HttpPut("{id}/chats")]
        public async Task<IActionResult> UpdateFolderChats(int id, [FromBody] List<int> chatIds)
        {
            var folder = await _context.ChatFolders.Include(f => f.Chats).FirstOrDefaultAsync(f => f.FolderID == id);
            if (folder == null) return NotFound();
            if (folder.UserID != CurrentUserId) return Forbid();

            folder.Chats.Clear();
            var userChatIds = await _context.ChatParticipants
                .Where(cp => cp.UserID == CurrentUserId)
                .Select(cp => cp.ChatID)
                .ToListAsync();

            var chats = await _context.Chats
                .Where(c => chatIds.Contains(c.ChatID) && userChatIds.Contains(c.ChatID))
                .ToListAsync();

            foreach (var chat in chats) folder.Chats.Add(chat);

            await _context.SaveChangesAsync();
            return Ok();
        }
    }

    public class CreateFolderDto
    {
        public string FolderName { get; set; } = string.Empty;
        public string? IconName { get; set; }
        public List<int>? ChatIds { get; set; }
    }
}
