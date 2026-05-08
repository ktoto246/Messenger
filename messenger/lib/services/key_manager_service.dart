import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManagerService {
  static const _storage = FlutterSecureStorage();

  // Сохраняем приватный ключ юзера
  static Future<void> savePrivateKey(String privateKey) async {
    await _storage.write(key: 'my_private_key', value: privateKey);
  }

  // Достаем приватный ключ
  static Future<String?> getPrivateKey() async {
    return await _storage.read(key: 'my_private_key');
  }

  // Сохраняем вычисленный общий секрет для конкретного чата,
  // чтобы не считать его каждый раз при отправке сообщения
  static Future<void> saveSharedSecret(String chatId, String sharedSecret) async {
    await _storage.write(key: 'shared_secret_$chatId', value: sharedSecret);
  }

  static Future<String?> getSharedSecret(String chatId) async {
    return await _storage.read(key: 'shared_secret_$chatId');
  }
}