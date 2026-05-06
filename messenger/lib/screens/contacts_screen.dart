import 'package:flutter/material.dart';
import 'dart:async';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import 'foreign_profile_screen.dart'; 

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _users = [];
  bool _isLoading = true;
  int? currentUserId;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userId = await _authService.getCurrentUserId();
    if (mounted) {
      setState(() => currentUserId = userId);
    }
    _searchUsers('');
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final users = await _chatService.searchUsers(query);
      if (mounted) {
        setState(() {
          if (currentUserId != null) {
            _users = users.where((u) => u['userID'] != currentUserId).toList();
          } else {
            _users = users;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = Theme.of(context).scaffoldBackgroundColor;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color searchBgColor = isDark ? Colors.grey[800]! : const Color(0xFFF2F2F2);
    Color dividerColor = isDark ? Colors.grey[800]! : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text('People', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: -0.4, color: textColor)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(color: searchBgColor, borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: textColor), 
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    hintText: 'Search', hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 70, color: Colors.grey.withOpacity(0.4)),
                              const SizedBox(height: 16),
                              Text("Никого не найдено", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                              const SizedBox(height: 8),
                              Text("Попробуйте изменить запрос", style: TextStyle(fontSize: 14, color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 10),
                          itemCount: _users.length,
                          separatorBuilder: (ctx, i) => Divider(height: 1, indent: 76, color: dividerColor),
                          itemBuilder: (context, index) => _buildUserTile(_users[index], isDark, textColor),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(dynamic user, bool isDark, Color textColor) {
    final displayName = user['displayName'] ?? 'Unknown';
    final avatarUrl = user['avatarUrl'];
    final userId = user['userID'] ?? user['userId'];
    
    final bool isOnline = user['isOnline'] ?? false;
    final String? lastActiveStr = user['lastActive']; 
    String statusText = '';
    Color statusColor = Colors.transparent;
    
    if (!isOnline && lastActiveStr != null) {
      try {
        final lastActive = DateTime.parse(lastActiveStr).toLocal();
        final diff = DateTime.now().difference(lastActive);
        if (diff.inMinutes < 60 && diff.inMinutes > 0) {
          statusText = '${diff.inMinutes} m'; statusColor = const Color(0xFFC7F0BB); 
        } else if (diff.inMinutes == 0) {
           statusText = 'now'; statusColor = const Color(0xFFC7F0BB);
        }
      } catch (e) {}
    }

    return InkWell(
      // 🛡️ ТЕПЕРЬ КЛИК ВЕДЕТ ТОЛЬКО В ПРОФИЛЬ (ГДЕ ЕСТЬ ЗАЩИТА) 🛡️
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
            builder: (context) => ForeignProfileScreen(userId: userId, initialName: displayName, initialAvatar: avatarUrl),
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: TextStyle(color: textColor, fontSize: 20)) : null,
                ),
                if (isOnline) Positioned(right: 0, bottom: 0, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: const Color(0xFF4CE417), shape: BoxShape.circle, border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2.5))))
                else if (statusText.isNotEmpty) Positioned(right: -4, bottom: -2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2)), child: Text(statusText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)))),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(displayName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: textColor))),
          ],
        ),
      ),
    );
  }
}