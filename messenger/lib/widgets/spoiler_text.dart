import 'package:flutter/material.dart';

/// Виджет спойлера — скрытый текст, раскрывается по тапу
/// Telegram-стиль: текст скрыт мозаикой/блюром, тап — показать
class SpoilerText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final bool isMe;

  const SpoilerText({
    super.key,
    required this.text,
    this.style,
    this.isMe = false,
  });

  @override
  State<SpoilerText> createState() => _SpoilerTextState();
}

class _SpoilerTextState extends State<SpoilerText> with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _opacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reveal() {
    setState(() => _isRevealed = true);
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ?? const TextStyle(fontSize: 16, color: Colors.white);

    if (_isRevealed) {
      return FadeTransition(
        opacity: _opacity,
        child: Text(widget.text, style: baseStyle),
      );
    }

    // Спойлер: текст скрыт под полупрозрачными точками (имитация Telegram)
    return GestureDetector(
      onTap: _reveal,
      child: Stack(
        children: [
          // Настоящий текст — невидимый, задаёт размер
          Opacity(
            opacity: 0,
            child: Text(widget.text, style: baseStyle),
          ),
          // Маска-спойлер
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isMe
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.grey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    '👁 Нажмите чтобы показать',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isMe ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Парсер текста на обычный и спойлер-части
/// Telegram формат: ||текст спойлера||
class SpoilerParser {
  static List<InlineSpan> parse(String text, TextStyle baseStyle, bool isMe) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\|\|(.+?)\|\|');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Обычный текст до спойлера
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: baseStyle));
      }
      // Спойлер
      final spoilerText = match.group(1)!;
      spans.add(WidgetSpan(
        child: SpoilerText(text: spoilerText, style: baseStyle, isMe: isMe),
      ));
      lastEnd = match.end;
    }

    // Остаток текста
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
  }

  static bool hasSpoiler(String text) => text.contains('||');
}
