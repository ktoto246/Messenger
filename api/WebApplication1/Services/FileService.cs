using System;
using System.IO;

namespace WebApplication1.Services
{
    public class FileService
    {
        private readonly string _uploadsFolder;

        public FileService()
        {
            _uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "App_Data", "uploads");
            if (!Directory.Exists(_uploadsFolder))
            {
                Directory.CreateDirectory(_uploadsFolder);
            }
        }

        public string GetUploadsFolder() => _uploadsFolder;

        public string GetFilePath(string fileName)
        {
            return Path.Combine(_uploadsFolder, fileName);
        }

        public void DeleteFile(string? fileUrl)
        {
            if (string.IsNullOrEmpty(fileUrl)) return;

            try
            {
                // Извлекаем имя файла из URL (например, /api/media/guid.jpg)
                var fileName = Path.GetFileName(fileUrl);
                var filePath = GetFilePath(fileName);

                if (File.Exists(filePath))
                {
                    File.Delete(filePath);
                }
            }
            catch (Exception ex)
            {
                // Логируем ошибку, но не прерываем выполнение
                Console.WriteLine($"Error deleting file {fileUrl}: {ex.Message}");
            }
        }
    }
}
