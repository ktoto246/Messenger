using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WebApplication1.Data;
using WebApplication1.Models;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace WebApplication1.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class PollsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public PollsController(AppDbContext context)
        {
            _context = context;
        }

        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // POST: api/polls/5/vote
        [HttpPost("{pollId}/vote")]
        public async Task<IActionResult> VotePoll(int pollId, [FromBody] VoteDto dto)
        {
            var poll = await _context.Polls.Include(p => p.Options).FirstOrDefaultAsync(p => p.PollID == pollId);
            if (poll == null) return NotFound();
 
            // Проверка участия в чате
            var isParticipant = await _context.ChatParticipants.AnyAsync(cp => cp.ChatID == poll.ChatID && cp.UserID == CurrentUserId);
            if (!isParticipant) return Forbid();
 
            PollOption? option = null;
            if (dto.OptionID > 0) {
                option = poll.Options.FirstOrDefault(o => o.OptionID == dto.OptionID);
            } else if (dto.OptionIndex >= 0 && dto.OptionIndex < poll.Options.Count) {
                option = poll.Options.ElementAt(dto.OptionIndex);
            }
 
            if (option == null) return BadRequest("Неверный вариант ответа.");
 
            var existingVote = await _context.PollVotes.FirstOrDefaultAsync(v => v.PollID == pollId && v.UserID == CurrentUserId);
 
            if (existingVote != null)
            {
                if (existingVote.OptionID == option.OptionID)
                {
                    // Отмена голоса
                    _context.PollVotes.Remove(existingVote);
                    option.VoteCount--;
                }
                else
                {
                    // Смена голоса
                    var oldOption = poll.Options.First(o => o.OptionID == existingVote.OptionID);
                    oldOption.VoteCount--;
                    existingVote.OptionID = option.OptionID;
                    option.VoteCount++;
                }
            }
            else
            {
                // Новый голос
                _context.PollVotes.Add(new PollVote
                {
                    PollID = pollId,
                    UserID = CurrentUserId,
                    OptionID = option.OptionID
                });
                option.VoteCount++;
            }
 
            await _context.SaveChangesAsync();
 
            return Ok(new { 
                success = true, 
                pollId, 
                options = poll.Options.Select(o => new { o.OptionID, o.VoteCount }) 
            });
        }
 
        public class VoteDto
        {
            public int OptionID { get; set; }
            public int OptionIndex { get; set; } = -1;
        }
    }
}
