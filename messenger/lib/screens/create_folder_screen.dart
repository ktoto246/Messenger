import 'package:flutter/material.dart';
import '../services/folder_service.dart';
import '../services/chat_service.dart';

class CreateFolderScreen extends StatefulWidget {
  final int currentUserId;
  const CreateFolderScreen({super.key, required this.currentUserId});

  @override
  State<CreateFolderScreen> createState() => _CreateFolderScreenState();
}

class _CreateFolderScreenState extends State<CreateFolderScreen> {
  final FolderService _folderService = FolderService();
  final ChatService _chatService = ChatService();
  final TextEditingController _nameController = TextEditingController();
  
  List<dynamic> _allChats = [];
  List<int> _selectedChatIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  void _loadChats() async {
    final chats = await _chatService.fetchChats(widget.currentUserId);
    setState(() {
      _allChats = chats;
      _isLoading = false;
    });
  }

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    
    await _folderService.createFolder(name, _selectedChatIds);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Новая папка"), actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)]),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Название папки")),
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(8.0), child: Text("Выберите чаты для папки:")),
          Expanded(
            child: ListView.builder(
              itemCount: _allChats.length,
              itemBuilder: (context, index) {
                final chat = _allChats[index];
                final chatId = chat['chatID'] ?? chat['chatId'] ?? chat['ChatID'];
                final isSelected = _selectedChatIds.contains(chatId);
                
                return CheckboxListTile(
                  title: Text(chat['chatName'] ?? "Чат"),
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) _selectedChatIds.add(chatId);
                      else _selectedChatIds.remove(chatId);
                    });
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
