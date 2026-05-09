using System.ComponentModel.DataAnnotations;

namespace WebApplication1.Models
{
    public class Story
    {
        [Key]
        public int StoryID { get; set; }
        public int UserID { get; set; }
        public string MediaUrl { get; set; }
        public string? Caption { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime ExpiresAt { get; set; } = DateTime.UtcNow.AddHours(24);
        public bool IsDeleted { get; set; } = false;

        public User User { get; set; }
    }
}
