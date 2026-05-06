import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';

/// Экран экспорта истории чата в .txt
class ExportChatScreen extends StatefulWidget {
  final int chatId;
  final String chatName;
  final int currentUserId;

  const ExportChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.currentUserId,
  });

  @override
  State<ExportChatScreen> createState() => _ExportChatScreenState();
}

class _ExportChatScreenState extends State<ExportChatScreen> {
  final ChatService _chatService = ChatService();
  bool _isExporting = false;
  String? _exportedText;
  bool _includeMedia = false;
  bool _includeTimestamps = true;

  String _formatMessage(Map<String, dynamic> msg) {
    final sender = msg['senderName'] ?? msg['SenderName'] ?? 'Неизвестный';
    final content = msg['contentText'] ?? msg['content'] ?? msg['Content'] ?? '';
    final sentAt = msg['sentAt'] ?? msg['SentAt'];
    final mediaUrl = msg['mediaUrl'] ?? msg['MediaUrl'];
    final msgType = (msg['messageType'] ?? msg['MessageType'] ?? 'Text').toString();

    final buffer = StringBuffer();

    if (_includeTimestamps && sentAt != null) {
      try {
        final date = DateTime.parse(sentAt.toString().endsWith('Z') ? sentAt.toString() : '${sentAt}Z').toLocal();
        buffer.write('[${DateFormat('dd.MM.yyyy HH:mm').format(date)}] ');
      } catch (_) {}
    }

    buffer.write('$sender: ');

    switch (msgType.toLowerCase()) {
      case 'image': buffer.write(_includeMedia ? '📷 Фото: $mediaUrl' : '📷 [Фото]'); break;
      case 'video': buffer.write(_includeMedia ? '🎥 Видео: $mediaUrl' : '🎥 [Видео]'); break;
      case 'audio': buffer.write('🎵 [Голосовое]'); break;
      case 'videonote': buffer.write('📹 [Видеокружок]'); break;
      case 'file': buffer.write(_includeMedia ? '📎 Файл: $content ($mediaUrl)' : '📎 Файл: $content'); break;
      case 'location':
        final coords = content.split(',');
        buffer.write(coords.length == 2 ? '📍 Геолокация: ${coords[0].trim()}, ${coords[1].trim()}' : '📍 [Геолокация]');
        break;
      case 'poll': buffer.write('📊 [Опрос]'); break;
      default:
        if (content.isNotEmpty) buffer.write(content);
    }

    return buffer.toString();
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      // Загружаем все сообщения (несколько страниц)
      final allMessages = <dynamic>[];
      dynamic lastId;
      while (true) {
        final batch = await _chatService.fetchMessages(
          widget.chatId,
          lastMessageId: lastId,
          take: 100,
        );
        if (batch.isEmpty) break;
        allMessages.addAll(batch);
        lastId = batch.last['messageID'] ?? batch.last['MessageID'];
        if (batch.length < 100) break;
      }

      // Строим текст в хронологическом порядке (список приходит в обратном)
      final reversed = allMessages.reversed.toList();
      final buffer = StringBuffer();
      buffer.writeln('═══════════════════════════════════');
      buffer.writeln('Чат: ${widget.chatName}');
      buffer.writeln('Сообщений: ${reversed.length}');
      buffer.writeln('Экспортировано: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}');
      buffer.writeln('═══════════════════════════════════');
      buffer.writeln();

      for (final msg in reversed) {
        buffer.writeln(_formatMessage(msg as Map<String, dynamic>));
      }

      if (mounted) setState(() { _exportedText = buffer.toString(); _isExporting = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Экспорт чата', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_exportedText != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Копировать',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _exportedText!));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано в буфер 📋')));
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Настройки
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildToggle('Включать временные метки', _includeTimestamps, (v) => setState(() => _includeTimestamps = v)),
                  const Divider(height: 1),
                  _buildToggle('Включать ссылки на медиа', _includeMedia, (v) => setState(() => _includeMedia = v)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_exportedText == null && !_isExporting)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Экспортировать историю', style: TextStyle(fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _export,
                ),
              ),
            if (_isExporting)
              const Center(child: Column(
                children: [
                  SizedBox(height: 32),
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Загружаем историю...', style: TextStyle(color: Colors.grey)),
                ],
              )),
            if (_exportedText != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Предпросмотр', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Повторить'),
                    onPressed: () { setState(() => _exportedText = null); _export(); },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _exportedText!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Копировать всё'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _exportedText!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('История скопирована 📋'), backgroundColor: Colors.green));
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15))),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: Colors.blue),
        ],
      ),
    );
  }
}
