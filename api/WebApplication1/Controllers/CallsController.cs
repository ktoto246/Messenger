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

            var calls = await _context.Calls
                .Where(c => (c.CallerUserID == userId && !c.DeletedByCaller) ||
                            (c.ReceiverUserID == userId && !c.DeletedByReceiver))
                .OrderByDescending(c => c.StartedAt)
                .Select(c => new {
                    c.CallID,
                    OtherUser = c.CallerUserID == userId ? c.ReceiverUser.DisplayName : c.CallerUser.DisplayName,
                    OtherUserId = c.CallerUserID == userId ? c.ReceiverUserID : c.CallerUserID,
                    Type = c.CallerUserID == userId ? "Outgoing" : "Incoming",
                    c.Status,
                    c.Duration,
                    Time = c.StartedAt,
                    c.IsVideo
                })
                .Take(50)
                .ToListAsync();

            return Ok(calls);
        }

        // DELETE: api/calls/history/5
        [HttpDelete("history/{userId}")]
        public async Task<IActionResult> ClearCallHistory(int userId)
        {
            if (userId != CurrentUserId) return Forbid();

            var userCalls = await _context.Calls
                .Where(c => c.CallerUserID == userId || c.ReceiverUserID == userId)
                .ToListAsync();

            foreach (var call in userCalls)
            {
                if (call.CallerUserID == userId) call.DeletedByCaller = true;
                if (call.ReceiverUserID == userId) call.DeletedByReceiver = true;
            }

            await _context.SaveChangesAsync();
            return Ok(new { success = true });
        }
    }
}
