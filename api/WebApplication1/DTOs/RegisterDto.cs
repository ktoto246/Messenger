using System.ComponentModel.DataAnnotations;

namespace WebApplication1.DTOs
{
    public class RegisterDto
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; }

        [Required]
        [MinLength(6, ErrorMessage = "Пароль должен быть не менее 6 символов")]
        [MaxLength(100)]
        public string Password { get; set; }

        [Required]
        [MaxLength(100)]
        public string DisplayName { get; set; }

        [MaxLength(50)]
        public string? Username { get; set; }
    }
}
