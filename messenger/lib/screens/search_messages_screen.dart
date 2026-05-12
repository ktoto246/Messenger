import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'chat_detail_screen.dart';
import 'package:intl/intl.dart';

class SearchMessagesScreen extends StatefulWidget {
  final int currentUserId;
<<<<<<< HEAD
  const SearchMessagesScreen({super.key, required this.currentUserId});
=======
  final int? chatId;
  const SearchMessagesScreen({super.key, required this.currentUserId, this.chatId});
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75

  @override
  State<SearchMessagesScreen> createState() => _SearchMessagesScreenState();
}

class _SearchMessagesScreenState extends State<SearchMessagesScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;

  void _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
<<<<<<< HEAD
    final results = await _chatService.searchMessages(query);
=======
    final results = await _chatService.searchMessages(query, chatId: widget.chatId);
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: const InputDecoration(
            hintText: "Поиск по сообщениям...",
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _onSearch(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _onSearch),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final msg = _results[index];
              final sentAt = msg['sentAt'];
              DateTime? date;
              try {
                if (sentAt != null && (sentAt as String).isNotEmpty) {
                  date = DateTime.parse(sentAt).toLocal();
                }
              } catch (_) {}
              
              final chatId = msg['chatID'] ?? msg['chatId'];
              
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.message)),
                title: Text(msg['chatName'] ?? "Чат"),
                subtitle: Text(msg['contentText'] ?? ""),
                trailing: date != null ? Text(DateFormat('HH:mm').format(date)) : null,
                onTap: chatId == null ? null : () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatDetailScreen(
                    chatId: chatId, 
                    chatName: msg['chatName'] ?? "Чат", 
                    currentUserId: widget.currentUserId
                  )));
                },
              );
            },
          ),
    );
  }
}
