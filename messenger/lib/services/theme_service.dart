import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

class ThemeService {
  static final ThemeService instance = ThemeService._internal();
  ThemeService._internal();

  static const String baseUrl = '${AppConfig.baseUrl}/themes';

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>?> getTheme() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(baseUrl), headers: headers);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { debugPrint("Ошибка тем: $e"); }
    return null;
  }

  Future<void> updateTheme(Map<String, dynamic> themeData) async {
    try {
      final headers = await _getHeaders();
      await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(themeData),
      );
    } catch (e) { debugPrint("Ошибка сохранения темы: $e"); }
  }
}
