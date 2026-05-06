import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';

/// Виджет отображения опроса в пузыре сообщения
class PollBubble extends StatefulWidget {
  final Map<String, dynamic> pollData;
  final int currentUserId;
  final bool isMe;

  const PollBubble({
    super.key,
    required this.pollData,
    required this.currentUserId,
    required this.isMe,
  });

  @override
  State<PollBubble> createState() => _PollBubbleState();
}

class _PollBubbleState extends State<PollBubble> {
  final ChatService _chatService = ChatService();
  int? _myVote;
  bool _isVoting = false;
  late Map<String, dynamic> _poll;

  @override
  void initState() {
    super.initState();
    _poll = widget.pollData;
    // Ищем, проголосовал ли уже текущий пользователь
    final options = _poll['options'] ?? _poll['Options'] ?? [];
    for (int i = 0; i < options.length; i++) {
      final voters = options[i]['voters'] ?? options[i]['Voters'] ?? [];
      if (voters.contains(widget.currentUserId)) {
        _myVote = i;
        break;
      }
    }
  }

  Future<void> _vote(int optionIndex) async {
    if (_myVote != null || _isVoting) return;
    setState(() => _isVoting = true);
    final pollId = _poll['pollId'] ?? _poll['PollId'] ?? _poll['id'];
    await _chatService.votePoll(pollId, optionIndex);
    if (mounted) {
      setState(() {
        _myVote = optionIndex;
        _isVoting = false;
        // Локально увеличиваем счётчик
        final opts = _poll['options'] ?? _poll['Options'] ?? [];
        if (optionIndex < opts.length) {
          opts[optionIndex]['votes'] = (opts[optionIndex]['votes'] ?? 0) + 1;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = _poll['question'] ?? _poll['Question'] ?? 'Опрос';
    final options = List<dynamic>.from(_poll['options'] ?? _poll['Options'] ?? []);
    final isAnonymous = _poll['isAnonymous'] ?? _poll['IsAnonymous'] ?? false;
    final bool hasVoted = _myVote != null;

    int totalVotes = 0;
    for (final opt in options) {
      totalVotes += (opt['votes'] ?? opt['Votes'] ?? 0) as int;
    }

    final Color textColor = widget.isMe ? Colors.white : Colors.black;
    final Color subColor = widget.isMe ? Colors.white70 : Colors.black54;
    final Color barColor = widget.isMe ? Colors.white.withValues(alpha: 0.4) : Colors.blue.withValues(alpha: 0.3);
    final Color barFill = widget.isMe ? Colors.white.withValues(alpha: 0.7) : Colors.blue;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(children: [
              Icon(Icons.poll, size: 18, color: subColor),
              const SizedBox(width: 6),
              Flexible(child: Text(isAnonymous ? 'Анонимный опрос' : 'Опрос', style: TextStyle(fontSize: 12, color: subColor))),
            ]),
            const SizedBox(height: 6),
            Text(question, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 10),
            // Варианты ответа
            ...options.asMap().entries.map((entry) {
              final i = entry.key;
              final opt = entry.value;
              final text = opt['text'] ?? opt['Text'] ?? '';
              final votes = (opt['votes'] ?? opt['Votes'] ?? 0) as int;
              final percent = totalVotes > 0 ? votes / totalVotes : 0.0;
              final isMyChoice = _myVote == i;

              return GestureDetector(
                onTap: hasVoted ? null : () => _vote(i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(10),
                    border: isMyChoice ? Border.all(color: barFill, width: 1.5) : null,
                  ),
                  child: Stack(
                    children: [
                      // Прогресс-бар позади
                      if (hasVoted)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percent,
                            child: Container(
                              decoration: BoxDecoration(
                                color: barFill.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(text, style: TextStyle(color: textColor, fontSize: 14, fontWeight: isMyChoice ? FontWeight.bold : FontWeight.normal)),
                          ),
                          if (hasVoted) ...[
                            const SizedBox(width: 8),
                            if (isMyChoice) Icon(Icons.check_circle, size: 16, color: barFill),
                            const SizedBox(width: 4),
                            Text('${(percent * 100).round()}%', style: TextStyle(color: subColor, fontSize: 12)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Text(
              '$totalVotes ${_pluralVotes(totalVotes)}${isAnonymous ? ' · Анонимно' : ''}',
              style: TextStyle(fontSize: 11, color: subColor),
            ),
          ],
        ),
      ),
    );
  }

  String _pluralVotes(int n) {
    if (n % 100 >= 11 && n % 100 <= 14) return 'голосов';
    switch (n % 10) {
      case 1: return 'голос';
      case 2: case 3: case 4: return 'голоса';
      default: return 'голосов';
    }
  }
}
