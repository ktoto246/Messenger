using Microsoft.EntityFrameworkCore;
using WebApplication1.Data;
using WebApplication1.Hubs;
using Microsoft.AspNetCore.SignalR;

namespace WebApplication1.Services
{
    public class ScheduledMessageWorker : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly IHubContext<ChatHub> _hubContext;

        public ScheduledMessageWorker(IServiceProvider serviceProvider, IHubContext<ChatHub> hubContext)
        {
            _serviceProvider = serviceProvider;
            _hubContext = hubContext;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                using (var scope = _serviceProvider.CreateScope())
                {
                    var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                    var now = DateTime.UtcNow;

                    var pendingMessages = await context.Messages
                        .Include(m => m.SenderUser)
                        .Where(m => m.ScheduledAt != null && m.ScheduledAt <= now)
                        .ToListAsync();

                    if (pendingMessages.Any())
                    {
                        foreach (var msg in pendingMessages)
                        {
                            msg.SentAt = now;
                            msg.ScheduledAt = null; // Помечаем как отправленное
                        }

                        await context.SaveChangesAsync();

                        // Уведомляем клиентов через SignalR
                        foreach (var msg in pendingMessages)
                        {
                            await _hubContext.Clients.Group(msg.ChatID.ToString()).SendAsync("ReceiveMessage", new {
                                msg.MessageID,
                                msg.SenderUserID,
                                msg.ContentText,
                                msg.SentAt,
                                msg.ImageUrl,
                                msg.MessageType,
                                msg.ReplyToMessageId,
                                SenderName = msg.SenderUser?.DisplayName,
                                msg.IsViewOnce
                            });
                        }
                    }
                }

                await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken); // Проверка каждые 30 сек
            }
        }
    }
}
