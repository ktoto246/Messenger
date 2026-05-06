import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/main_screen.dart'; // Добавили для перехода в чат
import '../services/auth_service.dart';
import '../services/chat_service.dart'; // Добавили для темы
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import '../main.dart';
import 'package:hive/hive.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  final _authService = AuthService();
  final _chatService = ChatService();
  bool _isLoading = false;

  // 🪄 ПРЕМИУМ УВЕДОМЛЕНИЯ АДАПТИВНЫЕ ПОД ТЕМУ 🪄
  void _showCustomMessage(String message, {int type = 0}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Цвета в стиле Apple (мягкие неоновые для ночи, классические для дня)
    Color iconColor = type == 1 ? (isDark ? const Color(0xFF32D74B) : Colors.green) 
                    : (type == 2 ? (isDark ? const Color(0xFFFF453A) : Colors.red) 
                    : (isDark ? const Color(0xFFFF9F0A) : Colors.orange));
    
    // Фон плашки: темно-серый ночью, белый днем
    Color bgColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(type == 1 ? Icons.check_circle : (type == 2 ? Icons.error : Icons.warning_rounded), color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
        elevation: isDark ? 0 : 8, // Убираем тень ночью для стиля
      ),
    );
  }

  void _register() async {
    if (_usernameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty || _displayNameController.text.isEmpty) {
      _showCustomMessage('Заполните все поля', type: 0);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final success = await _authService.register(
        _emailController.text,
        _passwordController.text,
        _displayNameController.text,
        _usernameController.text, 
      ).timeout(const Duration(seconds: 5));
      
      setState(() => _isLoading = false);

      if (success && mounted) {
        _showCustomMessage('Успешно! Заходим...', type: 1);
        
        // Автоматически логинимся после регистрации (чтобы получить ID и зайти)
        await _authService.login(_emailController.text, _passwordController.text);
        
        // Синхронизируем тему
        final userId = await _authService.getCurrentUserId();
        if (userId != null) {
          final profile = await _chatService.getUserProfile(userId);
          if (profile != null) {
            bool userTheme = profile['isDarkMode'] ?? profile['IsDarkMode'] ?? false;
            themeNotifier.value = userTheme; 
            var box = Hive.isBoxOpen('settings_box') ? Hive.box('settings_box') : await Hive.openBox('settings_box');
            box.put('isDarkMode', userTheme);
          }
        }

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            // 👇 ПУСКАЕМ СРАЗУ В ЧАТ 👇
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainScreen()),
              (route) => false // Очищаем историю, чтобы по кнопке "Назад" не выкинуло на регистрацию
            );
          }
        });

      } else if (mounted) {
        _showCustomMessage('Логин или Email уже заняты.', type: 2);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showCustomMessage('Ошибка соединения 🌐', type: 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color inputBgColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F2);
    Color inputTextColor = isDark ? Colors.white : Colors.black;
    Color hintColor = isDark ? Colors.grey[500]! : Colors.grey;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center( 
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Hello.', style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: textColor, fontFamily: 'SF Pro')),
              const SizedBox(height: 30),

              Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true, fillColor: inputBgColor, hintStyle: TextStyle(color: hintColor),
                    iconColor: hintColor, prefixIconColor: hintColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                  textTheme: TextTheme(bodyLarge: TextStyle(color: inputTextColor)),
                ),
                child: Column(
                  children: [
                    CustomInputField(hintText: 'Логин', isPassword: false, controller: _usernameController, iconData: Icons.alternate_email),
                    const SizedBox(height: 16),
                    CustomInputField(hintText: 'E-Mail', isPassword: false, controller: _emailController, iconData: Icons.email_outlined),
                    const SizedBox(height: 16),
                    CustomInputField(hintText: 'Пароль', isPassword: true, controller: _passwordController, iconData: Icons.lock_outline),
                    const SizedBox(height: 16),
                    CustomInputField(hintText: 'Отображаемое имя', isPassword: false, controller: _displayNameController, iconData: Icons.person_outline),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              _isLoading
                  ? const CircularProgressIndicator()
                  : CustomButton(text: 'Зарегистрироваться', color: const Color(0xFF0088FF), width: double.infinity, height: 55, onTap: _register),
              
              const SizedBox(height: 20),

              CustomButton(text: 'Уже есть аккаунт? Войдите.', color: const Color(0xFF0088FF), width: double.infinity, height: 55, onTap: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}