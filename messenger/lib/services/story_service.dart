import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

class StoryService {
  static const String baseUrl = '${AppConfig.baseUrl}/stories';

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Получить список историй
  Future<List<dynamic>> getStories() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse(baseUrl), headers: headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Ошибка загрузки сторис: $e");
    }
    return [];
  }

  /// Загрузить медиафайл и опубликовать историю
  Future<bool> uploadAndPostStory(File file, {String? caption}) async {
    try {
      final token = await AuthService.getToken();
      // 1. Загружаем медиафайл
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/chats/uploadMedia'),
      );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final uploadResponse = await request.send();

      if (uploadResponse.statusCode != 200) return false;
      final uploadData = jsonDecode(await uploadResponse.stream.bytesToString());
      final mediaUrl = uploadData['mediaUrl'] as String?;
      if (mediaUrl == null) return false;

      // 2. Публикуем историю — используем queryParameters для безопасного кодирования
      final headers = await _getHeaders();
      final uri = Uri.parse(baseUrl).replace(
        queryParameters: {if (caption != null && caption.isNotEmpty) 'caption': caption},
      );
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(mediaUrl),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Ошибка публикации сторис: $e");
      return false;
    }
  }

  /// Отметить историю как просмотренную
  Future<void> markStoryViewed(int storyId) async {
    try {
      final headers = await _getHeaders();
      await http.post(
        Uri.parse('$baseUrl/$storyId/view'),
        headers: headers,
      );
    } catch (e) {
      debugPrint("Ошибка отметки просмотра сторис: $e");
    }
  }
}
