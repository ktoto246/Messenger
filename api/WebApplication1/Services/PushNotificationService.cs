using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;

namespace WebApplication1.Services
{
    public class PushNotificationService
    {
        public async Task SendNotificationAsync(List<string> tokens, string title, string body, string? imageUrl = null)
        {
            if (tokens == null || !tokens.Any()) return;

            // 🛡️ Firebase имеет лимит: 500 токенов за один Multicast запрос
            var chunks = tokens.Chunk(500);

            foreach (var chunk in chunks)
            {
                var message = new MulticastMessage()
                {
                    Tokens = chunk.ToList(),
                    Notification = new Notification()
                    {
                        Title = title,
                        Body = body,
                        ImageUrl = imageUrl
                    },
                    Data = new Dictionary<string, string>()
                    {
                        { "click_action", "FLUTTER_NOTIFICATION_CLICK" },
                    }
                };

                try
                {
                    var response = await FirebaseMessaging.DefaultInstance.SendMulticastAsync(message);
                    Console.WriteLine($"Successfully sent {response.SuccessCount} messages in a chunk.");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error sending FCM notification chunk: {ex.Message}");
                }
            }
        }
    }
}
