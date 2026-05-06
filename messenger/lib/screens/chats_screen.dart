import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import 'chat_detail_screen.dart';
import 'new_message_screen.dart';
import 'create_folder_screen.dart';
import 'settings_screen.dart'; 
import 'search_messages_screen.dart'; 
import 'profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; 
import '../config/app_config.dart';
import '../services/folder_service.dart';
import '../widgets/story_bar.dart';

class ChatsScreen extends StatefulWidget {
  final void Function(int chatId, String chatName, int? otherUserId)? onChatSelected;
  const ChatsScreen({super.key, this.onChatSelected});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final FolderService _folderService = FolderService();
  final TextEditingController _searchController = TextEditingController();

  int? currentUserId;
  Map<String, dynamic>? currentUserProfile;
  
  List<dynamic> _allChats = [];
  List<dynamic> _filteredChats = [];
  List<dynamic> _folders = [];
  int? _selectedFolderId;
  bool _isLoading = true;
  bool _isOffline = false; 
  bool _isUpdating = false;
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Все', 'Личные', 'Группы'];
  
  HubConnection? _hubConnection;
  Map<int, Timer> _typingChats = {}; 
  StreamSubscription? _networkSubscription; 
  


  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);

    _networkSubscription = Connectivity().onConnectivityChanged.listen((dynamic result) {
      bool hasConnection = false;
      if (result is List<ConnectivityResult>) {
        hasConnection = !result.contains(ConnectivityResult.none);
      } else if (result is ConnectivityResult) {
        hasConnection = result != ConnectivityResult.none;
      }

      if (hasConnection) {
        if (_isOffline) {
          if (mounted) setState(() => _isOffline = false); 
          _refreshChats(showIndicator: true); 
        }
      } else {
        if (mounted) setState(() => _isOffline = true);
        _hubConnection?.stop(); 
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _networkSubscription?.cancel(); 
    _hubConnection?.stop();
    for (var timer in _typingChats.values) { timer.cancel(); }
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredChats = _allChats.where((chat) {
        final chatId = chat['chatID'] ?? chat['chatId'] ?? chat['ChatID'];
        
        // 📁 ФИЛЬТРАЦИЯ ПО ПАПКАМ
        if (_selectedFolderId != null) {
          final currentFolder = _folders.firstWhere((f) => f['folderID'] == _selectedFolderId, orElse: () => null);
          if (currentFolder != null) {
            final List<dynamic> folderChatIds = currentFolder['chatIds'] ?? [];
            if (!folderChatIds.contains(chatId)) return false;
          }
        }

        final name = (chat['chatName'] ?? chat['ChatName'] ?? '').toString().toLowerCase();
        
        bool isGroup = chat['isGroup'] == true || chat['IsGroup'] == true || 
                       chat['chatType'] == 1 || chat['ChatType'] == 1 || 
                       (chat['otherUserId'] == null && chat['chatName'] != 'Saved Messages' && chat['chatName'] != 'Избранное');
        bool isSavedMessages = (chat['otherUserId'] == null && !isGroup);

        bool matchesSearch = name.contains(query);
        bool matchesFilter = true;
        
        if (_selectedFilterIndex == 1) matchesFilter = !isGroup && !isSavedMessages;
        if (_selectedFilterIndex == 2) matchesFilter = isGroup; 
        
        return matchesSearch && matchesFilter;
      }).toList();

      _filteredChats.sort((a, b) {
        bool isPinnedA = a['isPinned'] ?? a['IsPinned'] ?? false;
        bool isPinnedB = b['isPinned'] ?? b['IsPinned'] ?? false;
        if (isPinnedA && !isPinnedB) return -1;
        if (!isPinnedA && isPinnedB) return 1;
        return 0; 
      });
    });
  }

  Future<void> _loadData() async {
    final userId = await _authService.getCurrentUserId();

    if (userId != null) {
      currentUserId = userId; 

      final box = Hive.box('chats_box');
      final cachedProfile = box.get('profile_$userId');
      final cachedChats = box.get('chats_$userId');

      if (cachedProfile != null && cachedChats != null && mounted) {
        setState(() {
          currentUserProfile = jsonDecode(cachedProfile);
          _allChats = jsonDecode(cachedChats);
          _filteredChats = _allChats;
          _isLoading = false; 
        });
      }

      _refreshChats(showIndicator: true);
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshChats({bool showIndicator = false}) async {
    if (currentUserId == null) return;
    
    if (mounted && showIndicator) {
      setState(() { 
        _isUpdating = true; 
        _isOffline = false;
      });
    }

    try {
      final profile = await _chatService.getUserProfile(currentUserId!);
      final chats = await _chatService.fetchChats(currentUserId!);
      final folders = await _folderService.getFolders();
      
      if (mounted) {
        setState(() {
          currentUserProfile = profile;
          _allChats = chats;
          _folders = folders;
          _onSearchChanged(); 
          _isUpdating = false;
          _isLoading = false;
        });
      }
      
      if (_hubConnection == null || _hubConnection!.state == HubConnectionState.Disconnected) {
        _initSignalR();
      }
    } catch (e) {
      if (mounted) setState(() { _isUpdating = false; _isLoading = false; _isOffline = true; });
    }
  }

  Future<void> _initSignalR() async {
    final token = await AuthService.getToken();
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          AppConfig.hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token ?? '',
          ),
        )
        .build();
    
    _hubConnection?.onclose(({error}) {
      if (mounted) setState(() => _isOffline = true);
    });

    _hubConnection?.on("UserTyping", (args) {
      if (args != null && args.length >= 2) {
        int chatId = int.parse(args[0].toString());
        int typingUserId = args[1] as int;

        if (typingUserId != currentUserId && mounted) {
          setState(() {
            _typingChats[chatId]?.cancel(); 
            _typingChats[chatId] = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _typingChats.remove(chatId));
            });
          });
        }
      }
    });

    _hubConnection?.on("ReceiveMessage", (args) { _refreshChats(); });

    try {
      await _hubConnection?.start();
      if (mounted) setState(() => _isOffline = false); // Сокет подключился - точно онлайн!

      for (var chat in _allChats) {
        final chatId = chat['chatID'] ?? chat['chatId'] ?? chat['ChatID'];
        _hubConnection?.send("JoinChat", args: [chatId.toString()]);
      }
    } catch (e) {
      if (mounted) setState(() => _isOffline = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = Theme.of(context).scaffoldBackgroundColor;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color searchBgColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F2);
    Color dividerColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    Color chipBgColor = isDark ? const Color(0xFF1C1C1E) : Colors.grey[200]!;
    Color subTextColor = isDark ? Colors.grey[500]! : Colors.grey;

    final String? myAvatarUrl = currentUserProfile?['avatarUrl'];
    final String myDisplayName = currentUserProfile?['displayName'] ?? '?';
    final String myInitial = myDisplayName.isNotEmpty ? myDisplayName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: bgColor,
      drawer: Drawer(
        backgroundColor: bgColor,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1)),
              accountName: Text(myDisplayName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              accountEmail: const Text("VEINPulse Pro User", style: TextStyle(color: Colors.blue)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: isDark ? Colors.grey[800] : Colors.black,
                backgroundImage: myAvatarUrl != null ? CachedNetworkImageProvider(myAvatarUrl) : null,
                child: myAvatarUrl == null ? Text(myInitial, style: const TextStyle(color: Colors.white, fontSize: 24)) : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark, color: Colors.blue),
              title: Text("Избранное", style: TextStyle(color: textColor)),
              onTap: () async {
                Navigator.pop(context);
                int? savedChatId = await _chatService.getOrCreateSavedMessages(currentUserId!);
                if (savedChatId != null) Navigator.push(context, MaterialPageRoute(builder: (context) => ChatDetailScreen(chatId: savedChatId, chatName: "Избранное", currentUserId: currentUserId!, otherUserId: currentUserId)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign, color: Colors.orange),
              title: Text("Создать канал", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                // Навигация на создание канала (создадим позже или используем существующий экран с флагом)
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: Text("Настройки", style: TextStyle(color: textColor)),
              onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen(currentUserId: currentUserId ?? 0, userProfile: currentUserProfile ?? {}))); },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Builder(builder: (context) => IconButton(icon: Icon(Icons.menu, color: textColor), onPressed: () => Scaffold.of(context).openDrawer())),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen())),
                        child: CircleAvatar(
                          radius: 18, 
                          backgroundColor: isDark ? Colors.grey[800] : Colors.black,
                          backgroundImage: myAvatarUrl != null ? CachedNetworkImageProvider(myAvatarUrl) : null,
                          child: myAvatarUrl == null ? Text(myInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)) : null,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Chats', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'SF Pro Text', color: textColor)),
                      if (_isUpdating || _isOffline)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isUpdating && !_isOffline) 
                              const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)),
                            if (_isUpdating && !_isOffline) const SizedBox(width: 4),
                            Text(
                              _isOffline ? 'Нет сети' : 'Обновление...',
                              style: TextStyle(
                                fontSize: 13,
                                color: _isOffline ? Colors.red : Colors.grey, 
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.bookmark_border, color: Colors.blue, size: 28),
                        onPressed: () async {
                          if (currentUserId == null) return;
                          int? savedChatId = await _chatService.getOrCreateSavedMessages(currentUserId!);
                          if (savedChatId != null && mounted) {
                            await Navigator.push(context, MaterialPageRoute(builder: (context) => ChatDetailScreen(chatId: savedChatId, chatName: "Избранное", currentUserId: currentUserId!, otherUserId: currentUserId)));
                            _refreshChats();
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.search, color: textColor),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SearchMessagesScreen(currentUserId: currentUserId!))),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_square, color: textColor),
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => NewMessageScreen(currentUserId: currentUserId!)));
                          _refreshChats();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 🎞️ ПАНЕЛЬ СТОРИС (ПУЛЬС)
            const StoryBar(),

            // 🔍 СТРОКА ПОИСКА ЧАТОВ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                height: 40,
                decoration: BoxDecoration(color: searchBgColor, borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  controller: _searchController, 
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(color: textColor), 
                  decoration: const InputDecoration(hintText: "Search", hintStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.search, color: Colors.grey), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 0), isDense: true),
                ),
              ),
            ),

            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedFilterIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_filters[index], style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected, selectedColor: Colors.blue, backgroundColor: chipBgColor, showCheckmark: false,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                      onSelected: (selected) { setState(() { _selectedFilterIndex = index; _onSearchChanged(); }); },
                    ),
                  );
                },
              ),
            ),

            // 📁 ПАПКИ
            if (_folders.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: const Text("Все чаты"),
                    selected: _selectedFolderId == null,
                    onSelected: (_) => setState(() { _selectedFolderId = null; _onSearchChanged(); }),
                  ),
                  const SizedBox(width: 8),
                  ..._folders.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f['folderName']),
                      selected: _selectedFolderId == f['folderID'],
                      onSelected: (_) => setState(() { _selectedFolderId = f['folderID']; _onSearchChanged(); }),
                    ),
                  )).toList(),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () async {
                      final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => CreateFolderScreen(currentUserId: currentUserId!)));
                      if (res == true) _refreshChats();
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refreshChats(showIndicator: false),
                color: Colors.blue,
                child: _filteredChats.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 50, color: isDark ? Colors.white54 : Colors.grey),
                                const SizedBox(height: 10),
                                Text(_allChats.isEmpty ? 'No chats yet' : 'Not found', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(), 
                        itemCount: _filteredChats.length,
                        separatorBuilder: (_, __) => Divider(indent: 76, height: 1, color: dividerColor),
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          final chatName = chat['chatName'] ?? chat['ChatName'] ?? 'Unknown';
                          final lastMessage = chat['lastMessage'] ?? chat['LastMessage'] ?? '';
                          final timeRaw = chat['lastMessageTime'] ?? chat['LastMessageTime'];
                          final chatId = chat['chatID'] ?? chat['chatId'] ?? chat['ChatID'];
                          final unreadCount = chat['unreadCount'] ?? chat['UnreadCount'] ?? 0;
                          final chatAvatar = chat['avatarUrl'] ?? chat['AvatarUrl'];
                          final otherUserId = chat['otherUserId'] ?? chat['OtherUserId'];
                          final bool isOnline = chat['isOnline'] ?? chat['IsOnline'] ?? false;
                          
                          final bool isGroup = chat['isGroup'] == true || chat['IsGroup'] == true || chat['chatType'] == 1 || chat['ChatType'] == 1 || (otherUserId == null && chatName != 'Saved Messages' && chatName != 'Избранное');
                          final bool isSavedMessages = (otherUserId == null && !isGroup);
                          final String finalChatName = isSavedMessages ? "Избранное" : chatName;
                          final bool isPinned = chat['isPinned'] ?? chat['IsPinned'] ?? false;
                          String timeStr = formatChatDateTime(timeRaw?.toString());

                          return Dismissible(
                            key: Key('chat_$chatId'),
                            dismissThresholds: const { DismissDirection.startToEnd: 0.25, DismissDirection.endToStart: 0.25 },
                            background: Container(
                              alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 24), color: isPinned ? Colors.grey : Colors.green, 
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: Colors.white, size: 28), Text(isPinned ? "Открепить" : "Закрепить", style: const TextStyle(color: Colors.white, fontSize: 12))]),
                            ),
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), color: Colors.red,
                              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.delete_outline, color: Colors.white, size: 28), Text("Удалить", style: TextStyle(color: Colors.white, fontSize: 12))]),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                HapticFeedback.lightImpact(); 
                                await _chatService.togglePinChat(chatId, currentUserId!); _refreshChats(); 
                                return false; 
                              } else {
                                HapticFeedback.mediumImpact();
                                bool? confirm = await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text("Удалить чат?"), content: Text("Вы уверены, что хотите удалить переписку с $chatName? Это действие нельзя отменить."),
                                      actions: [
                                        TextButton(child: const Text("Отмена", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.of(context).pop(false)),
                                        TextButton(child: const Text("Удалить", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), onPressed: () => Navigator.of(context).pop(true)),
                                      ],
                                    );
                                  },
                                );
                                if (confirm == true) {
                                  await _chatService.deleteChat(chatId, currentUserId!);
                                  setState(() { _allChats.removeWhere((c) => (c['chatID'] ?? c['chatId'] ?? c['ChatID']) == chatId); _onSearchChanged(); });
                                  return true; 
                                }
                                return false;
                              }
                            },
                            child: Container(
                              color: isPinned ? (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF4F9FF)) : Colors.transparent, 
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                onTap: () async {
                                  if (widget.onChatSelected != null) {
                                    widget.onChatSelected!(chatId, finalChatName, otherUserId);
                                  } else {
                                    await Navigator.push(context, MaterialPageRoute(builder: (context) => ChatDetailScreen(chatId: chatId, chatName: finalChatName, currentUserId: currentUserId!, otherUserId: otherUserId)));
                                    _refreshChats(); 
                                  }
                                },
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 28, 
                                      backgroundColor: isSavedMessages ? Colors.blue : (isGroup ? Colors.orangeAccent : (isDark ? Colors.grey[800] : Colors.blueAccent)),
                                      backgroundImage: chatAvatar != null ? CachedNetworkImageProvider(chatAvatar) : null,
                                      child: isSavedMessages 
                                          ? const Icon(Icons.bookmark, color: Colors.white, size: 28) 
                                          : (isGroup && chatAvatar == null 
                                              ? const Icon(Icons.people, color: Colors.white, size: 28) 
                                              : (chatAvatar == null ? Text(finalChatName.isNotEmpty ? finalChatName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 20)) : null)),
                                    ),
                                    if (isOnline && !isGroup && !isSavedMessages)
                                      Positioned(right: 0, bottom: 0, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: const Color(0xFF4CE417), shape: BoxShape.circle, border: Border.all(color: bgColor, width: 2.5)))),
                                  ],
                                ),
                                title: Text(chatName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: _typingChats.containsKey(chatId)
                                    ? const Text("печатает...", style: TextStyle(color: Colors.blue, fontSize: 15, fontStyle: FontStyle.italic))
                                    : Text(lastMessage, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: unreadCount > 0 ? textColor : subTextColor, fontSize: 15, height: 1.2)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isPinned) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.push_pin, size: 14, color: subTextColor)),
                                        Text(timeStr, style: TextStyle(color: unreadCount > 0 ? Colors.blue : subTextColor, fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(height: 5), 
                                    if (unreadCount > 0)
                                       Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatChatDateTime(String? dateTimeStr) {
  if (dateTimeStr == null || dateTimeStr == 'null' || dateTimeStr.isEmpty) return '';
  try {
    if (dateTimeStr.startsWith('0001')) return ''; 
    if (!dateTimeStr.endsWith('Z')) dateTimeStr += 'Z';
    final dt = DateTime.parse(dateTimeStr).toLocal(); 
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dt.year, dt.month, dt.day);
    final difference = today.difference(messageDay).inDays;

    if (difference == 0) return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    else if (difference == 1) return "Вчера";
    else return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year.toString().substring(2)}";
  } catch (e) { return ''; }
}