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

            var message = new MulticastMessage()
            {
                Tokens = tokens,
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
                Console.WriteLine($"Successfully sent {response.SuccessCount} messages.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error sending FCM notification: {ex.Message}");
            }
        }
    }
}
