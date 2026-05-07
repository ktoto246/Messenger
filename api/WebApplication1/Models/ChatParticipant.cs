using System.ComponentModel.DataAnnotations.Schema;

namespace WebApplication1.Models
{
    public class ChatParticipant
    {
        // Это составной ключ (ChatID + UserID), настроим его в AppDbContext
        public int ChatID { get; set; }
        [ForeignKey("ChatID")]
        public Chat Chat { get; set; }

        public int UserID { get; set; }
        [ForeignKey("UserID")]
        public User User { get; set; }

        public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
        public bool IsPinned { get; set; } = false;
        public bool IsAdmin { get; set; } = false;
        public bool IsArchived { get; set; } = false; // 📦 Новое
        public bool IsMuted { get; set; } = false; // 🔕 Новое
        public long? LastReadMessageId { get; set; } // 📖 Новое
        public long? LastDeletedMessageId { get; set; } // 🗑️ Новое
    }
}
