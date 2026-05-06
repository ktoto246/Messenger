import 'package:flutter/material.dart';

/// Экран создания опроса — Telegram-стиль
class CreatePollScreen extends StatefulWidget {
  const CreatePollScreen({super.key});

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _isAnonymous = true;
  bool _isMultipleChoice = false;
  bool _isQuiz = false;
  int? _correctAnswer; // Для режима викторины

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) { c.dispose(); }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 10) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
      if (_correctAnswer == index) _correctAnswer = null;
      if (_correctAnswer != null && _correctAnswer! > index) _correctAnswer = _correctAnswer! - 1;
    });
  }

  Map<String, dynamic>? _build() {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите вопрос')));
      return null;
    }
    final options = _optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавьте минимум 2 варианта ответа')));
      return null;
    }
    if (_isQuiz && _correctAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите правильный ответ для викторины')));
      return null;
    }
    return {
      'question': question,
      'options': options.map((t) => {'text': t, 'votes': 0}).toList(),
      'isAnonymous': _isAnonymous,
      'isMultipleChoice': _isMultipleChoice,
      'isQuiz': _isQuiz,
      'correctAnswer': _correctAnswer,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final Color card = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена', style: TextStyle(color: Colors.blue)),
        ),
        leadingWidth: 80,
        title: const Text('Создать опрос', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              final data = _build();
              if (data != null) Navigator.pop(context, data);
            },
            child: const Text('Готово', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Вопрос
          _buildCard(card, child: TextField(
            controller: _questionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Вопрос',
              border: InputBorder.none,
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            ),
          )),
          const SizedBox(height: 16),

          // Варианты
          Text('ВАРИАНТЫ ОТВЕТА', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          ..._optionControllers.asMap().entries.map((e) {
            final i = e.key;
            final controller = e.value;
            return _buildCard(card, child: Row(
              children: [
                if (_isQuiz)
                  GestureDetector(
                    onTap: () => setState(() => _correctAnswer = i),
                    child: Icon(
                      _correctAnswer == i ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _correctAnswer == i ? Colors.green : Colors.grey,
                      size: 22,
                    ),
                  ),
                if (_isQuiz) const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Вариант ${i + 1}',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ),
                if (_optionControllers.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
                    onPressed: () => _removeOption(i),
                  ),
              ],
            ));
          }),

          if (_optionControllers.length < 10)
            TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add, color: Colors.blue),
              label: const Text('Добавить вариант', style: TextStyle(color: Colors.blue)),
            ),
          const SizedBox(height: 16),

          // Настройки
          Text('НАСТРОЙКИ', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _buildCard(card, child: Column(
            children: [
              _buildSwitch('Анонимное голосование', _isAnonymous, (v) => setState(() => _isAnonymous = v)),
              const Divider(height: 1),
              _buildSwitch('Несколько ответов', _isMultipleChoice, (v) => setState(() => _isMultipleChoice = v)),
              const Divider(height: 1),
              _buildSwitch('Режим викторины', _isQuiz, (v) => setState(() {
                _isQuiz = v;
                if (!v) _correctAnswer = null;
              })),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildCard(Color color, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }

  Widget _buildSwitch(String title, bool value, ValueChanged<bool> onChanged) {
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
