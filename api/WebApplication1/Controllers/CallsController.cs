using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WebApplication1.Data;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace WebApplication1.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class CallsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public CallsController(AppDbContext context)
        {
            _context = context;
        }

        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // GET: api/calls/history/5
        [HttpGet("history/{userId}")]
        public async Task<IActionResult> GetCallHistory(int userId)
        {
            if (userId != CurrentUserId) return Forbid();

            // В реальности нужна таблица Calls. Имитируем:
            return Ok(new[] {
                new { CallId = 1, OtherUser = "Алексей", Type = "Incoming", Duration = 120, Time = DateTime.UtcNow.AddHours(-2) },
                new { CallId = 2, OtherUser = "Мария", Type = "Outgoing", Duration = 45, Time = DateTime.UtcNow.AddDays(-1) }
            });
        }

        // DELETE: api/calls/history/5
        [HttpDelete("history/{userId}")]
        public async Task<IActionResult> ClearCallHistory(int userId)
        {
            if (userId != CurrentUserId) return Forbid();

            // Логика очистки истории звонков
            return Ok(new { success = true });
        }
    }
}
