import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'privacy_screen.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../services/chat_service.dart'; // Для отправки на бэкенд
import '../main.dart'; // Подключаем наш themeNotifier

class SettingsScreen extends StatefulWidget {
  final int currentUserId;
  final Map<String, dynamic> userProfile;

  const SettingsScreen({super.key, required this.currentUserId, required this.userProfile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ChatService _chatService = ChatService();
  late bool isDarkMode;

  @override
  void initState() {
    super.initState();
    // Устанавливаем положение тумблера при входе
    isDarkMode = widget.userProfile['isDarkMode'] ?? themeNotifier.value;
  }

  // Функция умной очистки кэша (оставляем без изменений)
  void _showClearCacheDialog() async {
    int fakeCacheSize = 450; 
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storage, size: 50, color: Colors.blue),
              const SizedBox(height: 16),
              const Text("Использование памяти", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "Медиафайлы (фото, видео, ГС) занимают около $fakeCacheSize КБ на устройстве.", 
                textAlign: TextAlign.center, 
                style: const TextStyle(color: Colors.grey, fontSize: 16)
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, 
                    padding: const EdgeInsets.symmetric(vertical: 14), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () async {
                    await DefaultCacheManager().emptyCache();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Медиа-кэш успешно очищен! 🧹"), backgroundColor: Colors.green)
                      );
                    }
                  },
                  child: const Text("Очистить кэш медиа", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // 🪄 МАГИЯ СМЕНЫ ТЕМЫ 🪄
  void _toggleTheme(bool newValue) async {
    setState(() {
      isDarkMode = newValue;
      widget.userProfile['isDarkMode'] = newValue; // Обновляем в профиле
    });

    // 1. Мгновенно перекрашиваем все приложение!
    themeNotifier.value = newValue;

    // 2. Сохраняем в память телефона
    var box = Hive.box('settings_box');
    box.put('isDarkMode', newValue);

    // 3. Тихо отправляем на сервер твоему API
    try {
      await _chatService.updateProfile(widget.currentUserId, {'IsDarkMode': newValue});
    } catch (e) {
      debugPrint("Ошибка сохранения темы в БД: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Определяем текущую тему, чтобы правильно покрасить фон настроек
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDark ? Colors.black : const Color(0xFFF2F2F6);
    Color blockColor = isDark ? const Color(0xFF1C1C1E) : Colors.white; // Цвет плашек

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Настройки", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          
          // Блок 1
          _buildSettingsBlock([
            _buildSettingsItem(icon: Icons.notifications, color: Colors.redAccent, title: "Уведомления и звуки", onTap: () {}),
            _buildSettingsItem(
              icon: Icons.lock, color: Colors.grey, title: "Конфиденциальность", 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PrivacyScreen(currentUserId: widget.currentUserId, userProfile: widget.userProfile))),
            ),
            _buildSettingsItem(icon: Icons.data_usage, color: Colors.green, title: "Данные и память", onTap: _showClearCacheDialog),
          ], blockColor),

          const SizedBox(height: 35),

          // Блок 2
          const Padding(padding: EdgeInsets.only(left: 16, bottom: 8), child: Text("ОФОРМЛЕНИЕ", style: TextStyle(color: Colors.grey, fontSize: 13))),
          _buildSettingsBlock([
            _buildSettingsItem(icon: Icons.color_lens, color: Colors.blue, title: "Тема и цвета", onTap: () {}), 
            
            // 👇 ПОДКЛЮЧАЕМ ТУМБЛЕР 👇
            _buildSettingsItem(
              icon: Icons.nightlight_round, 
              color: Colors.black, 
              title: "Ночной режим", 
              trailing: Switch.adaptive(
                value: isDarkMode, 
                onChanged: _toggleTheme, // Вызываем функцию при клике
                activeColor: Colors.blue,
              )
            ),
          ], blockColor),
        ],
      ),
    );
  }

  Widget _buildSettingsBlock(List<Widget> items, Color blockColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: blockColor, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: items.asMap().entries.map((entry) {
          int index = entry.key;
          Widget item = entry.value;
          return Column(
            children: [
              item,
              if (index < items.length - 1) const Divider(height: 1, indent: 56, color: Color(0xFF38383A)), // Сделал полоску чуть темнее
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsItem({required IconData icon, required Color color, required String title, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      onTap: trailing == null ? onTap : null, 
      leading: Container(width: 30, height: 30, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white, size: 20)),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}