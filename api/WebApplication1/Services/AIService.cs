using System.Threading.Tasks;

namespace WebApplication1.Services
{
    public interface IAIService
    {
        Task<string> TranslateAsync(string text, string targetLanguage = "RU");
        Task<string> TranscribeAsync(string audioPath);
        Task<string> SummarizeAsync(IEnumerable<string> messages);
    }

    public class AIServiceStub : IAIService
    {
        public async Task<string> TranslateAsync(string text, string targetLanguage = "RU")
        {
            // В реальности здесь будет вызов Google Translate / DeepL / LibreTranslate
            return $"[Перевод: {targetLanguage}] {text}";
        }

        public async Task<string> TranscribeAsync(string audioPath)
        {
            // В реальности здесь будет вызов Whisper AI / Google STT
            return "Это расшифрованное голосовое сообщение (Whisper AI Stub).";
        }

        public async Task<string> SummarizeAsync(IEnumerable<string> messages)
        {
            // В реальности здесь будет вызов GPT-4 / Claude / Gemini
            return "Краткое содержание: Участники обсуждали текущий прогресс, технические детали реализации API и планы на следующую неделю. Тон беседы конструктивный.";
        }
    }
}
