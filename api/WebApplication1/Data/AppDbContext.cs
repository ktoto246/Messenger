using Microsoft.EntityFrameworkCore;
using WebApplication1.Models;
namespace WebApplication1.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }

        public DbSet<User> Users { get; set; }
        public DbSet<Message> Messages { get; set; }
        public DbSet<Chat> Chats { get; set; }
        public DbSet<ChatParticipant> ChatParticipants { get; set; }
        public DbSet<Contact> Contacts { get; set; }
        public DbSet<MessageReaction> MessageReactions { get; set; }
        public DbSet<ChatFolder> ChatFolders { get; set; }
        public DbSet<Story> Stories { get; set; }
        public DbSet<UserTheme> UserThemes { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<ChatFolder>()
                .HasMany(f => f.Chats)
                .WithMany()
                .UsingEntity<Dictionary<string, object>>(
                    "ChatFolderItems",
                    j => j.HasOne<Chat>().WithMany().HasForeignKey("ChatID"),
                    j => j.HasOne<ChatFolder>().WithMany().HasForeignKey("FolderID")
                );

            modelBuilder.Entity<ChatParticipant>()
                .HasKey(cp => new { cp.ChatID, cp.UserID });

            modelBuilder.Entity<ChatParticipant>()
                .HasOne(cp => cp.Chat)
                .WithMany(c => c.Participants)
                .HasForeignKey(cp => cp.ChatID);

            modelBuilder.Entity<ChatParticipant>()
                .HasOne(cp => cp.User)
                .WithMany()
                .HasForeignKey(cp => cp.UserID);

            modelBuilder.Entity<Contact>()
                .HasOne(c => c.OwnerUser)
                .WithMany()
                .HasForeignKey(c => c.OwnerUserID)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Contact>()
                .HasOne(c => c.AddedUser)
                .WithMany()
                .HasForeignKey(c => c.AddedUserID)
                .OnDelete(DeleteBehavior.Restrict);

            // Фикс ошибки 0x80131904: Множественные каскадные пути (SQL Server)
            modelBuilder.Entity<MessageReaction>()
                .HasOne(r => r.User)
                .WithMany()
                .HasForeignKey(r => r.UserID)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}