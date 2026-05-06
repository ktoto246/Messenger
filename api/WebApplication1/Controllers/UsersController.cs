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
    public class UsersController : ControllerBase
    {
        private readonly AppDbContext _context;

        public UsersController(AppDbContext context)
        {
            _context = context;
        }

        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        [HttpGet]
        public async Task<IActionResult> GetUsers()
        {
            var users = await _context.Users
                .Select(u => new { u.UserID, u.DisplayName, u.Username, u.AvatarUrl, u.IsOnline, u.Bio })
                .Take(50)
                .ToListAsync();
            return Ok(users);
        }

        [HttpGet("search")]
        public async Task<IActionResult> SearchUsers([FromQuery] string? query)
        {
            var usersQuery = _context.Users.AsQueryable();
            if (!string.IsNullOrWhiteSpace(query))
            {
                usersQuery = usersQuery.Where(u => u.Username!.Contains(query) || u.Email.Contains(query) || u.DisplayName.Contains(query));
            }

            var users = await usersQuery
                .Select(u => new { u.UserID, u.DisplayName, u.Username, u.AvatarUrl, u.IsOnline, u.LastActive, u.Bio })
                .Take(20)
                .ToListAsync();
            return Ok(users);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetUserProfile(int id)
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null) return NotFound();

            bool isSelf = id == CurrentUserId;

            return Ok(new
            {
                user.UserID, 
                user.DisplayName, 
                user.Username, 
                PhoneNumber = isSelf || (!user.PrivacyPhone) ? user.PhoneNumber : null, 
                user.Bio, 
                AvatarUrl = isSelf || (!user.PrivacyAvatar) ? user.AvatarUrl : null,
                user.IsOnline, 
                user.LastActive, 
                user.CreatedAt, 
                DateOfBirth = isSelf ? user.DateOfBirth : null, 
                user.MusicUrl, 
                user.ThemeColor,
                user.PrivacyPhone, 
                user.PrivacyAvatar, 
                user.PrivacyMessages, 
                user.IsDarkMode
            });
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateProfile(int id, [FromBody] UserUpdateDto updatedData)
        {
            // 🛡️ Можно редактировать только СВОЙ профиль
            if (id != CurrentUserId) return Forbid();

            var user = await _context.Users.FindAsync(id);
            if (user == null) return NotFound();

            if (updatedData.DisplayName != null) user.DisplayName = updatedData.DisplayName;
            if (updatedData.Bio != null) user.Bio = updatedData.Bio;
            if (updatedData.AvatarUrl != null) user.AvatarUrl = updatedData.AvatarUrl;
            if (updatedData.FcmToken != null) user.FcmToken = updatedData.FcmToken; // 🔔 Обновление токена для пушей
            if (updatedData.ThemeColor != null) user.ThemeColor = updatedData.ThemeColor;
            if (updatedData.DateOfBirth != null) user.DateOfBirth = updatedData.DateOfBirth;
            if (updatedData.MusicUrl != null) user.MusicUrl = updatedData.MusicUrl;
            if (updatedData.IsDarkMode.HasValue) user.IsDarkMode = updatedData.IsDarkMode.Value;
            if (updatedData.PrivacyPhone.HasValue) user.PrivacyPhone = updatedData.PrivacyPhone.Value;
            if (updatedData.PrivacyAvatar.HasValue) user.PrivacyAvatar = updatedData.PrivacyAvatar.Value;
            if (updatedData.PrivacyMessages.HasValue) user.PrivacyMessages = updatedData.PrivacyMessages.Value;

            await _context.SaveChangesAsync();
            return Ok(new { Message = "Profile updated successfully" });
        }
    }
}