import 'dart:convert';

class SecretChatService {
  // В реальности здесь был бы обмен ключами по протоколу Signal или Diffie-Hellman.
  // Для демонстрации используем фиксированный ключ или имитацию.
  
  static String encrypt(String text, String key) {
    // Имитация шифрования: Base64 + префикс
    final bytes = utf8.encode(text);
    final base64 = base64Encode(bytes);
    return "ENC:$base64";
  }

  static String decrypt(String encryptedText, String key) {
    if (!encryptedText.startsWith("ENC:")) return encryptedText;
    try {
      final base64 = encryptedText.substring(4);
      final bytes = base64Decode(base64);
      return utf8.decode(bytes);
    } catch (e) {
      return "[Ошибка расшифровки]";
    }
  }

  static bool isEncrypted(String text) {
    return text.startsWith("ENC:");
  }
}
