using System.ComponentModel.DataAnnotations;

namespace WebApplication1.Models
{
    public class User
    {
        [Key]
        public int UserID { get; set; }

        [Required]
        public string Email { get; set; }

        [Required]
        public string Password { get; set; }

        public string DisplayName { get; set; }
        public string? Username { get; set; }
        public string? PhoneNumber { get; set; }
        public string? Bio { get; set; }
        public string? AvatarUrl { get; set; }

        public bool IsDarkMode { get; set; } = false;
        public string ThemeColor { get; set; } = "Default";

        public DateTime? DateOfBirth { get; set; }
        public string? MusicUrl { get; set; }
        public int PrivacyPhone { get; set; } = 0;
        public int PrivacyAvatar { get; set; } = 0;
        public int PrivacyMessages { get; set; } = 0;

        public bool IsOnline { get; set; } = false;
        public DateTime? LastActive { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public string? FcmToken { get; set; } // 🔔 Для Push-уведомлений
    }
}