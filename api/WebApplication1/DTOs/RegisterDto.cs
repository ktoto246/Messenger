using System.ComponentModel.DataAnnotations;

namespace WebApplication1.DTOs
{
    public class RegisterDto
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; }

        [Required]
        [MinLength(8, ErrorMessage = "Пароль должен быть не менее 8 символов")]
        [MaxLength(100)]
        [RegularExpression(@"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$",
            ErrorMessage = "Пароль должен содержать строчную и заглавную буквы и цифру")]
        public string Password { get; set; }

        [Required]
        [MaxLength(100)]
        public string DisplayName { get; set; }

        [Required]
        [MaxLength(50)]
        public string Username { get; set; }
    }
}
