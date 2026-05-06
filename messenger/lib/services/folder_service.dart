import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

class FolderService {
  static const String baseUrl = '${AppConfig.baseUrl}/folders';

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<dynamic>> getFolders() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(baseUrl), headers: headers);
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) { debugPrint("Ошибка получения папок: $e"); }
    return [];
  }

  Future<void> createFolder(String name, List<int> chatIds, {String icon = 'folder'}) async {
    try {
      final headers = await _getHeaders();
      await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode({'folderName': name, 'chatIds': chatIds, 'iconName': icon}),
      );
    } catch (e) { debugPrint("Ошибка создания папки: $e"); }
  }

  Future<void> deleteFolder(int folderId) async {
    try {
      final headers = await _getHeaders();
      await http.delete(Uri.parse('$baseUrl/$folderId'), headers: headers);
    } catch (e) { debugPrint("Ошибка удаления папки: $e"); }
  }
}
