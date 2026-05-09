import 'package:flutter/material.dart';
import 'main_screen.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart'; 
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import '../main.dart'; 
import '../utils/ui_utils.dart';
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

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      UIUtils.showSnackBar(context, 'Пожалуйста, заполните почту и пароль', isError: true);
      return;
    }

    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(email)) {
      UIUtils.showSnackBar(context, 'Введите корректный Email адрес', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final success = await _authService.login(email, password);
      
      if (success) {
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
          UIUtils.showSnackBar(context, 'Неверный логин или пароль 🚫', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('NETWORK_ERROR')) {
          UIUtils.showSnackBar(context, 'Нет связи с сервером. Проверьте интернет 🌐', isError: true);
        } else {
          UIUtils.showSnackBar(context, 'Произошла ошибка. Попробуйте позже.', isError: true);
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
                'Вход',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: textColor, fontFamily: 'SF Pro'),
              ),
              const SizedBox(height: 10),
              Text(
                'С возвращением!',
                style: TextStyle(fontSize: 16, color: hintColor),
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
                    CustomInputField(hintText: 'Почта', isPassword: false, controller: _emailController, iconData: Icons.email_outlined),
                    const SizedBox(height: 16), 
                    CustomInputField(hintText: 'Пароль', isPassword: true, controller: _passwordController, iconData: Icons.lock_outline),
                  ],
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    UIUtils.showCustomMessage(context, "Сброс пароля", "Функция восстановления пароля будет доступна в следующем обновлении.");
                  },
                  child: const Text('Забыли пароль?'),
                ),
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

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: Text('Нет аккаунта? Зарегистрироваться', style: TextStyle(color: textColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}