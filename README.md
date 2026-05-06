# 🚀 Real-time Messenger Project

Дипломный/коммерческий проект мессенджера. Поддерживает работу в реальном времени, кэширование, темную тему и работу с группами.

## 🛠 Стек технологий
* **Frontend:** Flutter, Dart, Hive (локальная БД/кэш), SignalR Client.
* **Backend:** C#, ASP.NET Core, SignalR (WebSockets).
* **Database:** SQL Server / Entity Framework Core.

---

## ⚙️ Как развернуть Бэкенд (C#)
1. Открой решение (`.sln`) в Visual Studio.
2. Открой консоль (`cmd`), введи `ipconfig` и узнай свой локальный IPv4-адрес.
3. Зайди в `Properties/launchSettings.json` и поменяй IP-адрес в параметре `applicationUrl` на свой. Пример: `"applicationUrl": "http://192.168.x.x:5121"`.
4. Настрой строку подключения к БД в `appsettings.json`.
5. Примени миграции к базе данных (если используем EF Core).
6. Жми F5 или запускай сервер.

---

## 📱 Как развернуть Фронтенд (Flutter)
1. Убедись, что установлен Flutter SDK.
2. В терминале в папке с Flutter-проектом выполни команду, чтобы подтянуть зависимости:
   ```bash
   flutter pub get