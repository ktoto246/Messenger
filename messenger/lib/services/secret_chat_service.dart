import 'package:encrypt/encrypt.dart' as enc;

class SecretChatService {
  // В реальности здесь был бы обмен ключами по протоколу Signal или Diffie-Hellman.
  // Для демонстрации используем фиксированный ключ.
  static final _key = enc.Key.fromUtf8('my_32_char_secret_key_1234567890'); // 32 chars
  static final _iv = enc.IV.fromLength(16);

  static String encrypt(String text, String key) {
    final encrypter = enc.Encrypter(enc.AES(_key));
    final encrypted = encrypter.encrypt(text, iv: _iv);
    return "AES:${encrypted.base64}";
  }

  static String decrypt(String encryptedText, String key) {
    if (!encryptedText.startsWith("AES:")) return encryptedText;
    try {
      final base64 = encryptedText.substring(4);
      final encrypter = enc.Encrypter(enc.AES(_key));
      return encrypter.decrypt64(base64, iv: _iv);
    } catch (e) {
      return "[Ошибка расшифровки]";
    }
  }

  static bool isEncrypted(String text) {
    return text.startsWith("AES:");
  }
}
