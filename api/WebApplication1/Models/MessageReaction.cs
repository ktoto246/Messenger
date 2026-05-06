using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace WebApplication1.Models
{
    public class MessageReaction
    {
        [Key]
        public long ReactionID { get; set; }

        [Required]
        public long MessageID { get; set; }

        [Required]
        public int UserID { get; set; }

        [Required]
        [MaxLength(10)]
        public string Emoji { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Навигационные свойства
        [ForeignKey("MessageID")]
        public virtual Message? Message { get; set; }

        [ForeignKey("UserID")]
        public virtual User? User { get; set; }
    }
}
