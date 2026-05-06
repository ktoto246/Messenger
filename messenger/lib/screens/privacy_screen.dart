import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/chat_service.dart';

class PrivacyScreen extends StatefulWidget {
  final int currentUserId;
  final Map<String, dynamic> userProfile;

  const PrivacyScreen({super.key, required this.currentUserId, required this.userProfile});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final ChatService _chatService = ChatService();
  
  // 0 - Все, 1 - Мои контакты, 2 - Никто
  late int _privacyPhone;
  late int _privacyAvatar;
  late int _privacyMessages;

  @override
  void initState() {
    super.initState();
    // Инициализируем настройки из профиля (или ставим 0 по умолчанию)
    _privacyPhone = widget.userProfile['privacyPhone'] ?? widget.userProfile['PrivacyPhone'] ?? 0;
    _privacyAvatar = widget.userProfile['privacyAvatar'] ?? widget.userProfile['PrivacyAvatar'] ?? 0;
    _privacyMessages = widget.userProfile['privacyMessages'] ?? widget.userProfile['PrivacyMessages'] ?? 0;
  }

  // Общая функция сохранения настройки
  Future<void> _saveSetting(String key, int value, String dbFieldName) async {
    // 1. Обновляем локальный Hive (чтобы в настройки улетело)
    var box = Hive.isBoxOpen('settings_box') ? Hive.box('settings_box') : await Hive.openBox('settings_box');
    box.put(key, value);

    // 2. Тихо отправляем на C# бэкенд
    try {
      await _chatService.updateProfile(widget.currentUserId, {dbFieldName: value});
    } catch (e) {
      debugPrint("Ошибка сохранения приватности в БД: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌙 Адаптация темы
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? Colors.black : const Color(0xFFF2F2F6); // Системный фон
    Color blockColor = isDark ? const Color(0xFF1C1C1E) : Colors.white; // Цвет плашек
    Color textColor = isDark ? Colors.white : Colors.black;
    Color headerTextColor = isDark ? Colors.white54 : Colors.grey;
    Color dividerColor = isDark ? Colors.grey[800]! : const Color(0xFFC6C6C8); // Очень тонкий разделитель

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        // Адаптивная стрелочка назад
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: textColor), onPressed: () => Navigator.pop(context)),
        title: Text("Privacy", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          
          // --- КТО ВИДИТ МОЙ НОМЕР ---
          _buildGroupHeader("КТО ВИДИТ МОЙ НОМЕР", headerTextColor),
          _buildPrivacyBlock([
            _buildPrivacyItem(title: "Все", value: 0, groupValue: _privacyPhone, textColor: textColor, dividerColor: dividerColor, onTap: () { setState(() => _privacyPhone = 0); _saveSetting('privacyPhone', 0, 'PrivacyPhone'); }),
            _buildPrivacyItem(title: "Мои контакты", value: 1, groupValue: _privacyPhone, textColor: textColor, dividerColor: dividerColor, onTap: () { setState(() => _privacyPhone = 1); _saveSetting('privacyPhone', 1, 'PrivacyPhone'); }),
            _buildPrivacyItem(title: "Никто", value: 2, groupValue: _privacyPhone, textColor: textColor, dividerColor: dividerColor, isLast: true, onTap: () { setState(() => _privacyPhone = 2); _saveSetting('privacyPhone', 2, 'PrivacyPhone'); }),
          ], blockColor),
          _buildGroupFooter("Выберите, кто может видеть ваш номер телефона в профиле.", headerTextColor),

          const SizedBox(height: 25),

          // --- ФОТОГРАФИЯ ПРОФИЛЯ ---
          _buildGroupHeader("ФОТОГРАФИЯ ПРОФИЛЯ", headerTextColor),
          _buildPrivacyBlock([
            _buildPrivacyItem(title: "Все", value: 0, groupValue: _privacyAvatar, textColor: textColor, dividerColor: dividerColor, onTap: () { setState(() => _privacyAvatar = 0); _saveSetting('privacyAvatar', 0, 'PrivacyAvatar'); }),
            _buildPrivacyItem(title: "Мои контакты", value: 1, groupValue: _privacyAvatar, textColor: textColor, dividerColor: dividerColor, onTap: () { setState(() => _privacyAvatar = 1); _saveSetting('privacyAvatar', 1, 'PrivacyAvatar'); }),
            _buildPrivacyItem(title: "Никто", value: 2, groupValue: _privacyAvatar, textColor: textColor, dividerColor: dividerColor, isLast: true, onTap: () { setState(() => _privacyAvatar = 2); _saveSetting('privacyAvatar', 2, 'PrivacyAvatar'); }),
          ], blockColor),
          _buildGroupFooter("Выберите, кто может видеть вашу аватарку.", headerTextColor),

          const SizedBox(height: 25),

          // --- КТО МОЖЕТ МНЕ ПИСАТЬ ---
          _buildGroupHeader("КТО МОЖЕТ МНЕ ПИСАТЬ", headerTextColor),
          _buildPrivacyBlock([
            _buildPrivacyItem(title: "Все", value: 0, groupValue: _privacyMessages, textColor: textColor, dividerColor: dividerColor, onTap: () { setState(() => _privacyMessages = 0); _saveSetting('privacyMessages', 0, 'PrivacyMessages'); }),
            _buildPrivacyItem(title: "Мои контакты", value: 1, groupValue: _privacyMessages, textColor: textColor, dividerColor: dividerColor, onTap: () { setState(() => _privacyMessages = 1); _saveSetting('privacyMessages', 1, 'PrivacyMessages'); }),
            _buildPrivacyItem(title: "Никто", value: 2, groupValue: _privacyMessages, textColor: textColor, dividerColor: dividerColor, isLast: true, onTap: () { setState(() => _privacyMessages = 2); _saveSetting('privacyMessages', 2, 'PrivacyMessages'); }),
          ], blockColor),
          _buildGroupFooter("выберите, кто может отправлять вам сообщения. Остальные увидят иконку замочка 🔒.", headerTextColor),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Заголовок группы (маленькие серые буквы)
  Widget _buildGroupHeader(String text, Color color) {
    return Padding(padding: const EdgeInsets.only(left: 28, bottom: 8), child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w400)));
  }

  // Подвал группы (маленькие серые буквы)
  Widget _buildGroupFooter(String text, Color color) {
    return Padding(padding: const EdgeInsets.fromLTRB(28, 8, 16, 0), child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w400)));
  }

  // Обертка для блока настроек (белая плашка)
  Widget _buildPrivacyBlock(List<Widget> items, Color blockColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: blockColor, borderRadius: BorderRadius.circular(10)),
      child: Column(children: items),
    );
  }

  // Один пункт настройки с галочкой
  Widget _buildPrivacyItem({
    required String title,
    required int value,
    required int groupValue,
    required Color textColor,
    required Color dividerColor,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          ListTile(
            title: Text(title, style: TextStyle(fontSize: 17, color: textColor, fontWeight: FontWeight.w400)),
            // Синяя галочка iOS стиля, если выбрано
            trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF007AFF), size: 24) : null,
          ),
          if (!isLast) Divider(height: 1, indent: 16, color: dividerColor),
        ],
      ),
    );
  }
}