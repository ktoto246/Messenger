USE master;
GO

-- 1. УДАЛЯЕМ СТАРУЮ БАЗУ (если она есть), чтобы не было конфликтов
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'MessengerAppDB')
BEGIN
    ALTER DATABASE MessengerAppDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MessengerAppDB;
END
GO

-- 2. СОЗДАЕМ БАЗУ ЗАНОВО
CREATE DATABASE MessengerAppDB;
GO

USE MessengerAppDB;
GO

-- =============================================
-- ТАБЛИЦА ПОЛЬЗОВАТЕЛЕЙ (Соответствует User.cs)
-- =============================================
CREATE TABLE Users (
    UserID INT PRIMARY KEY IDENTITY(1,1),
    Email NVARCHAR(100) NOT NULL UNIQUE,
    Password NVARCHAR(100) NOT NULL,
    DisplayName NVARCHAR(100) NOT NULL,
    Username NVARCHAR(50) NULL,
    PhoneNumber NVARCHAR(20) NULL,
    Bio NVARCHAR(500) NULL,
    AvatarUrl NVARCHAR(MAX) NULL,
    IsDarkMode BIT NOT NULL DEFAULT 0,
    IsOnline BIT NOT NULL DEFAULT 0,
    LastActive DATETIME2 NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    FcmToken NVARCHAR(MAX) NULL -- 🔔 Для Push-уведомлений
);

-- =============================================
-- ТАБЛИЦЫ ПАПОК (Для группировки чатов)
-- =============================================
CREATE TABLE ChatFolders (
    FolderID INT PRIMARY KEY IDENTITY(1,1),
    UserID INT NOT NULL,
    FolderName NVARCHAR(50) NOT NULL,
    IconName NVARCHAR(50) DEFAULT 'folder',
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT FK_Folders_Users FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE
);

CREATE TABLE ChatFolderItems (
    FolderID INT NOT NULL,
    ChatID INT NOT NULL,
    PRIMARY KEY (FolderID, ChatID),
    CONSTRAINT FK_FolderItems_Folders FOREIGN KEY (FolderID) REFERENCES ChatFolders(FolderID) ON DELETE CASCADE,
    CONSTRAINT FK_FolderItems_Chats FOREIGN KEY (ChatID) REFERENCES Chats(ChatID) ON DELETE CASCADE
);

