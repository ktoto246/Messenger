import 'package:flutter/material.dart';
import 'main_screen.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart'; 
import '../widgets/custom_button.dart';
import '../widgets/custom_input.dart';
import '../main.dart';
import '../utils/ui_utils.dart';
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
  final _confirmPasswordController = TextEditingController(); // 👈 Новый контроллер
  final _displayNameController = TextEditingController();
  
  final _authService = AuthService();
  final _chatService = ChatService();
  bool _isLoading = false;

  void _register() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text; // 👈 Берем текст подтверждения
    final displayName = _displayNameController.text.trim();

    // 👈 Добавили проверку confirmPassword на пустоту
    if (username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty || displayName.isEmpty) {
      UIUtils.showSnackBar(context, 'Пожалуйста, заполните все поля', isError: true);
      return;
    }

    if (username.length < 3) {
      UIUtils.showSnackBar(context, 'Логин слишком короткий (минимум 3 символа)', isError: true);
      return;
    }

    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(email)) {
      UIUtils.showSnackBar(context, 'Введите корректный Email адрес', isError: true);
      return;
    }

    if (password.length < 8) {
      UIUtils.showSnackBar(context, 'Пароль должен содержать минимум 8 символов для безопасности', isError: true);
      return;
    }

    // 👈 Сама проверка на совпадение
    if (password != confirmPassword) {
      UIUtils.showSnackBar(context, 'Пароли не совпадают', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final success = await _authService.register(
        email,
        password,
        displayName,
        username, 
      );
      
      if (success && mounted) {
        UIUtils.showSnackBar(context, 'Успешная регистрация! Входим...', isError: false);
        
        await _authService.login(email, password);
        
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
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false
          );
        }

      } else if (mounted) {
        UIUtils.showSnackBar(context, 'Этот логин или Email уже заняты.', isError: true);
      }
    } catch (e) {
      if (mounted) UIUtils.showSnackBar(context, 'Ошибка соединения 🌐', isError: true);
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
              Text('Регистрация', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: textColor, fontFamily: 'SF Pro')),
              const SizedBox(height: 10),
              Text('Создайте новый аккаунт VEIN', style: TextStyle(fontSize: 16, color: hintColor)),
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
                    CustomInputField(hintText: 'Почта (Email)', isPassword: false, controller: _emailController, iconData: Icons.email_outlined),
                    const SizedBox(height: 16),
                    CustomInputField(hintText: 'Отображаемое имя', isPassword: false, controller: _displayNameController, iconData: Icons.person_outline),
                    const SizedBox(height: 16),
                    CustomInputField(hintText: 'Пароль', isPassword: true, controller: _passwordController, iconData: Icons.lock_outline),
                    const SizedBox(height: 16),
                    // 👈 Новое поле в UI
                    CustomInputField(hintText: 'Подтвердите пароль', isPassword: true, controller: _confirmPasswordController, iconData: Icons.lock_outline),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              _isLoading
                  ? const CircularProgressIndicator()
                  : CustomButton(text: 'Создать аккаунт', color: const Color(0xFF0088FF), width: double.infinity, height: 55, onTap: _register),
              
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Уже есть аккаунт? Войти', style: TextStyle(color: textColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}