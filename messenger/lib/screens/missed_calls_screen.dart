import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';

/// Экран истории пропущенных и входящих звонков
class MissedCallsScreen extends StatefulWidget {
  final int currentUserId;
  const MissedCallsScreen({super.key, required this.currentUserId});

  @override
  State<MissedCallsScreen> createState() => _MissedCallsScreenState();
}

class _MissedCallsScreenState extends State<MissedCallsScreen> {
  final ChatService _chatService = ChatService();
  List<dynamic> _calls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCalls();
  }

  Future<void> _loadCalls() async {
    try {
      final calls = await _chatService.getCallHistory(widget.currentUserId);
      if (mounted) setState(() { _calls = calls; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.endsWith('Z') ? dateStr : '${dateStr}Z').toLocal();
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        return DateFormat('HH:mm').format(date);
      }
      return DateFormat('d MMM, HH:mm', 'ru').format(date);
    } catch (_) { return ''; }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return 'Не отвечено';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m мин $s сек' : '$s сек';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Звонки', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (_calls.isNotEmpty)
            TextButton(
              onPressed: () async {
                await _chatService.clearCallHistory(widget.currentUserId);
                if (mounted) setState(() => _calls = []);
              },
              child: const Text('Очистить', style: TextStyle(color: Colors.red)),
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
                      Icon(Icons.call, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Нет истории звонков', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _calls.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                  itemBuilder: (ctx, i) {
                    final call = _calls[i];
                    final isIncoming = call['isIncoming'] ?? call['IsIncoming'] ?? false;
                    final isMissed = call['isMissed'] ?? call['IsMissed'] ?? false;
                    final callerName = call['callerName'] ?? call['CallerName'] ?? 'Неизвестный';
                    final avatarUrl = call['avatarUrl'] ?? call['AvatarUrl'];
                    final duration = call['durationSeconds'] ?? call['DurationSeconds'];
                    final createdAt = call['createdAt'] ?? call['CreatedAt'];
                    final isVideo = call['isVideo'] ?? call['IsVideo'] ?? false;

                    Color iconColor = isMissed ? Colors.red : (isIncoming ? Colors.green : Colors.blue);
                    IconData directionIcon = isMissed
                        ? Icons.call_missed
                        : isIncoming
                            ? Icons.call_received
                            : Icons.call_made;

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blue.withValues(alpha: 0.15),
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl.toString())
                                : null,
                            child: avatarUrl == null
                                ? Text(
                                    callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: -2, right: -2,
                            child: Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                color: iconColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                              ),
                              child: Icon(directionIcon, color: Colors.white, size: 10),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        callerName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isMissed ? Colors.red : null,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Icon(isVideo ? Icons.videocam : Icons.call, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(duration is int ? duration : int.tryParse(duration?.toString() ?? '0')),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_formatTime(createdAt?.toString()), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          // Кнопка перезвонить
                          Icon(isVideo ? Icons.videocam_outlined : Icons.call_outlined, color: Colors.blue, size: 20),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
