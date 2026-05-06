import 'dart:convert';
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

  Future<List<dynamic>> getStories() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(baseUrl), headers: headers);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { print("Ошибка сторис: $e"); }
    return [];
  }

  Future<void> postStory(String mediaUrl, {String? caption}) async {
    try {
      final headers = await _getHeaders();
      await http.post(
        Uri.parse('$baseUrl?caption=${caption ?? ""}'),
        headers: headers,
        body: jsonEncode(mediaUrl),
      );
    } catch (e) { print("Ошибка создания сторис: $e"); }
  }
}
