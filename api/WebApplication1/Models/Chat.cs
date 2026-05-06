using System.ComponentModel.DataAnnotations;
using System.Collections.Generic;

namespace WebApplication1.Models
{
    public class Chat
    {
        [Key]
        public int ChatID { get; set; }

        public string? GroupName { get; set; } // Название, если это группа
        public string? AvatarUrl { get; set; } // Ссылка на аватарку группы
        public bool IsGroup { get; set; } = false;
        public bool IsChannel { get; set; } = false;
        public int? CreatorUserId { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Связи с другими таблицами (важно для работы Include и Select)
        public virtual ICollection<ChatParticipant> Participants { get; set; }
        public virtual ICollection<Message> Messages { get; set; }
    }
}
