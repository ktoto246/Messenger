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
        private readonly FileService _fileService;
 
        public ScheduledMessageWorker(IServiceProvider serviceProvider, IHubContext<ChatHub> hubContext, FileService fileService)
        {
            _serviceProvider = serviceProvider;
            _hubContext = hubContext;
            _fileService = fileService;
        }
 
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                using (var scope = _serviceProvider.CreateScope())
                {
                    var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                    var now = DateTime.UtcNow;
 
                    // 1. ОТПРАВКА ЗАПЛАНИРОВАННЫХ СООБЩЕНИЙ
                    // Используем транзакцию с уровнем Serializable или RowLock для предотвращения гонки
                    using (var transaction = await context.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, stoppingToken))
                    {
                        try {
                            var pendingMessages = await context.Messages
                                .Include(m => m.SenderUser)
                                .Where(m => m.ScheduledAt != null && m.ScheduledAt <= now)
                                .ToListAsync();
 
                            if (pendingMessages.Any())
                            {
                                foreach (var msg in pendingMessages)
                                {
                                    msg.SentAt = now;
                                    msg.ScheduledAt = null; 
                                }
 
                                await context.SaveChangesAsync();
                                await transaction.CommitAsync();
 
                                // Уведомляем клиентов ПОСЛЕ коммита
                                foreach (var msg in pendingMessages)
                                {
                                    await _hubContext.Clients.Group(msg.ChatID.ToString()).SendAsync("ReceiveMessage", new {
                                        msg.MessageID,
                                        msg.SenderUserID,
                                        msg.ContentText,
                                        msg.SentAt,
                                        msg.MediaUrl,
                                        msg.MessageType,
                                        msg.ReplyToMessageId,
                                        SenderName = msg.SenderUser?.DisplayName,
                                        msg.IsViewOnce
                                    });
                                }
                            }
                        } catch {
                            await transaction.RollbackAsync();
                        }
                    }
 
                    // 2. АВТОУДАЛЕНИЕ СООБЩЕНИЙ (ПО ТАЙМЕРУ ЧАТА)
                    // Фильтр SentAt + AutoDeleteSeconds <= now вычисляется в SQL через EF
                    try
                    {
                        var toDeleteByTimer = await context.Messages
                            .Include(m => m.Chat)
                            .Where(m => !m.IsDeleted
                                && m.ScheduledAt == null
                                && m.Chat.AutoDeleteSeconds != null
                                && EF.Functions.DateDiffSecond(m.SentAt, now) >= m.Chat.AutoDeleteSeconds)
                            .ToListAsync();

                        foreach (var msg in toDeleteByTimer)
                        {
                            msg.IsDeleted = true;
                            if (!string.IsNullOrEmpty(msg.MediaUrl))
                            {
                                try { _fileService.DeleteFile(msg.MediaUrl); } catch { /* файл уже удалён */ }
                            }
                        }

                        if (toDeleteByTimer.Any()) await context.SaveChangesAsync();
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"AutoDelete timer error: {ex.Message}");
                    }

                    // 3. УДАЛЕНИЕ ОДНОРАЗОВЫХ СООБЩЕНИЙ (УЖЕ ПРОСМОТРЕННЫХ)
                    try
                    {
                        var expiredViewOnce = await context.Messages
                            .Where(m => m.IsViewOnce && m.ViewedAt != null && !m.IsDeleted && m.ScheduledAt == null)
                            .ToListAsync();

                        foreach (var msg in expiredViewOnce)
                        {
                            msg.IsDeleted = true;
                            if (!string.IsNullOrEmpty(msg.MediaUrl))
                            {
                                try { _fileService.DeleteFile(msg.MediaUrl); } catch { /* файл уже удалён */ }
                            }
                        }

                        if (expiredViewOnce.Any()) await context.SaveChangesAsync();
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"AutoDelete viewOnce error: {ex.Message}");
                    }
                }

                await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken); // Проверка каждые 10 сек
            }
        }
    }
}