import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart'; 
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import '../main.dart'; 
import 'package:hive/hive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _chatService = ChatService(); 
  bool _isLoading = false;

  // 🪄 ПРЕМИУМ УВЕДОМЛЕНИЯ АДАПТИВНЫЕ ПОД ТЕМУ (КАК В РЕГИСТРАЦИИ) 🪄
  void _showCustomMessage(String message, {int type = 0}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Мягкие цвета для ночи, классические для дня
    Color iconColor = type == 1 ? (isDark ? const Color(0xFF32D74B) : Colors.green) 
                    : (type == 2 ? (isDark ? const Color(0xFFFF453A) : Colors.red) 
                    : (isDark ? const Color(0xFFFF9F0A) : Colors.orange));
    
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
        elevation: isDark ? 0 : 8,
      ),
    );
  }

 void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showCustomMessage('Пожалуйста, заполните почту и пароль', type: 0);
      return;
    }

    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(email)) {
      _showCustomMessage('Введите корректный Email адрес', type: 2);
      return;
    }

    if (password.length < 6) {
      _showCustomMessage('Пароль должен содержать минимум 6 символов', type: 2);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final success = await _authService.login(email, password);
      
      if (success) {
        // Загружаем тему
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

        if (mounted) {
          Navigator.of(context).pushReplacement(
             MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        if (mounted) {
          _showCustomMessage('Неверный логин или пароль 🚫', type: 2);
        }
      }
    } catch (e) {
      if (mounted) {
        // 👇 ТЕПЕРЬ ОН ТОЧНО ЗНАЕТ, ЧТО НЕТ СЕТИ 👇
        if (e.toString().contains('NETWORK_ERROR')) {
          _showCustomMessage('Нет связи с сервером. Проверьте интернет 🌐', type: 2);
        } else {
          _showCustomMessage('Произошла ошибка. Попробуйте позже.', type: 2);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              Text(
                'Hello.',
                style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: textColor, fontFamily: 'SF Pro'),
              ),
              const SizedBox(height: 40),

              Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: inputBgColor,
                    hintStyle: TextStyle(color: hintColor),
                    iconColor: hintColor,
                    prefixIconColor: hintColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  ),
                  textTheme: TextTheme(bodyLarge: TextStyle(color: inputTextColor)),
                ),
                child: Column(
                  children: [
                    CustomInputField(hintText: 'E-Mail', isPassword: false, controller: _emailController, iconData: Icons.email_outlined),
                    const SizedBox(height: 16), 
                    CustomInputField(hintText: 'Password', isPassword: true, controller: _passwordController, iconData: Icons.lock_outline),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              CustomButton(
                text: 'Зарегистрироваться',
                color: const Color(0xFF0088FF),
                width: double.infinity,
                height: 55,
                onTap: () => Navigator.pushNamed(context, '/register'),
              ),

              const SizedBox(height: 20),

              _isLoading
                  ? const CircularProgressIndicator()
                  : CustomButton(
                      text: 'Войти',
                      color: const Color(0xFF0088FF),
                      width: double.infinity,
                      height: 55,
                      onTap: _login,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}