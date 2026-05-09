using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using WebApplication1.Data;
using WebApplication1.Models;

namespace WebApplication1.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class ThemesController : ControllerBase
    {
        private readonly AppDbContext _context;

        public ThemesController(AppDbContext context)
        {
            _context = context;
        }

        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        [HttpGet]
        public async Task<IActionResult> GetTheme()
        {
            var theme = await _context.UserThemes.FirstOrDefaultAsync(t => t.UserID == CurrentUserId);
            if (theme == null) {
                return Ok(new UserTheme { UserID = CurrentUserId });
            }
            return Ok(theme);
        }

        [HttpPost]
        public async Task<IActionResult> UpdateTheme([FromBody] UserTheme updatedTheme)
        {
            var theme = await _context.UserThemes.FirstOrDefaultAsync(t => t.UserID == CurrentUserId);
            if (theme == null) {
                updatedTheme.UserID = CurrentUserId;
                _context.UserThemes.Add(updatedTheme);
            } else {
                theme.PrimaryColor = updatedTheme.PrimaryColor;
                theme.BgImageUrl = updatedTheme.BgImageUrl;
                theme.BubbleOpacity = updatedTheme.BubbleOpacity;
                theme.IsGlassmorphism = updatedTheme.IsGlassmorphism;
            }

            await _context.SaveChangesAsync();
            return Ok();
        }
    }
}
