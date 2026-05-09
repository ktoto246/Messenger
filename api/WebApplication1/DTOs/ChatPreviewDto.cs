namespace WebApplication1.DTOs
{
    public class ChatPreviewDto
    {
        public int ChatID { get; set; }
        public string ChatName { get; set; } // Имя собеседника или название группы
        public string LastMessage { get; set; }
        public DateTime LastMessageTime { get; set; }
        public int UnreadCount { get; set; }
        public bool IsOnline { get; set; } // Для зеленой точки (позже)
    }
}
