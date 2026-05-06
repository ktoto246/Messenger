import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'chats_screen.dart';
import 'contacts_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver { // <--- ДОБАВИЛИ НАБЛЮДАТЕЛЯ
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  int? _currentUserId;

  final List<Widget> _pages = [
    const ChatsScreen(),
    const ContactsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Регистрируем наблюдателя при запуске экрана
    WidgetsBinding.instance.addObserver(this);
    _initUserStatus();
  }

  // Получаем ID и сразу ставим статус "В сети"
  Future<void> _initUserStatus() async {
    _currentUserId = await _authService.getCurrentUserId();
    if (_currentUserId != null) {
      _authService.updateOnlineStatus(true);
    }
  }

  @override
  void dispose() {
    // Удаляем наблюдателя при закрытии
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // --- ЭТОТ МЕТОД ЛОВИТ СВОРАЧИВАНИЕ И РАЗВОРАЧИВАНИЕ ПРИЛОЖЕНИЯ ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_currentUserId == null) return;

    if (state == AppLifecycleState.resumed) {
      _authService.updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _authService.updateOnlineStatus(false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble, size: 28),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group, size: 30),
            label: 'People',
          ),
        ],
      ),
    );
  }
}