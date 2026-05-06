namespace WebApplication1.DTOs
{
    public class SendMessageDto
    {
        public int ChatId { get; set; }
        public int SenderId { get; set; }
        public string Content { get; set; }
        public long? ReplyToMessageId { get; set; }
        public string? MediaUrl { get; set; } 
        public string MessageType { get; set; } = "Text";
    }
}
