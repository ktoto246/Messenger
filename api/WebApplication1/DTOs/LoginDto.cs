using System.ComponentModel.DataAnnotations;

namespace WebApplication1.DTOs
{
    public class LoginDto
    {
        [Required]
        public string Login { get; set; } // email or username

        [Required]
        public string Password { get; set; }
    }
}