-- =============================================
-- ТАБЛИЦА ЧАТОВ (Соответствует Chat.cs)
-- =============================================
CREATE TABLE Chats (
    ChatID INT PRIMARY KEY IDENTITY(1,1),
    GroupName NVARCHAR(100) NULL,
    AvatarUrl NVARCHAR(MAX) NULL,
    IsGroup BIT NOT NULL DEFAULT 0,
    IsChannel BIT NOT NULL DEFAULT 0, -- 📢 Новое: Флаг канала
    CreatorUserId INT NULL, -- 👑 Создатель канала/группы
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

-- =============================================
-- ТАБЛИЦА УЧАСТНИКОВ (Соответствует ChatParticipant.cs)
-- =============================================
CREATE TABLE ChatParticipants (
    ChatID INT NOT NULL,
    UserID INT NOT NULL,
    JoinedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IsPinned BIT NOT NULL DEFAULT 0,
    IsAdmin BIT NOT NULL DEFAULT 0,
    PRIMARY KEY (ChatID, UserID),
    FOREIGN KEY (ChatID) REFERENCES Chats(ChatID) ON DELETE CASCADE,
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE
);

-- =============================================
-- ТАБЛИЦА СООБЩЕНИЙ (Соответствует Message.cs)
-- =============================================
CREATE TABLE Messages (
    MessageID BIGINT PRIMARY KEY IDENTITY(1,1),
    ChatID INT NOT NULL,
    SenderUserID INT NOT NULL,
    ContentText NVARCHAR(MAX) NULL,
    TranslatedText NVARCHAR(MAX) NULL, -- 🌍 Новое: Перевод сообщения
    MessageType NVARCHAR(50) NOT NULL DEFAULT 'Text',
    SentAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    ScheduledAt DATETIME2 NULL, -- 🕒 Новое: Отложенная отправка
    IsRead BIT NOT NULL DEFAULT 0,
    ReadAt DATETIME2 NULL,
    IsDelivered BIT NOT NULL DEFAULT 0,
    DeliveredAt DATETIME2 NULL,
    IsViewOnce BIT NOT NULL DEFAULT 0, -- 👻 Новое: Исчезающее медиа
    ViewedAt DATETIME2 NULL, -- 🕒 Новое: Когда исчезающее медиа было просмотрено
    IsDeleted BIT NOT NULL DEFAULT 0,
    IsEdited BIT NOT NULL DEFAULT 0,
    ReplyToMessageId BIGINT NULL,
    MediaUrl NVARCHAR(MAX) NULL,
    IsPinned BIT NOT NULL DEFAULT 0,
    FOREIGN KEY (ChatID) REFERENCES Chats(ChatID) ON DELETE CASCADE,
    FOREIGN KEY (SenderUserID) REFERENCES Users(UserID)
);

-- =============================================
-- ТАБЛИЦА СТОРИС (Stories)
-- =============================================
CREATE TABLE Stories (
    StoryID INT PRIMARY KEY IDENTITY(1,1),
    UserID INT NOT NULL,
    MediaUrl NVARCHAR(MAX) NOT NULL,
    Caption NVARCHAR(200) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    ExpiresAt DATETIME2 NOT NULL, -- Обычно CreatedAt + 24 часа
    IsDeleted BIT NOT NULL DEFAULT 0,
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE
);

-- =============================================
-- ТАБЛИЦА ТЕМ ПОЛЬЗОВАТЕЛЯ (Themes)
-- =============================================
CREATE TABLE UserThemes (
    UserID INT PRIMARY KEY,
    PrimaryColor NVARCHAR(20) DEFAULT '#007AFF',
    BgImageUrl NVARCHAR(MAX) NULL,
    BubbleOpacity FLOAT DEFAULT 0.9,
    IsGlassmorphism BIT DEFAULT 1,
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE
);
GO

-- =======================================================
-- ЗАПОЛНЕНИЕ ТЕСТОВЫМИ ДАННЫМИ (БЕЗ ФОТО)
-- =======================================================

-- Пользователи
INSERT INTO Users (Email, Password, DisplayName, Username, Bio, IsOnline)
VALUES 
('alice@test.com', '123456', 'Alice Smith', '@alice', 'Разработчик на Flutter', 1),
('bob@test.com', '123456', 'Bob Johnson', '@bob_dev', 'C# Backend Engineer', 0),
('charlie@test.com', '123456', 'Charlie Brown', '@charlie_ux', 'Дизайнер интерфейсов', 1);

-- Чаты (1 личный и 1 группа)
INSERT INTO Chats (IsGroup, GroupName) VALUES (0, NULL); -- ChatID 1
INSERT INTO Chats (IsGroup, GroupName) VALUES (1, 'Команда Диплома 🚀'); -- ChatID 2

-- Участники
INSERT INTO ChatParticipants (ChatID, UserID) VALUES (1, 1), (1, 2); -- Alice и Bob в ЛС
INSERT INTO ChatParticipants (ChatID, UserID) VALUES (2, 1), (2, 2), (2, 3); -- Все в группе

-- Сообщения (Текст и примеры для ответов)
INSERT INTO Messages (ChatID, SenderUserID, MessageType, ContentText, SentAt, IsRead)
VALUES 
(1, 1, 'Text', 'Привет, Боб! Как там наша база данных?', GETUTCDATE(), 1),
(1, 2, 'Text', 'Привет! Всё пересоздал, теперь летит!', GETUTCDATE(), 1);

-- Сообщение с закрепом
INSERT INTO Messages (ChatID, SenderUserID, MessageType, ContentText, IsPinned, SentAt)
VALUES (1, 1, 'Text', 'Важное: завтра созвон в 10:00', 1, GETUTCDATE());

-- Ответ на сообщение (ReplyToMessageId ссылается на MessageID = 1)
INSERT INTO Messages (ChatID, SenderUserID, MessageType, ContentText, ReplyToMessageId, SentAt)
VALUES (1, 2, 'Text', 'Да, база — это база.', 1, GETUTCDATE());

-- =======================================================
-- РЕАКЦИИ НА СООБЩЕНИЯ
-- =======================================================
CREATE TABLE MessageReactions (
    ReactionID BIGINT PRIMARY KEY IDENTITY(1,1),
    MessageID BIGINT NOT NULL,
    UserID INT NOT NULL,
    Emoji NVARCHAR(10) NOT NULL,
    CreatedAt DATETIME DEFAULT GETUTCDATE(),
    CONSTRAINT FK_Reactions_Messages FOREIGN KEY (MessageID) REFERENCES Messages(MessageID) ON DELETE CASCADE,
    CONSTRAINT FK_Reactions_Users FOREIGN KEY (UserID) REFERENCES Users(UserID)
);
CREATE INDEX IX_MessageReactions_MessageID ON MessageReactions(MessageID);

-- =======================================================
-- ИНДЕКСЫ ДЛЯ УСКОРЕНИЯ ПОИСКА
-- =======================================================
CREATE INDEX IX_Users_Email ON Users(Email);
CREATE INDEX IX_Users_Username ON Users(Username);
CREATE INDEX IX_Users_DisplayName ON Users(DisplayName);
CREATE INDEX IX_Messages_ChatID ON Messages(ChatID);
CREATE INDEX IX_ChatParticipants_UserID ON ChatParticipants(UserID);

PRINT 'База MessengerAppDB создана и заполнена! 🔥';