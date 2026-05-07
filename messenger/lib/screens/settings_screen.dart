import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'privacy_screen.dart';
import 'theme_settings_screen.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../main.dart';
import 'active_sessions_screen.dart';
import 'business_profile_screen.dart';
import 'missed_calls_screen.dart';
import 'nearby_people_screen.dart';

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
  bool _compactMode = false;
  bool _nightScheduleEnabled = false;

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.userProfile['isDarkMode'] ?? themeNotifier.value;
    // Загружаем доп. настройки
    NotificationService.isCompactMode().then((v) { if (mounted) setState(() => _compactMode = v); });
    NotificationService.getNightModeSchedule().then((s) { if (mounted) setState(() => _nightScheduleEnabled = s['enabled'] as bool); });
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
          
          // Блок 1: Основные
          _buildSettingsBlock([
            _buildSettingsItem(icon: Icons.notifications, color: Colors.redAccent, title: "Уведомления и звуки", onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Настройки уведомлений скоро будут доступны! 🔔")));
            }),
            _buildSettingsItem(
              icon: Icons.lock, color: Colors.grey, title: "Конфиденциальность", 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PrivacyScreen(currentUserId: widget.currentUserId, userProfile: widget.userProfile))),
            ),
            _buildSettingsItem(icon: Icons.data_usage, color: Colors.green, title: "Данные и память", onTap: _showClearCacheDialog),
            _buildSettingsItem(
              icon: Icons.devices, color: Colors.indigo, title: "Активные сессии",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActiveSessionsScreen())),
            ),
          ], blockColor),

          const SizedBox(height: 25),

          // Блок 2: Оформление
          const Padding(padding: EdgeInsets.only(left: 16, bottom: 8), child: Text("ОФОРМЛЕНИЕ", style: TextStyle(color: Colors.grey, fontSize: 13))),
          _buildSettingsBlock([
            _buildSettingsItem(
              icon: Icons.color_lens, color: Colors.blue, title: "Тема и цвета", 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ThemeSettingsScreen(currentUserId: widget.currentUserId))),
            ), 
            _buildSettingsItem(
              icon: Icons.nightlight_round, 
              color: Colors.black, 
              title: "Ночной режим", 
              trailing: Switch.adaptive(
                value: isDarkMode, 
                onChanged: _toggleTheme,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.blue.withValues(alpha: 0.5),
              )
            ),
            _buildSettingsItem(
              icon: Icons.schedule, color: Colors.deepPurple, title: "Ночной режим по расписанию",
              trailing: Switch.adaptive(
                value: _nightScheduleEnabled,
                onChanged: (v) async {
                  setState(() => _nightScheduleEnabled = v);
                  final schedule = await NotificationService.getNightModeSchedule();
                  await NotificationService.setNightModeSchedule(
                    enabled: v,
                    fromHour: schedule['fromHour'] as int,
                    fromMinute: schedule['fromMinute'] as int,
                    toHour: schedule['toHour'] as int,
                    toMinute: schedule['toMinute'] as int,
                  );
                  if (v) {
                    final shouldBeDark = await NotificationService.shouldBeDarkNow();
                    themeNotifier.value = shouldBeDark;
                  }
                },
                activeTrackColor: Colors.deepPurple.withValues(alpha: 0.5),
                activeThumbColor: Colors.deepPurple,
              ),
            ),
            _buildSettingsItem(
              icon: Icons.density_small, color: Colors.teal, title: "Компактный режим",
              trailing: Switch.adaptive(
                value: _compactMode,
                onChanged: (v) async {
                  setState(() => _compactMode = v);
                  await NotificationService.setCompactMode(v);
                },
                activeTrackColor: Colors.teal.withValues(alpha: 0.5),
                activeThumbColor: Colors.teal,
              ),
            ),
          ], blockColor),

          const SizedBox(height: 25),

          // Блок 3: Связь
          const Padding(padding: EdgeInsets.only(left: 16, bottom: 8), child: Text("СВЯЗЬ И ЗВОНКИ", style: TextStyle(color: Colors.grey, fontSize: 13))),
          _buildSettingsBlock([
            _buildSettingsItem(
              icon: Icons.call, color: Colors.green, title: "История звонков",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MissedCallsScreen(currentUserId: widget.currentUserId))),
            ),
            _buildSettingsItem(
              icon: Icons.location_on, color: Colors.red, title: "Люди рядом",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NearbyPeopleScreen(currentUserId: widget.currentUserId))),
            ),
          ], blockColor),

          const SizedBox(height: 25),

          // Блок 4: Бизнес
          const Padding(padding: EdgeInsets.only(left: 16, bottom: 8), child: Text("БИЗНЕС", style: TextStyle(color: Colors.grey, fontSize: 13))),
          _buildSettingsBlock([
            _buildSettingsItem(
              icon: Icons.business_center, color: Colors.orange, title: "Бизнес-профиль",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessProfileScreen(currentUserId: widget.currentUserId))),
            ),
          ], blockColor),

          const SizedBox(height: 40),
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