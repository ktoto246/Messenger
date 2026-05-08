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

        public string? ContentText { get; set; } 
        public string? TranslatedText { get; set; } // 🌍 Перевод сообщения
        public string? TranscriptionText { get; set; } // 🎙️ Расшифровка голосового

        public string MessageType { get; set; } = "Text"; // Text, Image, Audio

        public DateTime SentAt { get; set; } = DateTime.UtcNow;
        public DateTime? ScheduledAt { get; set; } // 🕒 Отложенная отправка
        public bool IsRead { get; set; } = false;
        public DateTime? ReadAt { get; set; }
        public bool IsDelivered { get; set; } = false;
        public DateTime? DeliveredAt { get; set; }
        public bool IsViewOnce { get; set; } = false; // 👻 Исчезающее медиа
        public DateTime? ViewedAt { get; set; } // 🕒 Когда просмотрено
        public bool IsDeleted { get; set; } = false;
        public bool IsEdited { get; set; } = false;
        public long? ReplyToMessageId { get; set; }
        public int? PollId { get; set; }
        public string? MediaUrl { get; set; }
        public bool IsPinned { get; set; } = false;

        // Связи (Навигационные свойства)
        public virtual Chat? Chat { get; set; }
        public virtual User? SenderUser { get; set; }

        [ForeignKey("ReplyToMessageId")]
        public virtual Message? ReplyToMessage { get; set; }

        public virtual ICollection<MessageReaction> Reactions { get; set; } = new List<MessageReaction>();
    }
}
