namespace WebApplication1.DTOs
{
    public class MessageDto
    {
        public long MessageID { get; set; }
        public int SenderId { get; set; }
        public string Content { get; set; }
        public DateTime SentAt { get; set; }
        public bool IsMe { get; set; } // Чтобы Flutter знал, справа или слева рисовать
    }
}
