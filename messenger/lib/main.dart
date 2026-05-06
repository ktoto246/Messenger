import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:ui';
import 'dart:async';
import 'services/notification_service.dart';

// Твои экраны
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/main_screen.dart'; // 👈 Добавили для перехода сразу в приложение

// Рубильник темы
final ValueNotifier<bool> themeNotifier = ValueNotifier(false);

void main() async {
  // Обязательная строчка для работы с памятью до запуска UI
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(); // 🔔 Инициализация Firebase
  } catch (e) {
    debugPrint("Firebase не инициализирован. Проверьте google-services.json");
  }
  
  // 1. Инициализируем локальную базу данных (Hive)
  await Hive.initFlutter();
  await Hive.openBox('chats_box');
  await Hive.openBox('messages_box');
  
  // 2. Достаем тему (чтобы не слепило белым при входе)
  var settingsBox = await Hive.openBox('settings_box');
  final bool savedDark = settingsBox.get('isDarkMode', defaultValue: false) as bool;
  // Проверяем ночной режим по расписанию
  final bool nightScheduleDark = await NotificationService.shouldBeDarkNow();
  themeNotifier.value = savedDark || nightScheduleDark;
  // Проверяем расписание каждую минуту
  Timer.periodic(const Duration(minutes: 1), (_) async {
    final shouldBeDark = await NotificationService.shouldBeDarkNow();
    final currentlySaved = (await Hive.openBox('settings_box')).get('isDarkMode', defaultValue: false) as bool;
    themeNotifier.value = currentlySaved || shouldBeDark;
  });

  // 3. 🪄 МАГИЯ АВТОВХОДА: Проверяем, есть ли сохраненный ID пользователя (Через SecureStorage)
  const storage = FlutterSecureStorage();
  final String? savedUserId = await storage.read(key: 'userId');
  final bool isLoggedIn = savedUserId != null; // Если ID есть, значит авторизован!

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("🔴 Ошибка Flutter: ${details.exception}");
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("🔴 Фоновая ошибка поймана: $error");
    return true;
  };
  
  // Передаем статус авторизации в само приложение
  runApp(MessengerApp(isLoggedIn: isLoggedIn));
}

class MessengerApp extends StatelessWidget {
  final bool isLoggedIn; // 👈 Принимаем статус

  const MessengerApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Messenger App',
          
          // --- СВЕТЛАЯ ТЕМА ---
          theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFFFFFFFF), 
            primarySwatch: Colors.blue,
            fontFamily: 'SF Pro',
            brightness: Brightness.light,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF2F2F6),
              foregroundColor: Colors.black,
              elevation: 0,
            ),
          ),
          
          // --- ТЕМНАЯ ТЕМА (AMOLED BLACK) ---
          darkTheme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFF000000), 
            primarySwatch: Colors.blue,
            fontFamily: 'SF Pro',
            brightness: Brightness.dark,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF000000),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFF000000),
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
            ),
            cardColor: const Color(0xFF1C1C1E), // Цвет для плашек/настроек
          ),
          
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          
          // 🪄 ГЛАВНАЯ ЛОГИКА АВТОВХОДА 🪄
          // Если авторизован -> MainScreen. Если нет -> LoginScreen
          home: isLoggedIn ? const MainScreen() : const LoginScreen(),
          
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/chats': (context) => const ChatsScreen(),
          },
        );
      }
    );
  }
}