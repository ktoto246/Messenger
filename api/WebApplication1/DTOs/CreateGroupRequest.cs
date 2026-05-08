namespace WebApplication1.DTOs
{
    public class CreateGroupRequest
    {
        public string GroupName { get; set; } = string.Empty;
        public List<int> MemberUserIds { get; set; } = new();
        public bool IsChannel { get; set; } = false;
    }
}
