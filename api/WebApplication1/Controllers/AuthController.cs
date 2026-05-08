using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using WebApplication1.Data;
using WebApplication1.DTOs;
using WebApplication1.Models;
using BCrypt.Net;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.RateLimiting;

namespace WebApplication1.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;

        public AuthController(AppDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;
        }

        // POST: api/auth/register
        [HttpPost("register")]
        [EnableRateLimiting("register")]
        public async Task<IActionResult> Register([FromBody] RegisterDto dto)
        {
            if (await _context.Users.AnyAsync(u => u.Email == dto.Email))
                return BadRequest("Email уже занят");

            if (await _context.Users.AnyAsync(u => u.Username == dto.Username))
                return BadRequest("Этот логин (Username) уже занят");

            var user = new User
            {
                Email = dto.Email,
                Password = BCrypt.Net.BCrypt.HashPassword(dto.Password),
                DisplayName = dto.DisplayName,
                Username = dto.Username,
                AvatarUrl = null,
                IsOnline = true,
                LastActive = DateTime.UtcNow,
                CreatedAt = DateTime.UtcNow
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            return Ok(new { Message = "Регистрация успешна", UserID = user.UserID });
        }

        // POST: api/auth/login  (accepts email OR username in the "login" field)
        [HttpPost("login")]
        [EnableRateLimiting("login")]
        public async Task<IActionResult> Login([FromBody] LoginDto dto)
        {
            var login = dto.Login.Trim();
            var user = await _context.Users.FirstOrDefaultAsync(u =>
                u.Email == login || u.Username == login);

            if (user == null || !BCrypt.Net.BCrypt.Verify(dto.Password, user.Password))
                return Unauthorized("Неверный логин или пароль");

            user.IsOnline = true;
            user.LastActive = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            var token = GenerateJwtToken(user, out var jti, out var expires);

            return Ok(new
            {
                message = "Login successful",
                token,
                userId = user.UserID,
                displayName = user.DisplayName,
                email = user.Email
            });
        }

        // POST: api/auth/logout
        [HttpPost("logout")]
        [Authorize]
        public async Task<IActionResult> Logout()
        {
            var jti = User.FindFirstValue(JwtRegisteredClaimNames.Jti);
            var expClaim = User.FindFirstValue(JwtRegisteredClaimNames.Exp);

            if (string.IsNullOrEmpty(jti))
                return BadRequest("Недействительный токен");

            // avoid duplicate entries
            if (!await _context.RevokedTokens.AnyAsync(t => t.Jti == jti))
            {
                var expires = expClaim != null
                    ? DateTimeOffset.FromUnixTimeSeconds(long.Parse(expClaim)).UtcDateTime
                    : DateTime.UtcNow.AddDays(7);

                _context.RevokedTokens.Add(new RevokedToken { Jti = jti, ExpiresAt = expires });
                await _context.SaveChangesAsync();
            }

            return Ok(new { message = "Logged out" });
        }

        [HttpPost("status")]
        [Authorize]
        public async Task<IActionResult> UpdateStatus([FromQuery] bool isOnline)
        {
            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            var user = await _context.Users.FindAsync(userId);
            if (user != null)
            {
                user.IsOnline = isOnline;
                user.LastActive = DateTime.UtcNow;
                await _context.SaveChangesAsync();
                return Ok();
            }
            return NotFound("User not found");
        }

        private string GenerateJwtToken(User user, out string jti, out DateTime expires)
        {
            var jwtSettings = _configuration.GetSection("Jwt");
            var key = Encoding.ASCII.GetBytes(jwtSettings["Key"]!);

            jti = Guid.NewGuid().ToString();
            expires = DateTime.UtcNow.AddDays(7);

            var tokenHandler = new JwtSecurityTokenHandler();
            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(new[]
                {
                    new Claim(ClaimTypes.NameIdentifier, user.UserID.ToString()),
                    new Claim(JwtRegisteredClaimNames.Jti, jti)
                }),
                Expires = expires,
                Issuer = jwtSettings["Issuer"],
                Audience = jwtSettings["Audience"],
                SigningCredentials = new SigningCredentials(
                    new SymmetricSecurityKey(key),
                    SecurityAlgorithms.HmacSha256Signature)
            };

            var token = tokenHandler.CreateToken(tokenDescriptor);
            return tokenHandler.WriteToken(token);
        }
    }
}
