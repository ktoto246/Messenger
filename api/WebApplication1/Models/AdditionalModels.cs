using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace WebApplication1.Models
{
    public class ReadReceipt
    {
        public long MessageID { get; set; }
        [ForeignKey("MessageID")]
        public virtual Message Message { get; set; }

        public int UserID { get; set; }
        [ForeignKey("UserID")]
        public virtual User User { get; set; }

        public DateTime ReadAt { get; set; } = DateTime.UtcNow;
    }

    public class MessageHistory
    {
        [Key]
        public long HistoryID { get; set; }

        public long MessageID { get; set; }
        [ForeignKey("MessageID")]
        public virtual Message Message { get; set; }

        [Required]
        public string OldContent { get; set; }

        public DateTime EditedAt { get; set; } = DateTime.UtcNow;
    }

    public class Poll
    {
        [Key]
        public int PollID { get; set; }

        public int ChatID { get; set; }
        [ForeignKey("ChatID")]
        public virtual Chat Chat { get; set; }

        public int CreatorUserID { get; set; }
        [ForeignKey("CreatorUserID")]
        public virtual User CreatorUser { get; set; }

        [Required]
        [MaxLength(500)]
        public string Question { get; set; }

        public bool IsAnonymous { get; set; } = true;
        public bool IsMultipleChoice { get; set; } = false;
        public DateTime? ExpiresAt { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public virtual ICollection<PollOption> Options { get; set; } = new List<PollOption>();
    }

    public class PollOption
    {
        [Key]
        public int OptionID { get; set; }

        public int PollID { get; set; }
        [ForeignKey("PollID")]
        public virtual Poll Poll { get; set; }

        [Required]
        [MaxLength(200)]
        public string OptionText { get; set; }

        public int VoteCount { get; set; } = 0;
    }

    public class PollVote
    {
        public int PollID { get; set; }
        [ForeignKey("PollID")]
        public virtual Poll Poll { get; set; }

        public int OptionID { get; set; }
        [ForeignKey("OptionID")]
        public virtual PollOption Option { get; set; }

        public int UserID { get; set; }
        [ForeignKey("UserID")]
        public virtual User User { get; set; }
    }

    public class Call
    {
        [Key]
        public int CallID { get; set; }

        public int CallerUserID { get; set; }
        [ForeignKey("CallerUserID")]
        public virtual User CallerUser { get; set; }

        public int ReceiverUserID { get; set; }
        [ForeignKey("ReceiverUserID")]
        public virtual User ReceiverUser { get; set; }

        [Required]
        public string Status { get; set; } // "Initiated", "Accepted", "Rejected", "Missed", "Ended"
        public int Duration { get; set; } // in seconds
        public bool IsVideo { get; set; }
        public DateTime StartedAt { get; set; } = DateTime.UtcNow;
        public DateTime? EndedAt { get; set; }
    }
}
