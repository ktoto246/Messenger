import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'chat_detail_screen.dart';
import 'package:intl/intl.dart';

class SearchMessagesScreen extends StatefulWidget {
  final int currentUserId;
  const SearchMessagesScreen({super.key, required this.currentUserId});

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
    final results = await _chatService.searchMessages(query);
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
              final date = DateTime.parse(msg['sentAt']).toLocal();
              
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.message)),
                title: Text(msg['chatName'] ?? "Чат"),
                subtitle: Text(msg['contentText'] ?? ""),
                trailing: Text(DateFormat('HH:mm').format(date)),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatDetailScreen(
                    chatId: msg['chatID'], 
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
