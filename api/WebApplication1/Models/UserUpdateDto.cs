namespace WebApplication1.Models
{
    public class UserUpdateDto
    {
        public string? DisplayName { get; set; }
        public string? Bio { get; set; }
        public string? AvatarUrl { get; set; }
        public string? FcmToken { get; set; } // 🔔 Токен для пушей
        public string? ThemeColor { get; set; }
        public DateTime? DateOfBirth { get; set; }
        public string? MusicUrl { get; set; }

        public bool? IsDarkMode { get; set; }
        public bool? PrivacyPhone { get; set; }
        public bool? PrivacyAvatar { get; set; }
        public bool? PrivacyMessages { get; set; }
    }
}