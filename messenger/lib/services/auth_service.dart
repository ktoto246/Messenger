import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AuthService {
  static const String baseUrl = '${AppConfig.baseUrl}/auth'; 

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        int? userId = data['userId'];
        String? token = data['token']; // 🛡️ Получаем JWT токен

        if (userId != null && token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('userId', userId);
          await prefs.setString('token', token); // 🛡️ Сохраняем токен
          return true;
        }
      } 
      return false;
      
    } catch (e) {
      throw Exception('NETWORK_ERROR');
    }
  }
  
  Future<bool> register(String email, String password, String displayName, String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'displayName': displayName,
          'username': username,
        }),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('NETWORK_ERROR');
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<int?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('token');
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      final token = await getToken();
      await http.post(
        Uri.parse('$baseUrl/status?isOnline=$isOnline'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      print("Ошибка обновления статуса: $e");
    }
  }
}