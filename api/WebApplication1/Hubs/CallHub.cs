using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace WebApplication1.Hubs
{
    [Authorize]
    public class CallHub : Hub
    {
        private int CurrentUserId => int.Parse(Context.User!.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // Когда кто-то звонит кому-то
        public async Task CallUser(int targetUserId, string offerJson)
        {
            await Clients.User(targetUserId.ToString()).SendAsync("IncomingCall", CurrentUserId, offerJson);
        }

        // Ответ на звонок
        public async Task AnswerCall(int targetUserId, string answerJson)
        {
            await Clients.User(targetUserId.ToString()).SendAsync("CallAnswered", CurrentUserId, answerJson);
        }

        // Обмен ICE кандидатами
        public async Task SendIceCandidate(int targetUserId, string candidateJson)
        {
            await Clients.User(targetUserId.ToString()).SendAsync("ReceiveIceCandidate", CurrentUserId, candidateJson);
        }

        // Завершение звонка
        public async Task Hangup(int targetUserId)
        {
            await Clients.User(targetUserId.ToString()).SendAsync("CallEnded", CurrentUserId);
        }
    }
}
