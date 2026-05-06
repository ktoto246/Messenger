import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'chats_screen.dart';
import 'contacts_screen.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import 'call_screen.dart';
import 'chat_detail_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver { // <--- ДОБАВИЛИ НАБЛЮДАТЕЛЯ
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  final CallService _callService = CallService();
  int? _currentUserId;

  int? _selectedChatId;
  String? _selectedChatName;
  int? _selectedOtherUserId;

  void _handleChatSelected(int chatId, String chatName, int? otherUserId) {
    setState(() {
      _selectedChatId = chatId;
      _selectedChatName = chatName;
      _selectedOtherUserId = otherUserId;
    });
  }

  @override
  void initState() {
    super.initState();
    // Регистрируем наблюдателя при запуске экрана
    WidgetsBinding.instance.addObserver(this);
    _initUserStatus();
    _initCalls();
    
    // 💾 СИНХРОНИЗАЦИЯ ОФЛАЙН СООБЩЕНИЙ
    ChatService().syncPendingMessages();
  }

  Future<void> _initCalls() async {
    await _callService.init();
    _callService.onIncomingCall = (id, offer) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => CallScreen(
        targetUserId: id, 
        targetUserName: "Incoming Call", // В идеале найти имя по ID
        isIncoming: true,
        remoteOffer: offer,
      )));
    };
  }

  // Получаем ID и сразу ставим статус "В сети"
  Future<void> _initUserStatus() async {
    _currentUserId = await _authService.getCurrentUserId();
    if (_currentUserId != null) {
      _authService.updateOnlineStatus(true);
      
      // 🔔 ПОЛУЧАЕМ И ОБНОВЛЯЕМ ТОКЕН ДЛЯ ПУШЕЙ
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await ChatService().updateProfile(_currentUserId!, {'fcmToken': fcmToken});
          print("🔔 FCM Токен обновлен: $fcmToken");
        }
      } catch (e) { print("Ошибка получения FCM токена: $e"); }
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

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: Theme.of(context).cardColor,
          selectedIconTheme: const IconThemeData(color: Colors.blue),
          unselectedIconTheme: const IconThemeData(color: Colors.grey),
          useIndicator: false,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: Text('Chats')),
            NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Contacts')),
          ],
        ),
        const VerticalDivider(thickness: 1, width: 1, color: Colors.black26),
        SizedBox(
          width: 380,
          child: _selectedIndex == 0 ? ChatsScreen(onChatSelected: _handleChatSelected) : const ContactsScreen(),
        ),
        const VerticalDivider(thickness: 1, width: 1, color: Colors.black26),
        Expanded(
          child: _selectedIndex == 0 
              ? (_selectedChatId != null 
                  ? ChatDetailScreen(chatId: _selectedChatId!, chatName: _selectedChatName ?? "Chat", currentUserId: _currentUserId ?? 0, otherUserId: _selectedOtherUserId)
                  : Center(child: Text("Выберите чат", style: TextStyle(color: Colors.grey[600], fontSize: 16))))
              : const Center(child: Text("Контакты", style: TextStyle(color: Colors.grey, fontSize: 16))),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _buildDesktopLayout(context);
          }
          
          Widget mobileBody = _selectedIndex == 0 ? const ChatsScreen() : const ContactsScreen();
          
          return Scaffold(
            body: mobileBody,
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              currentIndex: _selectedIndex,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
              onTap: _onItemTapped,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.chat_bubble, size: 28), label: 'Chats'),
                BottomNavigationBarItem(icon: Icon(Icons.group, size: 30), label: 'People'),
              ],
            ),
          );
        },
      ),
    );
  }
}