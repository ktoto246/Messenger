using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace WebApplication1.Models
{
    public class Message
    {
        [Key]
        public long MessageID { get; set; }

        public int ChatID { get; set; }
        public int SenderUserID { get; set; }

        public string ContentText { get; set; } // В базе мы назвали это ContentText

        public string MessageType { get; set; } = "Text"; // Text, Image, Audio

        public DateTime SentAt { get; set; } = DateTime.UtcNow;
        public bool IsRead { get; set; } = false;
        public bool IsDeleted { get; set; } = false;
        public bool IsEdited { get; set; } = false;
        public long? ReplyToMessageId { get; set; }
        [Column("MediaUrl")]
        public string? ImageUrl { get; set; }
        public bool IsPinned { get; set; } = false;
    }
}
