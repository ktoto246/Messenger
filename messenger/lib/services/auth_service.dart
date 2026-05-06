import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class AuthService {
  static const String baseUrl = '${AppConfig.baseUrl}/auth'; 
  final _storage = const FlutterSecureStorage();
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
          await _storage.write(key: 'userId', value: userId.toString());
          await _storage.write(key: 'token', value: token);
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
    const storage = FlutterSecureStorage();
    return await storage.read(key: 'token');
  }

  Future<int?> getCurrentUserId() async {
    String? id = await _storage.read(key: 'userId');
    return id != null ? int.tryParse(id) : null;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'userId');
    await _storage.delete(key: 'token');
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