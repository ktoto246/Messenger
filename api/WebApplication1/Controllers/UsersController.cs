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
        public async Task<IActionResult> GetUsers([FromQuery] int skip = 0, [FromQuery] int take = 50)
        {
            take = Math.Clamp(take, 1, 100);
            var users = await _context.Users
                .OrderBy(u => u.DisplayName)
                .Skip(skip)
                .Take(take)
                .Select(u => new { u.UserID, u.DisplayName, u.Username, u.AvatarUrl, u.IsOnline, u.Bio })
                .ToListAsync();
            return Ok(users);
        }

        [HttpGet("search")]
        public async Task<IActionResult> SearchUsers([FromQuery] string? query)
        {
            var usersQuery = _context.Users.AsQueryable();
            if (!string.IsNullOrWhiteSpace(query))
            {
                usersQuery = usersQuery.Where(u => u.Username!.Contains(query) || u.DisplayName.Contains(query));
            }

            var users = await usersQuery
                .Select(u => new { u.UserID, u.DisplayName, u.Username, u.AvatarUrl, u.IsOnline, u.LastActive })
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
                PhoneNumber = isSelf || !user.PrivacyPhone ? user.PhoneNumber : null,
                user.Bio,
                AvatarUrl = isSelf || !user.PrivacyAvatar ? user.AvatarUrl : null,
                IsOnline = isSelf || !user.PrivacyOnlineStatus ? user.IsOnline : (bool?)null,
                LastActive = isSelf || !user.PrivacyOnlineStatus ? user.LastActive : null,
                user.CreatedAt,
                DateOfBirth = isSelf ? user.DateOfBirth : null,
                user.MusicUrl,
                user.ThemeColor,
                user.PrivacyPhone,
                user.PrivacyAvatar,
                user.PrivacyMessages,
                user.PrivacyOnlineStatus,
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

        [HttpPost("nearby")]
        public async Task<IActionResult> GetNearbyUsers([FromBody] LocationDto location)
        {
            var user = await _context.Users.FindAsync(CurrentUserId);
            if (user != null)
            {
                user.Latitude = location.Latitude;
                user.Longitude = location.Longitude;
                user.LastActive = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }

            // Bbox-фильтр в SQL: ±0.1° ≈ ±11км, отсекаем большинство записей до загрузки в память
            double latDelta = 0.1;
            double lonDelta = 0.1;
            var candidatesQuery = _context.Users
                .Where(u => u.UserID != CurrentUserId
                    && u.Latitude != null && u.Longitude != null
                    && u.Latitude >= location.Latitude - latDelta
                    && u.Latitude <= location.Latitude + latDelta
                    && u.Longitude >= location.Longitude - lonDelta
                    && u.Longitude <= location.Longitude + lonDelta);

            var candidates = await candidatesQuery
                .Select(u => new { u.UserID, u.DisplayName, u.AvatarUrl, u.IsOnline, u.Latitude, u.Longitude })
                .ToListAsync();

            var radiusMeters = location.RadiusKm * 1000;
            var result = candidates
                .Select(u => new
                {
                    u.UserID,
                    u.DisplayName,
                    u.AvatarUrl,
                    u.IsOnline,
                    DistanceMeters = CalculateDistance(location.Latitude, location.Longitude, u.Latitude!.Value, u.Longitude!.Value)
                })
                .Where(u => u.DistanceMeters <= radiusMeters)
                .OrderBy(u => u.DistanceMeters)
                .ToList();

            return Ok(result);
        }

        private double CalculateDistance(double lat1, double lon1, double lat2, double lon2)
        {
            var d1 = lat1 * (Math.PI / 180.0);
            var num1 = lon1 * (Math.PI / 180.0);
            var d2 = lat2 * (Math.PI / 180.0);
            var num2 = lon2 * (Math.PI / 180.0) - num1;
            var d3 = Math.Pow(Math.Sin((d2 - d1) / 2.0), 2.0) + Math.Cos(d1) * Math.Cos(d2) * Math.Pow(Math.Sin(num2 / 2.0), 2.0);
            return 6371000.0 * (2.0 * Math.Atan2(Math.Sqrt(d3), Math.Sqrt(1.0 - d3)));
        }

        public class LocationDto { public double Latitude { get; set; } public double Longitude { get; set; } public double RadiusKm { get; set; } = 10; }

        public class UserUpdateDto
        {
            public string? DisplayName { get; set; }
            public string? Bio { get; set; }
            public string? AvatarUrl { get; set; }
            public string? FcmToken { get; set; }
            public string? ThemeColor { get; set; }
            public DateTime? DateOfBirth { get; set; }
            public string? MusicUrl { get; set; }
            public bool? IsDarkMode { get; set; }
            public bool? PrivacyPhone { get; set; }
            public bool? PrivacyAvatar { get; set; }
            public bool? PrivacyMessages { get; set; }
        }
    }
}