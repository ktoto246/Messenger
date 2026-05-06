using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace WebApplication1.Models
{
    public class ChatFolder
    {
        [Key]
        public int FolderID { get; set; }

        [Required]
        public int UserID { get; set; }

        [Required]
        [MaxLength(50)]
        public string FolderName { get; set; } = string.Empty;

        [MaxLength(50)]
        public string IconName { get; set; } = "folder";

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        [ForeignKey("UserID")]
        public virtual User? User { get; set; }

        public virtual ICollection<Chat> Chats { get; set; } = new List<Chat>();
    }
}
