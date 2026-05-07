import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'dart:convert';

/// Экран активных сессий — просмотр и завершение сеансов
class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  List<dynamic> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadSessions() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/auth/sessions'),
        headers: headers,
      ).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        if (mounted) setState(() { _sessions = jsonDecode(response.body); _isLoading = false; });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Sessions error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _terminateSession(String sessionId) async {
    try {
      final headers = await _getHeaders();
      await http.delete(
        Uri.parse('${AppConfig.baseUrl}/auth/sessions/$sessionId'),
        headers: headers,
      );
      setState(() => _sessions.removeWhere((s) => (s['sessionId'] ?? s['id']) == sessionId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сессия завершена ✅')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _terminateAllOther() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Завершить все сессии?'),
        content: const Text('Все другие устройства будут отключены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Завершить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final headers = await _getHeaders();
      await http.delete(Uri.parse('${AppConfig.baseUrl}/auth/sessions/all'), headers: headers);
      _loadSessions();
    } catch (_) {}
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.endsWith('Z') ? dateStr : '${dateStr}Z').toLocal();
      return DateFormat('d MMM yyyy, HH:mm', 'ru').format(date);
    } catch (_) { return dateStr; }
  }

  IconData _deviceIcon(String? platform) {
    final p = (platform ?? '').toLowerCase();
    if (p.contains('android')) return Icons.android;
    if (p.contains('ios') || p.contains('iphone')) return Icons.phone_iphone;
    if (p.contains('windows')) return Icons.desktop_windows;
    if (p.contains('mac')) return Icons.laptop_mac;
    if (p.contains('web')) return Icons.web;
    return Icons.devices;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Активные сессии', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_sessions.length > 1)
            TextButton(
              onPressed: _terminateAllOther,
              child: const Text('Завершить все', style: TextStyle(color: Colors.red, fontSize: 13)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.devices, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Нет активных сессий', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (ctx, i) {
                    final session = _sessions[i];
                    final sessionId = session['sessionId'] ?? session['id'] ?? '';
                    final platform = session['platform'] ?? session['Platform'] ?? 'Неизвестно';
                    final device = session['deviceName'] ?? session['DeviceName'] ?? platform;
                    final ip = session['ipAddress'] ?? session['IpAddress'] ?? '—';
                    final lastActive = session['lastActiveAt'] ?? session['LastActiveAt'];
                    final isCurrent = session['isCurrent'] ?? session['IsCurrent'] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isCurrent ? Border.all(color: Colors.blue, width: 1.5) : null,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: isCurrent ? Colors.blue.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_deviceIcon(platform), color: isCurrent ? Colors.blue : Colors.grey, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(device, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                    if (isCurrent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
                                        child: const Text('Текущее', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('IP: $ip', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(_formatDate(lastActive?.toString()), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          if (!isCurrent)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Завершить',
                              onPressed: () => _terminateSession(sessionId.toString()),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
