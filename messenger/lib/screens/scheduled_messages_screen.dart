import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'package:intl/intl.dart';

class ScheduledMessagesScreen extends StatefulWidget {
  final int chatId;
  final String chatName;

  const ScheduledMessagesScreen({super.key, required this.chatId, required this.chatName});

  @override
  State<ScheduledMessagesScreen> createState() => _ScheduledMessagesScreenState();
}

class _ScheduledMessagesScreenState extends State<ScheduledMessagesScreen> {
  final ChatService _chatService = ChatService();
  List<dynamic> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final msgs = await _chatService.getScheduledMessages(widget.chatId);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteMessage(int msgId) async {
    await _chatService.deleteScheduledMessage(msgId);
    _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F6),
      appBar: AppBar(
        title: Column(
          children: [
            const Text("Scheduled Messages", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(widget.chatName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text("No scheduled messages", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final text = msg['contentText'] ?? '';
                    final scheduledAt = DateTime.parse(msg['scheduledAt']).toLocal();
                    final msgId = msg['messageID'] ?? msg['MessageID'];

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(text, style: TextStyle(color: textColor, fontSize: 16)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Will be sent on ${DateFormat('MMM d, HH:mm').format(scheduledAt)}",
                                style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _deleteMessage(msgId),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
