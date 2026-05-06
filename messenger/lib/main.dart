import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 Добавили для чтения памяти
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:ui';

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
  
  // 1. Инициализируем локальную базу данных (Hive)
  await Hive.initFlutter();
  await Hive.openBox('chats_box');
  await Hive.openBox('messages_box');
  
  // 2. Достаем тему (чтобы не слепило белым при входе)
  var settingsBox = await Hive.openBox('settings_box');
  themeNotifier.value = settingsBox.get('isDarkMode', defaultValue: false);

  // 3. 🪄 МАГИЯ АВТОВХОДА: Проверяем, есть ли сохраненный ID пользователя
  final prefs = await SharedPreferences.getInstance();
  final int? savedUserId = prefs.getInt('userId');
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
          
          // --- ТЕМНАЯ ТЕМА ---
          darkTheme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFF121212), 
            primarySwatch: Colors.blue,
            fontFamily: 'SF Pro',
            brightness: Brightness.dark,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
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