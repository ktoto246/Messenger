using Microsoft.EntityFrameworkCore;
using WebApplication1.Data;

namespace WebApplication1.Services
{
    public class OnlineStatusWorker : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;

        public OnlineStatusWorker(IServiceProvider serviceProvider)
        {
            _serviceProvider = serviceProvider;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                using (var scope = _serviceProvider.CreateScope())
                {
                    var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                    var timeout = DateTime.UtcNow.AddMinutes(-5); // Считаем офлайн через 5 минут неактивности

                    var timedOutUsers = await context.Users
                        .Where(u => u.IsOnline && (u.LastActive == null || u.LastActive < timeout))
                        .ToListAsync();

                    if (timedOutUsers.Any())
                    {
                        foreach (var user in timedOutUsers)
                        {
                            user.IsOnline = false;
                        }
                        await context.SaveChangesAsync();
                    }
                }

                await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
            }
        }
    }
}
