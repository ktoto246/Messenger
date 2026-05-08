using System;
using System.IO;

namespace WebApplication1.Services
{
    public class FileService
    {
        private readonly string _uploadsFolder;

        public FileService()
        {
            _uploadsFolder = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "App_Data", "uploads"));
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
                var fileName = Path.GetFileName(fileUrl);
                if (string.IsNullOrEmpty(fileName) || fileName.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0)
                    return;

                var filePath = Path.GetFullPath(GetFilePath(fileName));
                if (!filePath.StartsWith(_uploadsFolder, StringComparison.OrdinalIgnoreCase))
                    return;

                if (File.Exists(filePath))
                    File.Delete(filePath);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error deleting file {fileUrl}: {ex.Message}");
            }
        }
    }
}
