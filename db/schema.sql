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
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);

-- =============================================
-- ТАБЛИЦА ЧАТОВ (Соответствует Chat.cs)
-- =============================================
CREATE TABLE Chats (
    ChatID INT PRIMARY KEY IDENTITY(1,1),
    GroupName NVARCHAR(100) NULL,
    AvatarUrl NVARCHAR(MAX) NULL,
    IsGroup BIT NOT NULL DEFAULT 0,
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
    MessageType NVARCHAR(50) NOT NULL DEFAULT 'Text',
    SentAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IsRead BIT NOT NULL DEFAULT 0,
    IsDeleted BIT NOT NULL DEFAULT 0,
    IsEdited BIT NOT NULL DEFAULT 0,
    ReplyToMessageId BIGINT NULL,
    MediaUrl NVARCHAR(MAX) NULL, -- В БД оставляем имя как в [Column("MediaUrl")]
    IsPinned BIT NOT NULL DEFAULT 0,
    FOREIGN KEY (ChatID) REFERENCES Chats(ChatID) ON DELETE CASCADE,
    FOREIGN KEY (SenderUserID) REFERENCES Users(UserID)
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
-- ИНДЕКСЫ ДЛЯ УСКОРЕНИЯ ПОИСКА
-- =======================================================
CREATE INDEX IX_Users_Email ON Users(Email);
CREATE INDEX IX_Users_Username ON Users(Username);
CREATE INDEX IX_Users_DisplayName ON Users(DisplayName);
CREATE INDEX IX_Messages_ChatID ON Messages(ChatID);
CREATE INDEX IX_ChatParticipants_UserID ON ChatParticipants(UserID);

PRINT 'База MessengerAppDB создана и заполнена! 🔥';