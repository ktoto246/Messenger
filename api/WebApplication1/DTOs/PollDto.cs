namespace WebApplication1.DTOs
{
    public class PollDto
    {
        public string Question { get; set; } = "";
        public List<string> Options { get; set; } = new();
        public bool IsAnonymous { get; set; }
    }
}
