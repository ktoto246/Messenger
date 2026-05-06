using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace WebApplication1.Models
{
    public class Contact
    {
        [Key]
        public int ContactID { get; set; }

        public int OwnerUserID { get; set; }
        [ForeignKey("OwnerUserID")]
        public User OwnerUser { get; set; }

        public int AddedUserID { get; set; }
        [ForeignKey("AddedUserID")]
        public User AddedUser { get; set; }

        public DateTime AddedAt { get; set; } = DateTime.UtcNow;
    }
}