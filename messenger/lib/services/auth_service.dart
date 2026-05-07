import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
          
          // Сохраняем сессию в список аккаунтов
          await _saveSession(userId, token, data['displayName'], data['avatarUrl']);
          return true;
        }
      } 
      return false;
      
    } catch (e) {
      throw Exception('NETWORK_ERROR');
    }
  }

  Future<void> _saveSession(int userId, String token, String? displayName, String? avatarUrl) async {
    final sessionsJson = await _storage.read(key: 'sessions');
    List<dynamic> sessions = sessionsJson != null ? jsonDecode(sessionsJson) : [];
    
    // Удаляем старую сессию этого юзера если была
    sessions.removeWhere((s) => s['userId'] == userId);
    
    sessions.add({
      'userId': userId,
      'token': token,
      'displayName': displayName ?? 'User $userId',
      'avatarUrl': avatarUrl,
    });
    
    await _storage.write(key: 'sessions', value: jsonEncode(sessions));
  }

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final sessionsJson = await _storage.read(key: 'sessions');
    if (sessionsJson == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(sessionsJson));
  }

  Future<void> switchAccount(int userId) async {
    final sessions = await getAccounts();
    final session = sessions.firstWhere((s) => s['userId'] == userId);
    
    if (_isTokenExpired(session['token'])) {
      debugPrint("Сессия истекла для пользователя $userId");
      return;
    }
    
    await _storage.write(key: 'userId', value: userId.toString());
    await _storage.write(key: 'token', value: session['token']);
  }

  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload);
      
      if (data['exp'] == null) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(data['exp'] * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      debugPrint("JWT parse error: $e");
      return true;
    }
  }

  Future<void> removeAccount(int userId) async {
    final sessions = await getAccounts();
    sessions.removeWhere((s) => s['userId'] == userId);
    await _storage.write(key: 'sessions', value: jsonEncode(sessions));
    
    final currentId = await getCurrentUserId();
    if (currentId == userId) {
      if (sessions.isNotEmpty) {
        await switchAccount(sessions.first['userId']);
      } else {
        await logout();
      }
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
    final userId = await getCurrentUserId();
    if (userId != null) await removeAccount(userId);
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
      debugPrint("Ошибка обновления статуса: $e");
    }
  }
}