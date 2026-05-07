import 'dart:convert';
import 'package:flutter/material.dart';
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
      debugPrint("Нет сети! Достаем чаты из Hive 💾");
    }
    
    final cachedJson = box.get(cacheKey);
    if (cachedJson != null) return jsonDecode(cachedJson);
    return [];
  }

  // 2. Получить сообщения (С ОФЛАЙН КЭШЕМ)
  Future<List<dynamic>> fetchMessages(int chatId, {int? lastMessageId, int take = 30}) async {
    final box = Hive.box('messages_box');
    final cacheKey = 'msgs_${chatId}_0'; 

    try {
      final headers = await _getHeaders();
      final url = lastMessageId != null 
          ? '$baseUrl/chats/$chatId/messages?lastMessageId=$lastMessageId&take=$take'
          : '$baseUrl/chats/$chatId/messages?take=$take';

      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        if (lastMessageId == null) await box.put(cacheKey, response.body); 
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Нет сети! Достаем сообщения из Hive 💾");
    }

    if (lastMessageId == null) {
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
      debugPrint("Нет сети! Достаем профиль из Hive 💾");
    }
    
    final cachedJson = box.get(cacheKey);
    if (cachedJson != null) return jsonDecode(cachedJson);
    return null;
  }

  // 3. Отправить сообщение (С ПОДДЕРЖКОЙ ОФЛАЙНА)
  Future<void> sendMessage(int chatId, int userId, String text, {int? replyToMessageId, String? mediaUrl, String messageType = 'Text', DateTime? scheduledAt, bool isViewOnce = false}) async {
    final body = {
      "content": text, 
      "replyToMessageId": replyToMessageId, 
      "mediaUrl": mediaUrl, 
      "messageType": messageType,
      "scheduledAt": scheduledAt?.toIso8601String(),
      "isViewOnce": isViewOnce
    };

    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/messages'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 401) throw Exception("UNAUTHORIZED");
      if (response.statusCode != 200) throw Exception("SERVER_ERROR");
    } on Exception catch (e) {
      final errStr = e.toString();
      // Не кешируем ошибки сервера (400/500), только сетевые таймауты
      if (errStr.contains("UNAUTHORIZED")) throw Exception("SESSION_EXPIRED");
      if (errStr.contains("SERVER_ERROR")) rethrow;
      // Сетевая ошибка — сохраняем в очередь
      debugPrint("Сообщение не отправлено. Сохраняем в очередь 💾: $e");
      final box = await Hive.openBox('pending_messages');
      await box.add({
        "chatId": chatId,
        "userId": userId,
        "data": body,
        "timestamp": DateTime.now().millisecondsSinceEpoch
      });
    }
  }

  // СИНХРОНИЗАЦИЯ ОФЛАЙН СООБЩЕНИЙ
  Future<void> syncPendingMessages() async {
    final box = await Hive.openBox('pending_messages');
    if (box.isEmpty) return;

    final List<dynamic> keys = box.keys.toList();
    for (var key in keys) {
      final msg = box.get(key);
      try {
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('$baseUrl/chats/${msg['chatId']}/messages'),
          headers: headers,
          body: jsonEncode(msg['data']),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          await box.delete(key);
          debugPrint("Офлайн сообщение успешно отправлено! ✅");
        }
      } catch (e) {
        break; // Если всё еще нет сети, прерываем цикл
      }
    }
  }

  Future<void> markViewOnceAsViewed(int messageId) async {
    try {
      final headers = await _getHeaders();
      await http.post(Uri.parse('$baseUrl/messages/$messageId/view-once'), headers: headers);
    } catch (e) { debugPrint("Ошибка markViewOnceAsViewed: $e"); }
  }

  Future<String?> translateMessage(int messageId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('$baseUrl/messages/$messageId/translate'), headers: headers);
      if (response.statusCode == 200) return jsonDecode(response.body)['translatedText'];
    } catch (e) { debugPrint("Ошибка перевода: $e"); }
    return null;
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
    } catch (e) { debugPrint("Ошибка загрузки медиа: $e"); }
    return null;
  }

  // 4. Поиск пользователей
  Future<List<dynamic>> searchUsers(String query) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/users/search').replace(queryParameters: {'query': query});
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { debugPrint("Ошибка поиска пользователей: $e"); }
    return [];
  }

  // 5. Создать личный чат
  Future<int?> createPrivateChat(int currentUserId, int targetUserId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('$baseUrl/chats/private'), headers: headers, body: jsonEncode(targetUserId)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return jsonDecode(response.body)['chatId'];
    } catch (e) { debugPrint("Ошибка создания личного чата: $e"); }
    return null;
  }

  // 6. Создать групповой чат или канал
  Future<int?> createGroupChat(int adminId, String groupName, List<int> memberIds, {bool isChannel = false}) async {
    final headers = await _getHeaders();
    final body = jsonEncode({
      'groupName': groupName,
      'memberUserIds': memberIds,
      'isChannel': isChannel
    });
    final response = await http.post(Uri.parse('$baseUrl/chats/group'), headers: headers, body: body);
    if (response.statusCode == 200) return jsonDecode(response.body)['chatId'];
    return null;
  }

  // Отметить сообщения в чате как прочитанные
  Future<void> markAsRead(int chatId, int userId) async {
    try { 
      final headers = await _getHeaders();
      await http.post(Uri.parse('$baseUrl/chats/$chatId/read'), headers: headers); 
    } catch (e) { debugPrint("Ошибка при отметке прочитанного: $e"); }
  }

  // 7. НАСТОЯЩЕЕ РЕДАКТИРОВАНИЕ
  Future<void> editMessage(int messageId, String newText) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(Uri.parse('$baseUrl/messages/$messageId'), headers: headers, body: jsonEncode(newText));
      if (response.statusCode != 200) throw Exception("Ошибка редактирования");
    } catch (e) { debugPrint("Ошибка: $e"); }
  }

  // 8. НАСТОЯЩЕЕ УДАЛЕНИЕ
  Future<void> deleteMessage(int messageId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(Uri.parse('$baseUrl/messages/$messageId'), headers: headers);
      if (response.statusCode != 200) throw Exception("Ошибка удаления");
    } catch (e) { debugPrint("Ошибка: $e"); }
  }

  // 9. ЗАКРЕПИТЬ / ОТКРЕПИТЬ СООБЩЕНИЕ
  Future<void> togglePinMessage(int messageId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(Uri.parse('$baseUrl/messages/$messageId/pin'), headers: headers);
      if (response.statusCode != 200) throw Exception("Ошибка закрепа");
    } catch (e) { debugPrint("Ошибка: $e"); }
  }

  // 10. ЗАКРЕПИТЬ / ОТКРЕПИТЬ ЧАТ
  Future<void> togglePinChat(int chatId, int userId) async {
    try {
      final headers = await _getHeaders();
      await http.put(Uri.parse('$baseUrl/chats/$chatId/pin'), headers: headers);
    } catch (e) { debugPrint("Ошибка закрепа чата: $e"); }
  }

  // 11. УДАЛИТЬ ЧАТ (Выйти из него)
  Future<void> deleteChat(int chatId, int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(Uri.parse('$baseUrl/chats/$chatId'), headers: headers);
      if (response.statusCode != 200) throw Exception("Ошибка удаления чата");
    } catch (e) { debugPrint("Ошибка: $e"); }
  }

  // 12. ПОЛУЧИТЬ ИЛИ СОЗДАТЬ "ИЗБРАННОЕ" (Saved Messages)
  Future<int?> getOrCreateSavedMessages(int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('$baseUrl/chats/saved-messages'), headers: headers);
      if (response.statusCode == 200) return jsonDecode(response.body)['chatId'];
    } catch (e) { debugPrint("Ошибка Избранного: $e"); }
    return null;
  }

  // 13. ОБНОВИТЬ ПРОФИЛЬ И НАСТРОЙКИ
  Future<void> updateProfile(int userId, Map<String, dynamic> updatedData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(Uri.parse('$baseUrl/users/$userId'), headers: headers, body: jsonEncode(updatedData));
      if (response.statusCode != 200) throw Exception("Ошибка обновления профиля");
    } catch (e) { debugPrint("Ошибка: $e"); }
  }

  // 14. ПОЛУЧИТЬ УЧАСТНИКОВ ГРУППЫ
  Future<List<dynamic>> getChatMembers(int chatId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/chats/$chatId/members'), headers: headers).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { debugPrint("Ошибка получения участников группы: $e"); }
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
          'groupName': ?name,
          'avatarUrl': ?avatarUrl,
        }),
      );
      if (response.statusCode != 200) throw Exception("Ошибка обновления группы");
    } catch (e) { debugPrint("Ошибка: $e"); }
  }

  // 16. ДОБАВИТЬ УЧАСТНИКОВ В ГРУППУ
  Future<void> addGroupMembers(int chatId, List<int> userIds) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('$baseUrl/chats/$chatId/participants'), headers: headers, body: jsonEncode(userIds));
      if (response.statusCode != 200) throw Exception("Ошибка добавления участников");
    } catch (e) { debugPrint("Ошибка: $e"); }
  }

  // 17. ИСКЛЮЧИТЬ УЧАСТНИКА (КИК)
  Future<void> kickMember(int chatId, int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(Uri.parse('$baseUrl/chats/$chatId/participants/$userId'), headers: headers);
      if (response.statusCode != 200) throw Exception("Ошибка исключения участника");
    } catch (e) { debugPrint("Ошибка: $e"); }
  }

  // 18. ТУГГЛ РЕАКЦИИ
  Future<void> toggleReaction(int messageId, String emoji) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/messages/$messageId/reactions'),
        headers: headers,
        body: jsonEncode(emoji),
      );
      if (response.statusCode != 200) throw Exception("Ошибка реакции");
    } catch (e) { debugPrint("Ошибка реакции: $e"); }
  }

  // 19. ГЛОБАЛЬНЫЙ ПОИСК СООБЩЕНИЙ
  Future<List<dynamic>> searchMessages(String query) async {
    try {
      final headers = await _getHeaders();
      // Используем Uri для корректного кодирования спецсимволов в query
      final uri = Uri.parse('$baseUrl/messages/search').replace(queryParameters: {'query': query});
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { debugPrint("Ошибка поиска: $e"); }
    return [];
  }

  // 20. ОЧИСТИТЬ ИСТОРИЮ ЧАТА (локально + на сервере)
  Future<void> clearChatHistory(int chatId) async {
    try {
      final headers = await _getHeaders();
      await http.delete(Uri.parse('$baseUrl/chats/$chatId/messages'), headers: headers);
    } catch (e) { debugPrint("Ошибка очистки чата: $e"); }
    // Очищаем локальный кэш
    final box = Hive.box('messages_box');
    await box.delete('msgs_${chatId}_0');
  }

  // 21. АВТОУДАЛЕНИЕ СООБЩЕНИЙ
  Future<void> setAutoDelete(int chatId, int? seconds) async {
    try {
      final headers = await _getHeaders();
      await http.put(
        Uri.parse('$baseUrl/chats/$chatId/auto-delete'),
        headers: headers,
        body: jsonEncode({'autoDeleteSeconds': seconds}),
      );
    } catch (e) { debugPrint("Ошибка setAutoDelete: $e"); }
  }

  // 22. СОЗДАТЬ ОПРОС
  Future<void> createPoll(int chatId, int userId, Map<String, dynamic> pollData) async {
    try {
      final headers = await _getHeaders();
      await http.post(
        Uri.parse('$baseUrl/chats/$chatId/polls'),
        headers: headers,
        body: jsonEncode(pollData),
      );
    } catch (e) { debugPrint("Ошибка createPoll: $e"); }
  }

  // 23. ПРОГОЛОСОВАТЬ В ОПРОСЕ
  Future<void> votePoll(int pollId, int optionIndex) async {
    try {
      final headers = await _getHeaders();
      await http.post(
        Uri.parse('$baseUrl/polls/$pollId/vote'),
        headers: headers,
        body: jsonEncode({'optionIndex': optionIndex}),
      );
    } catch (e) { debugPrint("Ошибка votePoll: $e"); }
  }

  // 24. ОТПРАВИТЬ ФАЙЛ (документ)
  Future<String?> uploadFile(File file) async {
    try {
      final token = await AuthService.getToken();
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/chats/uploadMedia'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        var data = jsonDecode(await response.stream.bytesToString());
        return data['mediaUrl'];
      }
    } catch (e) { debugPrint("Ошибка uploadFile: $e"); }
    return null;
  }

  // 25. ЧЕРНОВИКИ (локально через Hive)
  Future<void> saveMessageDraft(int chatId, String text) async {
    final box = Hive.isBoxOpen('drafts_box') ? Hive.box('drafts_box') : await Hive.openBox('drafts_box');
    if (text.trim().isEmpty) {
      await box.delete('draft_$chatId');
    } else {
      await box.put('draft_$chatId', text);
    }
  }

  Future<String?> getMessageDraft(int chatId) async {
    final box = Hive.isBoxOpen('drafts_box') ? Hive.box('drafts_box') : await Hive.openBox('drafts_box');
    return box.get('draft_$chatId') as String?;
  }

  // 26. АРХИВ ЧАТОВ (локально через Hive)
  Future<void> archiveChat(int chatId, bool archive) async {
    final box = Hive.isBoxOpen('settings_box') ? Hive.box('settings_box') : await Hive.openBox('settings_box');
    final List<dynamic> archived = List<dynamic>.from(box.get('archived_chats', defaultValue: <dynamic>[]) ?? []);
    if (archive) {
      if (!archived.contains(chatId)) archived.add(chatId);
    } else {
      archived.remove(chatId);
    }
    await box.put('archived_chats', archived);
    // Уведомляем сервер (опционально)
    try {
      final headers = await _getHeaders();
      await http.put(Uri.parse('$baseUrl/chats/$chatId/archive'), headers: headers, body: jsonEncode(archive));
    } catch (_) {}
  }

  Future<List<int>> getArchivedChatIds() async {
    final box = Hive.isBoxOpen('settings_box') ? Hive.box('settings_box') : await Hive.openBox('settings_box');
    final raw = box.get('archived_chats', defaultValue: <dynamic>[]) ?? [];
    return List<int>.from(raw.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0));
  }

  // 27. ИСТОРИЯ ПРАВОК СООБЩЕНИЯ
  Future<List<dynamic>> getMessageEditHistory(dynamic messageId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/messages/$messageId/history'), headers: headers);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { debugPrint('getMessageEditHistory error: $e'); }
    return [];
  }

  // 28. ИСТОРИЯ ЗВОНКОВ
  Future<List<dynamic>> getCallHistory(int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/calls/history/$userId'), headers: headers);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { debugPrint('getCallHistory error: $e'); }
    return [];
  }

  Future<void> clearCallHistory(int userId) async {
    try {
      final headers = await _getHeaders();
      await http.delete(Uri.parse('$baseUrl/calls/history/$userId'), headers: headers);
    } catch (e) { debugPrint('clearCallHistory error: $e'); }
  }
}