import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'package:intl/intl.dart';

class CallHistoryScreen extends StatefulWidget {
  final int userId;

  const CallHistoryScreen({super.key, required this.userId});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final ChatService _chatService = ChatService();
  List<dynamic> _calls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    setState(() => _isLoading = true);
    final history = await _chatService.getCallHistory(widget.userId);
    if (mounted) {
      setState(() {
        _calls = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    await _chatService.clearCallHistory(widget.userId);
    _loadCalls();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F6),
      appBar: AppBar(
        title: const Text("Calls", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            onPressed: _calls.isEmpty ? null : _clearHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _calls.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.call_end, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text("No call history", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _calls.length,
                  separatorBuilder: (context, index) => Divider(height: 1, indent: 70, color: isDark ? Colors.white10 : Colors.grey[300]),
                  itemBuilder: (context, index) {
                    final call = _calls[index];
                    final partnerName = call['partnerName'] ?? 'Unknown';
                    final type = call['type'] ?? 'Outgoing'; // Incoming, Outgoing, Missed
                    final duration = call['duration'] ?? 0;
                    final time = DateTime.parse(call['time'] ?? DateTime.now().toString()).toLocal();
                    final bool isMissed = type == 'Missed';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isMissed ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                        child: Icon(
                          type == 'Incoming' ? Icons.call_received : (type == 'Missed' ? Icons.call_missed : Icons.call_made),
                          color: isMissed ? Colors.red : Colors.blue,
                          size: 20,
                        ),
                      ),
                      title: Text(partnerName, style: TextStyle(color: isMissed ? Colors.red : (isDark ? Colors.white : Colors.black), fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        "${DateFormat('MMM d, HH:mm').format(time)}${duration > 0 ? ' · ${duration}s' : ''}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                    );
                  },
                ),
    );
  }
}
