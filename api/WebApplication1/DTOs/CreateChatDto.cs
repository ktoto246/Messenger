namespace WebApplication1.DTOs
{
    // Для создания личного чата
    public class CreatePrivateChatDto
    {
        public int CurrentUserId { get; set; } // Кто создает
        public int TargetUserId { get; set; }  // С кем создает
    }

    // Для создания группы
    public class CreateGroupChatDto
    {
        public int AdminUserId { get; set; } // Создатель группы
        public string GroupName { get; set; }
        public List<int> MemberUserIds { get; set; } // Список ID участников
    }
}
