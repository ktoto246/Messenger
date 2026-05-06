import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_service.dart';
import '../config/app_config.dart';

class ChatService {
  static const String baseUrl = AppConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 1. Получить список чатов (С ОФЛАЙН КЭШЕМ)
  Future<List<dynamic>> fetchChats(int userId) async {
    final box = Hive.box('chats_box');
    final cacheKey = 'chats_$userId';

    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/chats'), headers: headers).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        await box.put(cacheKey, response.body);
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Нет сети! Достаем чаты из Hive 💾");
    }
    
    final cachedJson = box.get(cacheKey);
    if (cachedJson != null) return jsonDecode(cachedJson);
    return [];
  }

  // 2. Получить сообщения (С ОФЛАЙН КЭШЕМ)
  Future<List<dynamic>> fetchMessages(int chatId, {int skip = 0, int take = 30}) async {
    final box = Hive.box('messages_box');
    final cacheKey = 'msgs_${chatId}_$skip'; 

    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/chats/$chatId/messages?skip=$skip&take=$take'), headers: headers).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        if (skip == 0) await box.put(cacheKey, response.body); 
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Нет сети! Достаем сообщения из Hive 💾");
    }

    if (skip == 0) {
      final cachedJson = box.get(cacheKey);
      if (cachedJson != null) return jsonDecode(cachedJson);
    }
    return [];
  }

  // Получить профиль пользователя по ID (С ОФЛАЙН КЭШЕМ)
  Future<Map<String, dynamic>?> getUserProfile(int userId) async {
    final box = Hive.box('chats_box');
    final cacheKey = 'profile_$userId';

    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/users/$userId'), headers: headers).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        await box.put(cacheKey, response.body);
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Нет сети! Достаем профиль из Hive 💾");
    }
    
    final cachedJson = box.get(cacheKey);
    if (cachedJson != null) return jsonDecode(cachedJson);
    return null;
  }

  // 3. Отправить сообщение
  Future<void> sendMessage(int chatId, int userId, String text, {int? replyToMessageId, String? mediaUrl, String messageType = 'Text'}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/messages'),
        headers: headers,
        body: jsonEncode({"content": text, "replyToMessageId": replyToMessageId, "mediaUrl": mediaUrl, "messageType": messageType }),
      );
      if (response.statusCode != 200) throw Exception("Ошибка отправки: ${response.body}");
    } catch (e) { print("Ошибка: $e"); }
  }

  Future<String?> uploadMedia(File file) async {
    try {
      final token = await AuthService.getToken();
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/chats/uploadMedia'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var json = jsonDecode(responseData);
        return json['mediaUrl']; 
      }
    } catch (e) { print("Ошибка загрузки медиа: $e"); }
    return null;
  }

  // 4. Поиск пользователей
  Future<List<dynamic>> searchUsers(String query) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/users/search').replace(queryParameters: {'query': query});
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // 5. Создать личный чат
  Future<int?> createPrivateChat(int currentUserId, int targetUserId) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/chats/private'), headers: headers, body: jsonEncode(targetUserId));
    if (response.statusCode == 200) return jsonDecode(response.body)['chatId'];
    return null;
  }

  // 6. Создать групповой чат
  Future<int?> createGroupChat(int adminId, String groupName, List<int> memberIds) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl/chats/group'), headers: headers, body: jsonEncode({'groupName': groupName, 'memberUserIds': memberIds}));
    if (response.statusCode == 200) return jsonDecode(response.body)['chatId'];
    return null;
  }

  // Отметить сообщения в чате как прочитанные
  Future<void> markAsRead(int chatId, int userId) async {
    try { 
      final headers = await _getHeaders();
      await http.post(Uri.parse('$baseUrl/chats/$chatId/read'), headers: headers); 
    } catch (e) { print("Ошибка при отметке прочитанного: $e"); }
  }

  // 7. НАСТОЯЩЕЕ РЕДАКТИРОВАНИЕ
  Future<void> editMessage(int messageId, String newText) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(Uri.parse('$baseUrl/messages/$messageId'), headers: headers, body: jsonEncode(newText));
      if (response.statusCode != 200) throw Exception("Ошибка редактирования");
    } catch (e) { print("Ошибка: $e"); }
  }

  // 8. НАСТОЯЩЕЕ УДАЛЕНИЕ
  Future<void> deleteMessage(int messageId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(Uri.parse('$baseUrl/messages/$messageId'), headers: headers);
      if (response.statusCode != 200) throw Exception("Ошибка удаления");
    } catch (e) { print("Ошибка: $e"); }
  }

  // 9. ЗАКРЕПИТЬ / ОТКРЕПИТЬ СООБЩЕНИЕ
  Future<void> togglePinMessage(int messageId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(Uri.parse('$baseUrl/messages/$messageId/pin'), headers: headers);
      if (response.statusCode != 200) throw Exception("Ошибка закрепа");
    } catch (e) { print("Ошибка: $e"); }
  }

  // 10. ЗАКРЕПИТЬ / ОТКРЕПИТЬ ЧАТ
  Future<void> togglePinChat(int chatId, int userId) async {
    try {
      final headers = await _getHeaders();
      await http.put(Uri.parse('$baseUrl/chats/$chatId/pin'), headers: headers);
    } catch (e) { print("Ошибка закрепа чата: $e"); }
  }

  // 11. УДАЛИТЬ ЧАТ (Выйти из него)
  Future<void> deleteChat(int chatId, int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(Uri.parse('$baseUrl/chats/$chatId'), headers: headers);
      if (response.statusCode != 200) throw Exception("Ошибка удаления чата");
    } catch (e) { print("Ошибка: $e"); }
  }

  // 12. ПОЛУЧИТЬ ИЛИ СОЗДАТЬ "ИЗБРАННОЕ" (Saved Messages)
  Future<int?> getOrCreateSavedMessages(int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('$baseUrl/chats/saved-messages'), headers: headers);
      if (response.statusCode == 200) return jsonDecode(response.body)['chatId'];
    } catch (e) { print("Ошибка Избранного: $e"); }
    return null;
  }

  // 13. ОБНОВИТЬ ПРОФИЛЬ И НАСТРОЙКИ
  Future<void> updateProfile(int userId, Map<String, dynamic> updatedData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(Uri.parse('$baseUrl/users/$userId'), headers: headers, body: jsonEncode(updatedData));
      if (response.statusCode != 200) throw Exception("Ошибка обновления профиля");
    } catch (e) { print("Ошибка: $e"); }
  }

  // 14. ПОЛУЧИТЬ УЧАСТНИКОВ ГРУППЫ
  Future<List<dynamic>> getChatMembers(int chatId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/chats/$chatId/members'), headers: headers).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { print("Ошибка получения участников группы: $e"); }
    return [];
  }

  // 15. ОБНОВИТЬ ИНФОРМАЦИЮ О ГРУППЕ
  Future<void> updateGroupInfo(int chatId, {String? name, String? avatarUrl}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/chats/$chatId'),
        headers: headers,
        body: jsonEncode({
          if (name != null) 'groupName': name,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
        }),
      );
      if (response.statusCode != 200) throw Exception("Ошибка обновления группы");
    } catch (e) { print("Ошибка: $e"); }
  }

  // 16. ДОБАВИТЬ УЧАСТНИКОВ В ГРУППУ
  Future<void> addGroupMembers(int chatId, List<int> userIds) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('$baseUrl/chats/$chatId/participants'), headers: headers, body: jsonEncode(userIds));
      if (response.statusCode != 200) throw Exception("Ошибка добавления участников");
    } catch (e) { print("Ошибка: $e"); }
  }

  // 17. ИСКЛЮЧИТЬ УЧАСТНИКА (КИК)
  Future<void> kickMember(int chatId, int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(Uri.parse('$baseUrl/chats/$chatId/participants/$userId'), headers: headers);
      if (response.statusCode != 200) throw Exception("Ошибка исключения участника");
    } catch (e) { print("Ошибка: $e"); }
  }
}