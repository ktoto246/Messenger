import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Бизнес-профиль — часы работы, быстрые ответы, приветствие
class BusinessProfileScreen extends StatefulWidget {
  final int currentUserId;
  const BusinessProfileScreen({super.key, required this.currentUserId});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  bool _isBusinessAccount = false;
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _welcomeController = TextEditingController();
  final TextEditingController _awayController = TextEditingController();
  List<Map<String, String>> _quickReplies = [];
  bool _isOpenNow = true;
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 18, minute: 0);
  List<bool> _workDays = [false, true, true, true, true, true, false]; // Вс-Сб

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _welcomeController.dispose();
    _awayController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  Future<void> _loadProfile() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/users/${widget.currentUserId}/business'),
        headers: headers,
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _isBusinessAccount = data['isBusinessAccount'] ?? false;
          _bioController.text = data['businessBio'] ?? '';
          _welcomeController.text = data['welcomeMessage'] ?? 'Привет! Как я могу помочь?';
          _awayController.text = data['awayMessage'] ?? 'Сейчас не в сети, отвечу как можно скорее.';
          final qr = data['quickReplies'] as List? ?? [];
          _quickReplies = qr.map<Map<String, String>>((e) => {'key': e['key'] ?? '', 'text': e['text'] ?? ''}).toList();
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final headers = await _getHeaders();
      await http.put(
        Uri.parse('${AppConfig.baseUrl}/users/${widget.currentUserId}/business'),
        headers: headers,
        body: jsonEncode({
          'isBusinessAccount': _isBusinessAccount,
          'businessBio': _bioController.text.trim(),
          'welcomeMessage': _welcomeController.text.trim(),
          'awayMessage': _awayController.text.trim(),
          'quickReplies': _quickReplies,
          'workingHours': {
            'openHour': _openTime.hour,
            'openMinute': _openTime.minute,
            'closeHour': _closeTime.hour,
            'closeMinute': _closeTime.minute,
            'workDays': _workDays,
          },
        }),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено ✅'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addQuickReply() {
    final keyCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Быстрый ответ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: '/ключ (например /help)')),
            const SizedBox(height: 12),
            TextField(controller: textCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Текст ответа')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              if (keyCtrl.text.isNotEmpty && textCtrl.text.isNotEmpty) {
                setState(() => _quickReplies.add({'key': keyCtrl.text, 'text': textCtrl.text}));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color card = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final Color bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        title: const Text('Бизнес-профиль', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          _isSaving
              ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
              : TextButton(onPressed: _isBusinessAccount ? _save : null, child: const Text('Сохранить', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Включение бизнес-режима
                _section(card, child: SwitchListTile.adaptive(
                  title: const Text('Бизнес-аккаунт', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Часы работы, быстрые ответы, приветствие'),
                  value: _isBusinessAccount,
                  onChanged: (v) => setState(() => _isBusinessAccount = v),
                  activeColor: Colors.blue,
                )),

                if (_isBusinessAccount) ...[
                  const SizedBox(height: 16),
                  _label('ОПИСАНИЕ БИЗНЕСА'),
                  _section(card, child: TextField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Чем вы занимаетесь?', border: InputBorder.none),
                  )),

                  const SizedBox(height: 16),
                  _label('ЧАСЫ РАБОТЫ'),
                  _section(card, child: Column(
                    children: [
                      // Дни недели
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'].asMap().entries.map((e) {
                          final i = e.key;
                          final day = e.value;
                          return GestureDetector(
                            onTap: () => setState(() => _workDays[i] = !_workDays[i]),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: _workDays[i] ? Colors.blue : Colors.grey.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: Text(day, style: TextStyle(color: _workDays[i] ? Colors.white : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _timePicker('Открыть', _openTime, (t) => setState(() => _openTime = t))),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('—', style: TextStyle(fontSize: 20, color: Colors.grey))),
                          Expanded(child: _timePicker('Закрыть', _closeTime, (t) => setState(() => _closeTime = t))),
                        ],
                      ),
                    ],
                  )),

                  const SizedBox(height: 16),
                  _label('АВТОМАТИЧЕСКИЕ СООБЩЕНИЯ'),
                  _section(card, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Приветствие', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                      TextField(controller: _welcomeController, maxLines: 2, decoration: const InputDecoration(border: InputBorder.none)),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      const Text('Когда не в сети', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                      TextField(controller: _awayController, maxLines: 2, decoration: const InputDecoration(border: InputBorder.none)),
                    ],
                  )),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _label('БЫСТРЫЕ ОТВЕТЫ'),
                      IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: _addQuickReply),
                    ],
                  ),
                  if (_quickReplies.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
                      child: const Text('Нет быстрых ответов. Нажмите + чтобы добавить.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    _section(card, child: Column(
                      children: _quickReplies.asMap().entries.map((e) {
                        final i = e.key;
                        final qr = e.value;
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(qr['key'] ?? '', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          title: Text(qr['text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.red),
                            onPressed: () => setState(() => _quickReplies.removeAt(i)),
                          ),
                        );
                      }).toList(),
                    )),
                ],
              ],
            ),
    );
  }

  Widget _section(Color color, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 0.5)),
    );
  }

  Widget _timePicker(String label, TimeOfDay time, ValueChanged<TimeOfDay> onPicked) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.blue)),
            Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
      ),
    );
  }
}
