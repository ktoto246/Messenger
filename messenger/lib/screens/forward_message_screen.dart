import 'package:flutter/material.dart';
import '../services/chat_service.dart';

/// Экран выбора чата для пересылки сообщения — Telegram-стиль
class ForwardMessageScreen extends StatefulWidget {
  final int currentUserId;
  final String textToForward;
  final String? mediaUrlToForward;
  final String? originalMessageType; // <-- Добавили оригинальный тип

  const ForwardMessageScreen({
    super.key,
    required this.currentUserId,
    required this.textToForward,
    this.mediaUrlToForward,
    this.originalMessageType, // <-- Принимаем его тут
  });

  @override
  State<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<ForwardMessageScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allChats = [];
  List<dynamic> _filteredChats = [];
  final Set<int> _selectedChatIds = {};
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _searchController.addListener(_filterChats);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    final chats = await _chatService.fetchChats(widget.currentUserId);
    if (mounted) {
      setState(() {
        _allChats = chats;
        _filteredChats = chats;
        _isLoading = false;
      });
    }
  }

  void _filterChats() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredChats = q.isEmpty
          ? _allChats
          : _allChats.where((c) {
              final name = (c['chatName'] ?? c['ChatName'] ?? '').toString().toLowerCase();
              return name.contains(q);
            }).toList();
    });
  }

  Future<void> _forward() async {
    if (_selectedChatIds.isEmpty) return;
    setState(() => _isSending = true);

    for (final chatId in _selectedChatIds) {
      try {
        if (widget.mediaUrlToForward != null) {
          await _chatService.sendMessage(
            chatId,
            widget.textToForward,
            mediaUrl: widget.mediaUrlToForward,
            // Скармливаем оригинальный тип, иначе бэк сдохнет или фронт не отрендерит
            messageType: widget.originalMessageType ?? 'Image', 
          );
        } else {
          await _chatService.sendMessage(chatId, widget.textToForward);
        }
      } catch (e) {
        debugPrint('Forward error: $e');
      }
    }

    if (!mounted) return;
    setState(() => _isSending = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Переслано в ${_selectedChatIds.length} ${_plural(_selectedChatIds.length)}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _plural(int n) {
    if (n % 100 >= 11 && n % 100 <= 14) return 'чатов';
    switch (n % 10) {
      case 1: return 'чат';
      case 2: case 3: case 4: return 'чата';
      default: return 'чатов';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Переслать', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_selectedChatIds.isNotEmpty)
              Text(
                'Выбрано: ${_selectedChatIds.length}',
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
          ],
        ),
        actions: [
          if (_selectedChatIds.isNotEmpty)
            _isSending
                ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton(
                    onPressed: _forward,
                    child: const Text('Переслать', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
        ],
      ),
      body: Column(
        children: [
          // Превью пересылаемого
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            child: Row(
              children: [
                Container(width: 3, height: 36, color: Colors.blue, margin: const EdgeInsets.only(right: 10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Пересылаемое сообщение', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w500)),
                      Text(
                        widget.textToForward.isEmpty ? '📎 Медиафайл' : widget.textToForward,
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Поиск
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // Список чатов
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredChats.length,
                    itemBuilder: (ctx, i) {
                      final chat = _filteredChats[i];
                      final chatId = chat['chatID'] ?? chat['chatId'] ?? chat['ChatID'];
                      final name = chat['chatName'] ?? chat['ChatName'] ?? 'Чат';
                      final isGroup = chat['isGroup'] ?? chat['IsGroup'] ?? false;
                      final isSelected = _selectedChatIds.contains(chatId);

                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.withValues(alpha: 0.2),
                              child: Icon(isGroup ? Icons.group : Icons.person, color: Colors.blue),
                            ),
                            if (isSelected)
                              Positioned(
                                right: -2, bottom: -2,
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                                ),
                              ),
                          ],
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        onTap: () {
                          if (chatId == null) return;
                          setState(() {
                            if (isSelected) {
                              _selectedChatIds.remove(chatId);
                            } else {
                              _selectedChatIds.add(chatId);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}