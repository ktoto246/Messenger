import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/chat_service.dart';
<<<<<<< HEAD
=======
import 'active_sessions_screen.dart';
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75

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
<<<<<<< HEAD
=======
  late int _privacyLastSeen;
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75

  @override
  void initState() {
    super.initState();
    // Инициализируем настройки из профиля (или ставим 0 по умолчанию)
    _privacyPhone = widget.userProfile['privacyPhone'] ?? widget.userProfile['PrivacyPhone'] ?? 0;
    _privacyAvatar = widget.userProfile['privacyAvatar'] ?? widget.userProfile['PrivacyAvatar'] ?? 0;
    _privacyMessages = widget.userProfile['privacyMessages'] ?? widget.userProfile['PrivacyMessages'] ?? 0;
<<<<<<< HEAD
=======
    _privacyLastSeen = widget.userProfile['privacyLastSeen'] ?? widget.userProfile['PrivacyLastSeen'] ?? 0;
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
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
          
<<<<<<< HEAD
=======
          const SizedBox(height: 25),

          // --- ВРЕМЯ ПОСЛЕДНЕГО ВХОДА ---
          _buildGroupHeader("ПОСЛЕДНЯЯ АКТИВНОСТЬ", headerTextColor),
          _buildPrivacyBlock([
            _buildPrivacyItem(title: "Все", value: 0, groupValue: _privacyLastSeen, textColor: textColor, dividerColor: dividerColor, onTap: () { setState(() => _privacyLastSeen = 0); _saveSetting('privacyLastSeen', 0, 'PrivacyLastSeen'); }),
            _buildPrivacyItem(title: "Мои контакты", value: 1, groupValue: _privacyLastSeen, textColor: textColor, dividerColor: dividerColor, onTap: () { setState(() => _privacyLastSeen = 1); _saveSetting('privacyLastSeen', 1, 'PrivacyLastSeen'); }),
            _buildPrivacyItem(title: "Никто", value: 2, groupValue: _privacyLastSeen, textColor: textColor, dividerColor: dividerColor, isLast: true, onTap: () { setState(() => _privacyLastSeen = 2); _saveSetting('privacyLastSeen', 2, 'PrivacyLastSeen'); }),
          ], blockColor),
          _buildGroupFooter("Выберите, кто может видеть время вашего последнего захода и статус «в сети».", headerTextColor),

          // --- УСТРОЙСТВА ---
          _buildGroupHeader("БЕЗОПАСНОСТЬ", headerTextColor),
          _buildPrivacyBlock([
            ListTile(
              leading: const Icon(Icons.devices, color: Colors.blue),
              title: Text("Активные сеансы", style: TextStyle(fontSize: 17, color: textColor)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveSessionsScreen())),
            ),
          ], blockColor),
          _buildGroupFooter("Просмотр и управление активными сессиями на других устройствах.", headerTextColor),

          // --- УДАЛЕНИЕ АККАУНТА ---
          _buildGroupHeader("УДАЛЕНИЕ АККАУНТА", headerTextColor),
          _buildPrivacyBlock([
            ListTile(
              title: Text("Если я не захожу...", style: TextStyle(fontSize: 17, color: textColor)),
              trailing: const Text("6 месяцев", style: TextStyle(color: Colors.blue, fontSize: 16)),
              onTap: () => _showSelfDestructPicker(textColor, blockColor),
            ),
            const Divider(height: 1, indent: 16),
            ListTile(
              title: const Text("Удалить мой аккаунт сейчас", style: TextStyle(fontSize: 17, color: Colors.red)),
              onTap: _confirmDeleteAccount,
            ),
          ], blockColor),
          _buildGroupFooter("Вы можете установить период, после которого ваш аккаунт будет удален автоматически при неактивности.", headerTextColor),

>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
          const SizedBox(height: 40),
        ],
      ),
    );
  }

<<<<<<< HEAD
=======
  void _showSelfDestructPicker(Color textColor, Color blockColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: blockColor,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text("Если я не захожу...", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          const Divider(),
          _destructItem("1 месяц", textColor),
          _destructItem("3 месяца", textColor),
          _destructItem("6 месяцев", textColor, isSelected: true),
          _destructItem("1 год", textColor),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _destructItem(String text, Color textColor, {bool isSelected = false}) {
    return ListTile(
      title: Text(text, style: TextStyle(color: textColor)),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () => Navigator.pop(context),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Удалить аккаунт?"),
        content: const Text("Это действие нельзя отменить. Все ваши сообщения, контакты и медиа будут удалены навсегда."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Отмена")),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("УДАЛИТЬ", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
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