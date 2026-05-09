import 'dart:async';
import 'dart:math';

/// Mock STT Service for VEIN Messenger
class STTService {
  static final List<String> _mockPhrases = [
    "Привет, как дела? Давай встретимся завтра в пять.",
    "Я сейчас занят, перезвоню позже через десять минут.",
    "Отличная идея! Я согласен на этот проект.",
    "Не забудь купить молоко и хлеб по дороге домой.",
    "Голосовое сообщение зашифровано, но я его расшифровал.",
    "Внимание: это тестовая транскрипция сообщения.",
  ];

  static Future<String> transcribe(String url) async {
    // Симуляция задержки обработки
    await Future.delayed(const Duration(seconds: 2));
    
    // Возвращаем случайную фразу (в реальности тут был бы вызов Whisper API или Google STT)
    final random = Random();
    return _mockPhrases[random.nextInt(_mockPhrases.length)];
  }
}
