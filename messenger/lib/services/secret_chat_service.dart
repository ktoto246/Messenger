import 'package:encrypt/encrypt.dart' as enc;

class SecretChatService {
  // В реальности здесь был бы обмен ключами по протоколу Signal или Diffie-Hellman.
  // Для демонстрации используем фиксированный ключ.
  static String encrypt(String text, String keyStr) {
    try {
      final key = enc.Key.fromUtf8(keyStr.padRight(32, ' ').substring(0, 32));
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key));
      final encrypted = encrypter.encrypt(text, iv: iv);
      return "AES:${iv.base64}:${encrypted.base64}";
    } catch (e) {
      return text;
    }
  }

  static String decrypt(String encryptedText, String keyStr) {
    if (!encryptedText.startsWith("AES:")) return encryptedText;
    try {
      final parts = encryptedText.split(':');
      if (parts.length != 3) return "[Ошибка формата]";
      
      final iv = enc.IV.fromBase64(parts[1]);
      final base64Content = parts[2];
      
      final key = enc.Key.fromUtf8(keyStr.padRight(32, ' ').substring(0, 32));
      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.decrypt64(base64Content, iv: iv);
    } catch (e) {
      return "[Ошибка расшифровки]";
    }
  }

  static bool isEncrypted(String text) {
    return text.startsWith("AES:");
  }
}
