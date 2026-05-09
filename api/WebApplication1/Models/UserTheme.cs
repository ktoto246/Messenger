using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace WebApplication1.Models
{
    public class UserTheme
    {
        [Key, ForeignKey("User")]
        public int UserID { get; set; }
        public string PrimaryColor { get; set; } = "#007AFF";
        public string? BgImageUrl { get; set; }
        public double BubbleOpacity { get; set; } = 0.9;
        public bool IsGlassmorphism { get; set; } = true;

        public User User { get; set; }
    }
}
