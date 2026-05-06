import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'foreign_profile_screen.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import '../widgets/audio_bubble.dart';
import '../widgets/video_circle.dart';
import 'fullscreen_image_screen.dart';
import '../widgets/inline_video_player.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'group_info_screen.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import 'call_screen.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'search_messages_screen.dart';
import 'forward_message_screen.dart';
import 'create_poll_screen.dart';
import 'chat_wallpaper_screen.dart';
import 'export_chat_screen.dart';
import '../widgets/spoiler_text.dart';
import '../widgets/poll_bubble.dart';
import '../services/translation_service.dart';
import '../services/notification_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final int chatId;
  final String chatName;
  final int currentUserId;
  final int? otherUserId;

  const ChatDetailScreen({super.key, required this.chatId, required this.chatName, required this.currentUserId, this.otherUserId});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true; 
  HubConnection? _hubConnection;
  bool _isTyping = false;
  Timer? _typingTimer; 
  Timer? _sendTypingTimer; 
  dynamic _replyingToMessage; 
  dynamic _editingMessage; 

  bool _showScrollToBottom = false;
  DateTime? _scheduledAt;
  bool _isViewOnceEnabled = false;
  int _unreadCountWhileScrolled = 0; // Keeping it if it will be used in UI soon

  bool _isAudioMode = true; 
  bool _isRecording = false;
  final Record _audioRecorder = Record();
  String? _audioFilePath;
  
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  int _selectedCameraIndex = 1; 
  bool _isFlashOn = false;
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  Offset _dragOffset = Offset.zero; 
  final double _cancelThreshold = -100.0; 
  bool _isCanceledBySwipe = false; 
  bool _isRecordingLocked = false;
  Timer? _recordingTimer; 
  Duration _recordingDuration = Duration.zero;
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  // === НОВЫЕ ФУНКЦИИ ===
  // Мультиселект
  bool _isMultiSelectMode = false;
  final Set<dynamic> _selectedMessages = {};
  // Упоминания
  List<dynamic> _mentionSuggestions = [];
  bool _showMentions = false;
  // Автоудаление
  int? _autoDeleteSeconds;
  // Обои
  String? _wallpaperPath;
  // Мьют
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && mounted) setState(() => _showEmojiPicker = false);
    });
    _initChat();
    // Загружаем черновик
    _chatService.getMessageDraft(widget.chatId).then((draft) {
      if (draft != null && mounted && draft.isNotEmpty) {
        _messageController.text = draft;
        _messageController.selection = TextSelection.fromPosition(TextPosition(offset: draft.length));
      }
    });
    // Слушаем ввод для упоминаний
    _messageController.addListener(_onMessageChanged);
    // Загружаем обои и статус мьюта
    NotificationService.getChatWallpaper(widget.chatId).then((w) { if (mounted) setState(() => _wallpaperPath = w); });
    NotificationService.isChatMuted(widget.chatId).then((m) { if (mounted) setState(() => _isMuted = m); });
  }

  void _onMessageChanged() {
    final text = _messageController.text;
    // Проверяем упоминания @
    final match = RegExp(r'@(\w*)$').firstMatch(text);
    if (match != null) {
      final query = match.group(1) ?? '';
      _chatService.searchUsers(query).then((users) {
        if (mounted) setState(() { _mentionSuggestions = users; _showMentions = users.isNotEmpty; });
      });
    } else {
      if (_showMentions && mounted) setState(() { _showMentions = false; _mentionSuggestions = []; });
    }
  }

  Future<void> _initCamera({int cameraIndex = 1}) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      _selectedCameraIndex = cameraIndex < _cameras.length ? cameraIndex : 0;
      // Диспозим старый контроллер перед созданием нового
      await _cameraController?.dispose();
      _cameraController = CameraController(_cameras[_selectedCameraIndex], ResolutionPreset.medium);
      // Обязательно инициализируем перед использованием
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint("Camera init error: $e");
      if (mounted) setState(() => _isCameraInitialized = false);
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    int newIndex = _selectedCameraIndex == 0 ? 1 : 0;
    setState(() => _isCameraInitialized = false);
    await _initCamera(cameraIndex: newIndex);
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    _isFlashOn = !_isFlashOn;
    await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  Future<void> _initChat() async {
    await _loadMessages(); 
    if (!mounted) return;
    _setupScrollListener();
    await _initSignalR();  
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _typingTimer?.cancel();
    _sendTypingTimer?.cancel();
    _recordingTimer?.cancel(); 
    _cameraController?.dispose(); 
    _audioRecorder.dispose();     
    try {
      _safeSignalRSend("LeaveChat", [widget.chatId.toString()]);
      _hubConnection?.stop();
    } catch (e) {
      debugPrint("SignalR leave/stop error: $e");
    }
    super.dispose();
  }

  void _startTimer() {
    _recordingDuration = Duration.zero;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) setState(() => _recordingDuration = Duration(seconds: t.tick));
    });
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
    if (mounted) setState(() => _recordingDuration = Duration.zero);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        _audioFilePath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(path: _audioFilePath, encoder: AudioEncoder.aacLc);
        if (mounted) {
          setState(() { _isRecording = true; _isCanceledBySwipe = false; _dragOffset = Offset.zero; });
          HapticFeedback.lightImpact(); 
          _startTimer();
        }
      }
    } catch (e) {
      debugPrint("Audio recording error: $e");
    }
  }

  Future<void> _stopRecordingAndHandle() async {
    if (!_isRecording) return;
    _stopTimer();
    final path = await _audioRecorder.stop();
    if (mounted) setState(() => _isRecording = false);
    if (_isCanceledBySwipe) { HapticFeedback.heavyImpact(); if (path != null) File(path).delete(); return; }
    if (path != null) await _uploadAndSendMedia(File(path), "Audio");
  }

  Future<void> _startVideoRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      await _cameraController!.startVideoRecording();
      if (mounted) {
        setState(() { _isRecording = true; _isCanceledBySwipe = false; _dragOffset = Offset.zero; });
        HapticFeedback.lightImpact();
        _startTimer();
      }
    } catch (e) {
      debugPrint("Video recording error: $e");
    }
  }

  Future<void> _stopVideoRecordingAndHandle() async {
    if (!_isRecording || _cameraController == null) return;
    try {
      _stopTimer();
      final video = await _cameraController!.stopVideoRecording();
      if (_isFlashOn) _toggleFlash(); 
      if (mounted) setState(() => _isRecording = false);
      if (_isCanceledBySwipe) { HapticFeedback.heavyImpact(); File(video.path).delete(); return; }
      await _uploadAndSendMedia(File(video.path), "VideoNote");
    } catch (e) {
      debugPrint("Stop video recording error: $e");
    }
  }

  Future<void> _uploadAndSendMedia(File file, String messageType) async {
    // Проверяем mounted перед первым использованием context
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Отправка $messageType...")));
    String? mediaUrl = await _chatService.uploadMedia(file);
    if (!mounted) return;
    if (mediaUrl != null) {
      int? replyId = _replyingToMessage != null ? (_replyingToMessage['messageID'] ?? _replyingToMessage['MessageID']) : null;
      await _chatService.sendMessage(widget.chatId, widget.currentUserId, "", replyToMessageId: replyId, mediaUrl: mediaUrl, messageType: messageType);
      _cancelAction();
      await _loadMessages(isRefresh: true);
      _safeSignalRSend("ReceiveMessage", []);
    }
  }

  void _safeSignalRSend(String methodName, List<Object> args) {
    try { if (_hubConnection?.state == HubConnectionState.Connected) _hubConnection?.send(methodName, args: args); } catch (e) {
      debugPrint("SignalR send error: $e");
    }
  }

  Future<void> _initSignalR() async {
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          AppConfig.hubUrl,
          options: HttpConnectionOptions(
            // \u0412\u044b\u0437\u044b\u0432\u0430\u0435\u043c getToken \u0434\u0438\u043d\u0430\u043c\u0438\u0447\u0435\u0441\u043a\u0438 \u043f\u0440\u0438 \u043a\u0430\u0436\u0434\u043e\u043c \u0437\u0430\u043f\u0440\u043e\u0441\u0435, \u0447\u0442\u043e\u0431\u044b \u043d\u0435 \u0438\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u044c \u0443\u0441\u0442\u0430\u0440\u0435\u0432\u0448\u0438\u0439 \u0442\u043e\u043a\u0435\u043d\n            accessTokenFactory: () => AuthService.getToken().then((t) => t ?? ''),
          ),
        )
        .build();
    _hubConnection?.on("UserTyping", (args) {
      if (args != null && args.length > 1 && (args[1] as int) != widget.currentUserId) { 
        setState(() => _isTyping = true);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () { if (mounted) setState(() => _isTyping = false); });
      }
    });
    _hubConnection?.on("ReceiveMessage", (args) {
      if (args != null && args.isNotEmpty) {
        final newMsg = args[0] as Map<String, dynamic>;
        final msgId = newMsg['messageID'] ?? newMsg['MessageID'];
        bool exists = _messages.any((m) => (m['messageID'] ?? m['MessageID']) == msgId);
        if (!exists) {
           if (mounted) {
             setState(() {
             _messages.insert(0, newMsg);
             if (_showScrollToBottom) _unreadCountWhileScrolled++;
           });
           }
        }
      } else {
        _loadMessages(isRefresh: true);
      }
    });
    _hubConnection?.on("UpdateReaction", (args) {
      _loadMessages(isRefresh: true);
    });
    _hubConnection?.on("MessageRead", (args) {
      final readMsgId = args![0].toString();
      if (mounted) {
        setState(() {
          for (var m in _messages) {
            if ((m['messageID'] ?? m['MessageID']).toString() == readMsgId) {
              m['isRead'] = true;
              break;
            }
          }
        });
      }
    });
    try { await _hubConnection?.start(); _safeSignalRSend("JoinChat", [widget.chatId.toString()]); } catch (e) {
      debugPrint("SignalR start error: $e");
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent > 0 && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) _loadMoreMessages();
      if (_scrollController.offset > 300) { if (!_showScrollToBottom) setState(() => _showScrollToBottom = true); } 
      else { if (_showScrollToBottom) setState(() { _showScrollToBottom = false; _unreadCountWhileScrolled = 0; }); }
    });
  }

  Future<void> _loadMessages({bool isRefresh = false}) async {
    if (!isRefresh) {
      final box = Hive.box('messages_box');
      final cachedJson = box.get('msgs_${widget.chatId}_0');
      if (cachedJson != null && mounted) {
        setState(() { _messages = jsonDecode(cachedJson); _isLoading = false; });
      }
    }
    try {
      final messages = await _chatService.fetchMessages(widget.chatId, take: 30);
      if (mounted) {
        setState(() {
          _messages = messages;
          _hasMore = messages.length == 30;
          _isLoading = false;
          // Очищаем устаревшие ключи из _messageKeys для предотвращения утечки памяти
          final currentIds = messages.map((m) => (m['messageID'] ?? m['MessageID']).toString()).toSet();
          _messageKeys.removeWhere((key, _) => !currentIds.contains(key));
        });
        _chatService.markAsRead(widget.chatId, widget.currentUserId);
        if (messages.isNotEmpty) {
          _safeSignalRSend("MarkAsRead", [widget.chatId.toString(), messages.first['messageID'] ?? messages.first['MessageID']]);
        }
      }
    } catch (e) {
      if (mounted && !isRefresh && _messages.isEmpty) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) return; 
    setState(() => _isLoadingMore = true);
    try {
      final lastMsgId = _messages.last['messageID'] ?? _messages.last['MessageID'];
      final newMessages = await _chatService.fetchMessages(widget.chatId, lastMessageId: lastMsgId, take: 30);
      if (mounted) {
        setState(() {
          if (newMessages.isEmpty) {
            _hasMore = false;
          } else {
            _messages.addAll(newMessages);
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) { if (mounted) setState(() => _isLoadingMore = false); }
  }

  void _handleError(dynamic e) {
    if (!mounted) return;
    if (e.toString().contains("SESSION_EXPIRED")) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Сессия истекла. Войдите заново 🔒"), backgroundColor: Colors.red));
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } else if (e.toString().contains("SERVER_ERROR")) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ошибка сервера 🚫"), backgroundColor: Colors.orange));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Нет сети. Отправим позже! 💾"), backgroundColor: Colors.blue));
    }
  }

  // ══════════════════════════════════════════════
  // НОВЫЕ ФУНКЦИИ
  // ══════════════════════════════════════════════

  /// Выбор и отправка файла/документа
  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.first.path!);
    final fileName = result.files.first.name;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Отправка "$fileName"...')));
    final mediaUrl = await _chatService.uploadFile(file);
    if (!mounted) return;
    if (mediaUrl != null) {
      await _chatService.sendMessage(widget.chatId, widget.currentUserId, fileName, mediaUrl: mediaUrl, messageType: 'File');
      await _loadMessages(isRefresh: true);
      _safeSignalRSend("ReceiveMessage", []);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка загрузки файла 😔'), backgroundColor: Colors.red));
    }
  }

  /// Создание и отправка опроса
  Future<void> _openCreatePoll() async {
    final pollData = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePollScreen()),
    );
    if (pollData == null || !mounted) return;
    await _chatService.createPoll(widget.chatId, widget.currentUserId, pollData);
    await _loadMessages(isRefresh: true);
    _safeSignalRSend("ReceiveMessage", []);
  }

  /// Сохранить черновик и выйти
  void _saveDraftAndLeave() {
    _chatService.saveMessageDraft(widget.chatId, _messageController.text);
  }

  /// Переключить мультиселект
  void _toggleMultiSelect(dynamic message) {
    setState(() {
      if (!_isMultiSelectMode) _isMultiSelectMode = true;
      final msgId = message['messageID'] ?? message['MessageID'];
      final existing = _selectedMessages.firstWhere(
        (m) => (m['messageID'] ?? m['MessageID']) == msgId,
        orElse: () => null,
      );
      if (existing != null) {
        _selectedMessages.remove(existing);
        if (_selectedMessages.isEmpty) _isMultiSelectMode = false;
      } else {
        _selectedMessages.add(message);
      }
    });
  }

  /// Переслать выделенные сообщения
  void _forwardSelected() {
    final texts = _selectedMessages.map((m) => m['content'] ?? m['ContentText'] ?? '').join('\n— — —\n');
    Navigator.push(context, MaterialPageRoute(builder: (_) => ForwardMessageScreen(
      currentUserId: widget.currentUserId,
      textToForward: texts,
    ))).then((_) {
      setState(() { _isMultiSelectMode = false; _selectedMessages.clear(); });
    });
  }

  /// Удалить выделенные сообщения
  Future<void> _deleteSelected() async {
    for (final msg in _selectedMessages) {
      final msgId = msg['messageID'] ?? msg['MessageID'];
      if (msgId != null) await _chatService.deleteMessage(msgId);
    }
    setState(() { _isMultiSelectMode = false; _selectedMessages.clear(); });
    await _loadMessages(isRefresh: true);
  }

  /// Вставить упоминание из подсказки
  void _insertMention(String username) {
    final text = _messageController.text;
    final match = RegExp(r'@\w*$').firstMatch(text);
    if (match != null) {
      final newText = text.replaceRange(match.start, match.end, '@$username ');
      _messageController.text = newText;
      _messageController.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
    }
    setState(() { _showMentions = false; _mentionSuggestions = []; });
  }

  /// Диалог выбора авто-удаления
  void _showAutoDeleteSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final options = [
          {'label': 'Выключено', 'value': null},
          {'label': '1 минута', 'value': 60},
          {'label': '1 час', 'value': 3600},
          {'label': '1 день', 'value': 86400},
          {'label': '1 неделя', 'value': 604800},
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('Авто-удаление сообщений', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ...options.map((opt) => ListTile(
                title: Text(opt['label'] as String),
                trailing: _autoDeleteSeconds == opt['value'] ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  final seconds = opt['value'] as int?;
                  await _chatService.setAutoDelete(widget.chatId, seconds);
                  if (mounted) setState(() => _autoDeleteSeconds = seconds);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(seconds == null ? 'Авто-удаление отключено' : 'Авто-удаление: ${opt['label']}')),
                  );
                },
              )),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final text = _messageController.text;
    _messageController.clear();
    try {
      if (_editingMessage != null) {
        final msgId = _editingMessage['messageID'] ?? _editingMessage['MessageID'];
        await _chatService.editMessage(msgId, text);
      } else {
        int? replyId = _replyingToMessage != null ? (_replyingToMessage['messageID'] ?? _replyingToMessage['MessageID']) : null;
        // Передаём запланированное время, если оно было выбрано
        await _chatService.sendMessage(
          widget.chatId, widget.currentUserId, text,
          replyToMessageId: replyId,
          messageType: "Text",
          scheduledAt: _scheduledAt,
        );
        // Сбрасываем после отправки
        if (mounted) setState(() => _scheduledAt = null);
      }
      if (!mounted) return;
      _cancelAction();
      if (_scrollController.hasClients) _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      await _loadMessages(isRefresh: true);
      _safeSignalRSend("ReceiveMessage", []);
    } catch (e) {
      _handleError(e);
    }
  }

  void _onTextChanged(String text) {
    setState(() {}); 
    if (text.isNotEmpty && (_sendTypingTimer == null || !_sendTypingTimer!.isActive)) {
      _safeSignalRSend("Typing", [widget.chatId.toString(), widget.currentUserId]);
      _sendTypingTimer = Timer(const Duration(seconds: 1), () {});
    }
  }

  void _onSwipeToReply(dynamic msg) => setState(() { _editingMessage = null; _replyingToMessage = msg; });
  void _cancelAction() => setState(() { _replyingToMessage = null; _editingMessage = null; _messageController.clear(); });
  
  Future<void> _pickGiphy() async {
    GiphyGif? gif = await GiphyGet.getGif(
      context: context,
      apiKey: AppConfig.giphyApiKey,
      lang: GiphyLanguage.russian,
      tabColor: Colors.blue,
    );

    if (gif != null && gif.images?.original?.url != null) {
      final gifUrl = gif.images!.original!.url;
      // Отправляем как изображение
      await _chatService.sendMessage(widget.chatId, widget.currentUserId, "", messageType: "Image", mediaUrl: gifUrl);
      await _loadMessages(isRefresh: true);
      _safeSignalRSend("ReceiveMessage", []);
    }
  }

  void _showMessageMenu(BuildContext context, dynamic msg, bool isMe, bool isDark) {
    final text = msg['contentText'] ?? msg['ContentText'] ?? '';
    final msgId = msg['messageID'] ?? msg['MessageID'];
    Color sheetBg = isDark ? Colors.grey[900]! : Colors.white;
    Color sheetText = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(color: sheetBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // 🤩 РЯД ЭМОДЗИ ДЛЯ РЕАКЦИЙ
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏'].map((e) => GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await _chatService.toggleReaction(msgId, e);
                        _safeSignalRSend("SendReaction", [widget.chatId.toString(), msgId]);
                        _loadMessages(isRefresh: true);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 10),
                ListTile(leading: const Icon(Icons.reply, color: Colors.blue), title: Text('Ответить', style: TextStyle(color: sheetText)), onTap: () { Navigator.pop(context); _onSwipeToReply(msg); }),
                ListTile(leading: Icon((msg['isPinned'] ?? msg['IsPinned'] ?? false) ? Icons.push_pin_outlined : Icons.push_pin, color: Colors.blue), title: Text((msg['isPinned'] ?? msg['IsPinned'] ?? false) ? 'Открепить' : 'Закрепить', style: TextStyle(color: sheetText)), 
                  onTap: () async { Navigator.pop(context); await _chatService.togglePinMessage(msgId); _safeSignalRSend("ReceiveMessage", []); _loadMessages(isRefresh: true); }
                ),
                if (text.isNotEmpty) ListTile(leading: Icon(Icons.copy, color: isDark ? Colors.white54 : Colors.black54), title: Text('Скопировать', style: TextStyle(color: sheetText)), onTap: () { Clipboard.setData(ClipboardData(text: text)); Navigator.pop(context); }),
                // ПЕРЕВОД — реальный TranslationService
                if (text.isNotEmpty) ListTile(
                  leading: const Icon(Icons.translate, color: Colors.purple),
                  title: Text('Перевести', style: TextStyle(color: sheetText)),
                  onTap: () async {
                    Navigator.pop(context);
                    // Диалог выбора языка
                    final target = await showDialog<String>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('Перевести на...'),
                        children: TranslationService.languages.entries.map((e) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, e.key),
                          child: Text(e.value),
                        )).toList(),
                      ),
                    );
                    if (target == null || !mounted) return;
                    final translated = await TranslationService.translate(text, target: target);
                    if (!mounted) return;
                    if (translated != null) {
                      showDialog(context: context, builder: (ctx) => AlertDialog(
                        title: const Text('Перевод'),
                        content: SelectableText(translated, style: const TextStyle(fontSize: 16)),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
                      ));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось перевести 😔')));
                    }
                  },
                ),
                // ИСТОРИЯ ПРАВОК
                if (isMe) ListTile(
                  leading: const Icon(Icons.history, color: Colors.blueGrey),
                  title: Text('История правок', style: TextStyle(color: sheetText)),
                  onTap: () async {
                    Navigator.pop(context);
                    final history = await _chatService.getMessageEditHistory(msgId);
                    if (!mounted) return;
                    showDialog(context: context, builder: (ctx) => AlertDialog(
                      title: const Text('История изменений'),
                      content: history.isEmpty
                          ? const Text('Сообщение не редактировалось')
                          : SizedBox(
                              width: double.maxFinite,
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: history.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (ctx2, i) {
                                  final h = history[i];
                                  final editedAt = h['editedAt'] ?? h['EditedAt'] ?? '';
                                  final prevText = h['previousText'] ?? h['PreviousText'] ?? '';
                                  return ListTile(
                                    dense: true,
                                    title: Text(prevText, style: const TextStyle(fontSize: 13)),
                                    subtitle: Text(editedAt.toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  );
                                },
                              ),
                            ),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
                    ));
                  },
                ),
                // МУЛЬТИСЕЛЕКТ
                ListTile(
                  leading: Icon(Icons.checklist, color: isDark ? Colors.white54 : Colors.black54),
                  title: Text('Выбрать', style: TextStyle(color: sheetText)),
                  onTap: () { Navigator.pop(context); _toggleMultiSelect(msg); },
                ),
                // ПЕРЕСЛАТЬ
                ListTile(
                  leading: const Icon(Icons.forward, color: Colors.blue),
                  title: Text('Переслать', style: TextStyle(color: sheetText)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ForwardMessageScreen(
                      currentUserId: widget.currentUserId,
                      textToForward: text,
                      mediaUrlToForward: msg['mediaUrl'] ?? msg['MediaUrl'],
                    )));
                  },
                ),
                if (isMe) ListTile(leading: Icon(Icons.edit, color: isDark ? Colors.white54 : Colors.black54), title: Text('Изменить', style: TextStyle(color: sheetText)), onTap: () { Navigator.pop(context); setState(() { _replyingToMessage = null; _editingMessage = msg; _messageController.text = text; }); }),
                if (isMe) ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Удалить', style: TextStyle(color: Colors.red)), onTap: () async { Navigator.pop(context); await _chatService.deleteMessage(msgId); _safeSignalRSend("ReceiveMessage", []); _loadMessages(isRefresh: true); }),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageSourceMenu(bool isDark) {
    showModalBottomSheet(context: context, backgroundColor: isDark ? Colors.grey[900] : Colors.white, builder: (context) => StatefulBuilder(builder: (context, setModalState) => SafeArea(child: Wrap(children: [
      SwitchListTile(
        title: Text("Посмотреть один раз", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        subtitle: const Text("Медиа исчезнет после открытия"),
        secondary: const Icon(Icons.visibility_off, color: Colors.blue),
        value: _isViewOnceEnabled,
        onChanged: (val) {
          setModalState(() => _isViewOnceEnabled = val);
          setState(() => _isViewOnceEnabled = val);
        },
      ),
      const Divider(),
      ListTile(leading: Icon(Icons.photo_library, color: isDark ? Colors.white : Colors.black), title: Text('Фото из галереи', style: TextStyle(color: isDark ? Colors.white : Colors.black)), onTap: () { Navigator.pop(context); _pickAndSendMedia(ImageSource.gallery, false); }),
      ListTile(leading: Icon(Icons.camera_alt, color: isDark ? Colors.white : Colors.black), title: Text('Сделать фото', style: TextStyle(color: isDark ? Colors.white : Colors.black)), onTap: () { Navigator.pop(context); _pickAndSendMedia(ImageSource.camera, false); }),
      ListTile(leading: Icon(Icons.video_library, color: isDark ? Colors.white : Colors.black), title: Text('Видео из галереи', style: TextStyle(color: isDark ? Colors.white : Colors.black)), onTap: () { Navigator.pop(context); _pickAndSendMedia(ImageSource.gallery, true); }),
      ListTile(leading: const Icon(Icons.location_on, color: Colors.green), title: Text('Моё местоположение', style: TextStyle(color: isDark ? Colors.white : Colors.black)), onTap: () { Navigator.pop(context); _shareLocation(); }),
    ]))));
  }

  Future<void> _shareLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Служба геолокации отключена.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Разрешение на геолокацию отклонено.')));
        return;
      }
    }

    // Обработка случая, когда разрешение навсегда запрещено
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Геолокация отключена навсегда. Разрешите в настройках приложения.')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    final locationString = "${position.latitude},${position.longitude}";
    await _chatService.sendMessage(widget.chatId, widget.currentUserId, locationString, messageType: "Location");
    await _loadMessages(isRefresh: true);
    _safeSignalRSend("ReceiveMessage", []);
  }

  Future<void> _pickAndSendMedia(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    XFile? pickedFile;
    if (isVideo) {
      pickedFile = await picker.pickVideo(source: source);
    } else {
      pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    }

    if (pickedFile != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Отправка ${isVideo ? 'видео' : 'фото'}...")));
      
      String? uploadedMediaUrl = await _chatService.uploadMedia(File(pickedFile.path));
      if (uploadedMediaUrl != null) {
        int? replyId = _replyingToMessage != null ? (_replyingToMessage['messageID'] ?? _replyingToMessage['MessageID']) : null;
        await _chatService.sendMessage(
          widget.chatId, 
          widget.currentUserId, 
          _messageController.text.trim(), 
          replyToMessageId: replyId, 
          mediaUrl: uploadedMediaUrl, 
          messageType: isVideo ? "Video" : "Image",
          isViewOnce: _isViewOnceEnabled
        );
        if(!mounted) return;
        _cancelAction();
        setState(() => _isViewOnceEnabled = false); // Сброс
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
        await _loadMessages(isRefresh: true);
        _safeSignalRSend("ReceiveMessage", []);
      }
    }
  }

  DateTime _parseDateSafely(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr.startsWith('0001')) return DateTime.now(); 
    try { if (!dateStr.endsWith('Z')) dateStr += 'Z'; return DateTime.parse(dateStr).toLocal(); } catch (e) { return DateTime.now(); }
  }
  
  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try { if (!dateStr.endsWith('Z')) dateStr += 'Z'; return DateFormat('HH:mm').format(DateTime.parse(dateStr).toLocal()); } catch (e) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    // 🌙 Адаптация темы
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = Theme.of(context).scaffoldBackgroundColor;
    Color textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(isDark, textColor, bgColor),
      body: Container(
        decoration: BoxDecoration(
          color: bgColor,
          image: isDark ? const DecorationImage(
            image: AssetImage('assets/images/chat_bg.png'),
            fit: BoxFit.cover,
            opacity: 0.15, // Subtle pattern
          ) : null,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildMessagesList(isDark, textColor), 
                Builder(
                  builder: (context) {
                    try {
                      final pinnedMsg = _messages.firstWhere((m) => m['isPinned'] == true || m['IsPinned'] == true);
                      return Positioned(top: 0, left: 0, right: 0, child: _buildPinnedMessageBar(pinnedMsg, isDark));
                    } catch (e) { return const SizedBox(); }
                  }
                ),
                if (_isRecording && !_isAudioMode && _isCameraInitialized)
                  Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.black.withValues(alpha: 0.3)))),
                if (_isRecording && !_isAudioMode && _isCameraInitialized)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.1, left: 0, right: 0,
                    child: Column(
                      children: [
                        Center(child: ClipOval(child: Container(width: 280, height: 280, color: Colors.black, child: AspectRatio(aspectRatio: 1, child: CameraPreview(_cameraController!))))),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 32), onPressed: _toggleFlash),
                            const SizedBox(width: 50),
                            IconButton(icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 32), onPressed: _toggleCamera),
                          ],
                        )
                      ],
                    ),
                  ),
                if (_showScrollToBottom && !_isRecording)
                    Positioned(
                      right: 16, bottom: 16,
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          FloatingActionButton(
                            mini: true, backgroundColor: isDark ? Colors.grey[800] : Colors.white, foregroundColor: Colors.blue,
                            child: const Icon(Icons.keyboard_arrow_down, size: 30),
                            onPressed: () { _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); setState(() => _unreadCountWhileScrolled = 0); },
                          ),
                          if (_unreadCountWhileScrolled > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: Text('$_unreadCountWhileScrolled', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          _buildMessageInput(isDark, textColor), 
        ],
      ),
    ),
  ),
);
}
  
  void _scrollToMessage(String? msgId) {
    if (msgId == null) return;
    final key = _messageKeys[msgId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(key.currentContext!, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut, alignment: 0.5);
      setState(() => _highlightedMessageId = msgId);
      Future.delayed(const Duration(seconds: 1), () { if (mounted) setState(() => _highlightedMessageId = null); });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Сообщение слишком далеко или удалено")));
    }
  }

  Widget _buildMessagesList(bool isDark, Color mainTextColor) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    // 👇 ПУСТОЕ СОСТОЯНИЕ 👇
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.waving_hand_rounded, size: 70, color: Colors.blue.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              "Здесь пока пусто",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              "Отправьте первое сообщение!",
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey),
            ),
          ],
        ),
      );
    }
    // 👆 КОНЕЦ ПУСТОГО СОСТОЯНИЯ 👆

    return Column(
      children: [
        if (_isLoadingMore) const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        Expanded(
          child: GroupedListView<dynamic, DateTime>(
            controller: _scrollController,
            elements: _messages, reverse: true, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            groupBy: (msg) { final date = _parseDateSafely(msg['sentAt'] ?? msg['SentAt']); return DateTime(date.year, date.month, date.day); },
            sort: false, useStickyGroupSeparators: true, floatingHeader: true,
            groupSeparatorBuilder: (DateTime date) => _buildDateHeader(date),
            itemBuilder: (context, msg) {
              final index = _messages.indexOf(msg);
              final bool isMe = (msg['senderUserID'] ?? msg['SenderUserID']) == widget.currentUserId;
              final String content = msg['contentText'] ?? msg['ContentText'] ?? '';
              final String time = _formatTime(msg['sentAt'] ?? msg['SentAt']);
              final bool isRead = msg['isRead'] ?? msg['IsRead'] ?? false; 
              final bool isDelivered = msg['isDelivered'] ?? msg['IsDelivered'] ?? false;
              final String msgId = (msg['messageID'] ?? msg['MessageID'] ?? index).toString();
              
              if (!_messageKeys.containsKey(msgId)) _messageKeys[msgId] = GlobalKey();
              
              final bool isEdited = msg['isEdited'] ?? msg['IsEdited'] ?? false;
              final String? replyText = msg['replyToMessageText'] ?? msg['ReplyToMessageText'];
              final String? replySender = msg['replyToMessageSender'] ?? msg['ReplyToMessageSender'];
              final String? imageUrl = msg['imageUrl'] ?? msg['ImageUrl']; 

              final String rawMsgType = msg['messageType'] ?? msg['MessageType'] ?? 'text';
              final String typeLower = rawMsgType.toLowerCase();

              bool isImage = typeLower == 'image' || (imageUrl != null && imageUrl.contains(RegExp(r'\.(jpg|jpeg|png)', caseSensitive: false)));
              bool isAudio = typeLower == 'audio' || (imageUrl != null && imageUrl.contains(RegExp(r'\.(m4a|mp3)', caseSensitive: false)));
              bool isVideoNote = typeLower == 'videonote'; 
              bool isRegularVideo = typeLower == 'video' || (!isVideoNote && imageUrl != null && imageUrl.contains(RegExp(r'\.(mp4|webm|mov)', caseSensitive: false)));
              bool isLocation = typeLower == 'location';

              bool isVisualMedia = isImage || isVideoNote || isRegularVideo || isLocation;
              bool isVisualOnly = isVisualMedia && content.isEmpty && replyText == null;
              
              // Если это локация, контент содержит "lat,lng"
              String? staticMapUrl;
              if (isLocation && content.isNotEmpty) {
                staticMapUrl = "https://maps.googleapis.com/maps/api/staticmap?center=$content&zoom=15&size=400x200&markers=color:red|$content&key=${AppConfig.googleMapsApiKey}";
              }

              Color bubbleColor = isVisualOnly ? Colors.transparent : (isMe ? const Color(0xFF007AFF) : (isDark ? Colors.grey[800]! : const Color(0xFFE5E5EA)));
              EdgeInsets bubblePadding = isVisualOnly ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
              String displaySenderName = isMe ? "Вы" : widget.chatName;

              Widget timeAndChecks = Row(
                mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isEdited) Padding(padding: const EdgeInsets.only(right: 6), child: Text("изм.", style: TextStyle(color: isVisualOnly ? Colors.white70 : (isMe ? Colors.white70 : (isDark ? Colors.white54 : Colors.black54)), fontSize: 10, fontStyle: FontStyle.italic))),
                  Text(time, style: TextStyle(color: isVisualOnly ? Colors.white : (isMe ? Colors.white70 : (isDark ? Colors.white54 : Colors.black54)), fontSize: 10, fontWeight: isVisualOnly ? FontWeight.bold : FontWeight.normal)),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all : (isDelivered ? Icons.done_all : Icons.done),
                      size: 14,
                      color: isRead ? Colors.blueAccent : (isVisualOnly ? Colors.white : (isDark ? Colors.white54 : Colors.black54)),
                    )
                  ]
                ],
              );

              Widget overlaidTime = Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(10)), child: timeAndChecks);

              Widget messageContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyText != null)
                    GestureDetector(
                      onTap: () => _scrollToMessage((msg['replyToMessageId'] ?? msg['ReplyToMessageId'])?.toString()),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                        decoration: BoxDecoration(color: isMe ? Colors.white.withValues(alpha: 0.2) : (isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05)), border: Border(left: BorderSide(color: isMe ? Colors.white : Colors.blue, width: 3))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(replySender ?? "Unknown", style: TextStyle(color: isMe ? Colors.white : Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(replyText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isMe ? Colors.white70 : mainTextColor, fontSize: 12)),
                        ]),
                      ),
                    ),
                  if (isImage && imageUrl != null) 
                    GestureDetector(
                      onTap: () async {
                        if (msg['isExpired'] == true) return;
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenImageScreen(imageUrl: "${AppConfig.baseUrl.replaceAll('/api', '')}$imageUrl", senderName: displaySenderName, date: time)));
                        if (msg['isViewOnce'] == true) {
                          await _chatService.markViewOnceAsViewed(int.parse(msgId));
                          _loadMessages(isRefresh: true);
                        }
                      },
                      child: msg['isExpired'] == true 
                        ? Container(width: 200, height: 150, color: Colors.black54, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.visibility_off, color: Colors.white54), Text("Фото просмотрено", style: TextStyle(color: Colors.white54, fontSize: 12))]))
                        : CachedNetworkImage(imageUrl: "${AppConfig.baseUrl.replaceAll('/api', '')}$imageUrl", fit: BoxFit.cover, placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)), errorWidget: (context, url, error) => const Icon(Icons.error))
                    ),
                  if (isLocation && staticMapUrl != null) 
                    GestureDetector(
                      onTap: () async {
                         final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$content");
                         if (await canLaunchUrl(uri)) {
                           await launchUrl(uri);
                         }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(imageUrl: staticMapUrl, fit: BoxFit.cover, placeholder: (context, url) => const Center(child: CircularProgressIndicator())),
                      ),
                    ),
                  if (isRegularVideo && imageUrl != null) InlineVideoPlayer(url: "${AppConfig.baseUrl.replaceAll('/api', '')}$imageUrl", senderName: displaySenderName, date: time),
                  if (isAudio && imageUrl != null) Padding(padding: EdgeInsets.only(bottom: isVisualOnly ? 0 : 8.0), child: AudioBubble(url: "${AppConfig.baseUrl.replaceAll('/api', '')}$imageUrl", isMe: isMe)),
                  if (isVideoNote && imageUrl != null) Padding(padding: EdgeInsets.only(bottom: isVisualOnly ? 0 : 8.0), child: VideoCircle(url: "${AppConfig.baseUrl.replaceAll('/api', '')}$imageUrl")),
                  if (content.isNotEmpty && !isLocation) Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Text(content, style: TextStyle(color: isMe ? Colors.white : mainTextColor, fontSize: 16))),
                  if (msg['translatedText'] != null) 
                    Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 8), padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("ПЕРЕВОД (ИИ)", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue)),
                        Text(msg['translatedText'], style: TextStyle(color: isMe ? Colors.white : mainTextColor, fontSize: 14, fontStyle: FontStyle.italic)),
                      ]),
                    ),
                  if (!isVisualOnly) timeAndChecks,
                  
                  // 🤩 ОТОБРАЖЕНИЕ РЕАКЦИЙ
                  if (msg['reactions'] != null && (msg['reactions'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 4,
                        children: (msg['reactions'] as List).map((r) => GestureDetector(
                          onTap: () async {
                             await _chatService.toggleReaction(int.parse(msgId), r['emoji']);
                             _safeSignalRSend("SendReaction", [widget.chatId.toString(), msgId]);
                             _loadMessages(isRefresh: true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: r['userReacted'] == true ? Colors.blue.withValues(alpha: 0.3) : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: r['userReacted'] == true ? Colors.blue : Colors.transparent, width: 1)
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(r['emoji'], style: const TextStyle(fontSize: 12)),
                                const SizedBox(width: 2),
                                Text(r['count'].toString(), style: TextStyle(fontSize: 10, color: r['userReacted'] == true ? Colors.white : (isMe ? Colors.white70 : mainTextColor))),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                ],
              );

              Widget finalMessageContent = messageContent;
              if (isVisualOnly && !isVideoNote) {
                finalMessageContent = Stack(children: [messageContent, Positioned(bottom: 6, right: 6, child: overlaidTime)]);
              } else if (isVisualOnly && isVideoNote) {
                finalMessageContent = Stack(alignment: Alignment.bottomCenter, children: [messageContent, Positioned(bottom: 0, child: overlaidTime)]);
              }

              Widget messageBubble = AnimatedContainer(
                key: _messageKeys[msgId], duration: const Duration(milliseconds: 500), color: _highlightedMessageId == msgId ? Colors.blue.withValues(alpha: 0.3) : Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 2), 
                child: GestureDetector(
                  onLongPress: () => _showMessageMenu(context, msg, isMe, isDark),
                  child: Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4), padding: bubblePadding, constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(0), bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(18))),
                      child: (isVisualOnly && !isVideoNote) ? ClipRRect(borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(0), bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(18)), child: finalMessageContent) : finalMessageContent,
                    ),
                  ),
                ),
              );

              return Dismissible(
                key: Key(msgId), direction: DismissDirection.horizontal, confirmDismiss: (direction) async { _onSwipeToReply(msg); return false; },
                background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), child: const Icon(Icons.reply, color: Colors.blue)),
                secondaryBackground: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.reply, color: Colors.blue)),
                child: messageBubble,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageInput(bool isDark, Color mainTextColor) {
    bool isEditing = _editingMessage != null;
    bool hasText = _messageController.text.trim().isNotEmpty;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SafeArea(
          bottom: !_showEmojiPicker,
          child: Container(
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9F9), border: Border(top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!))),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                if (_replyingToMessage != null || isEditing)
                  Container(
                    padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 4),
                    child: Row(
                      children: [
                        Icon(isEditing ? Icons.edit : Icons.reply, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isEditing ? "Редактирование" : "Ответ", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(isEditing ? (_editingMessage['contentText'] ?? '') : (_replyingToMessage['contentText'] ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.grey, size: 20), onPressed: _cancelAction)
                      ],
                    ),
                  ),
                  
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _isRecording
                            ? _buildRecordingStatus(isDark) 
                            : Row(
                                children: [
                                   IconButton(
                                    icon: const Icon(Icons.add, color: Colors.blue),
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                        builder: (ctx) => SafeArea(child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Wrap(
                                            children: [
                                              _attachItem(ctx, Icons.photo_library, 'Галерея', Colors.purple, () => _pickImageOrVideo(fromGallery: true)),
                                              _attachItem(ctx, Icons.camera_alt, 'Камера', Colors.blue, () => _pickImageOrVideo(fromGallery: false)),
                                              _attachItem(ctx, Icons.insert_drive_file, 'Файл', Colors.orange, _pickAndSendFile),
                                              _attachItem(ctx, Icons.poll, 'Опрос', Colors.green, _openCreatePoll),
                                              _attachItem(ctx, Icons.location_on, 'Геолокация', Colors.red, _shareLocation),
                                              _attachItem(ctx, Icons.gif, 'GIF', Colors.teal, _pickGiphy),
                                              _attachItem(ctx, Icons.timer, 'Авто-удаление', Colors.amber, _showAutoDeleteSheet),
                                              _attachItem(ctx, Icons.settings_outlined, 'Опции чата', Colors.blueGrey, _showChatOptionsSheet),
                                            ],
                                          ),
                                        )),
                                      );
                                    }),
                                  IconButton(
                                    icon: Icon(_showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined, color: Colors.blue),
                                    onPressed: () { setState(() { _showEmojiPicker = !_showEmojiPicker; if (_showEmojiPicker) { _focusNode.unfocus(); } else { _focusNode.requestFocus(); } }); },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.gif_box_outlined, color: Colors.blue),
                                    onPressed: _pickGiphy,
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                                      child: TextField(
                                        controller: _messageController, focusNode: _focusNode, onChanged: _onTextChanged, 
                                        style: TextStyle(color: mainTextColor),
                                        decoration: InputDecoration(hintText: "Сообщение...", hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      
                      if (!_isRecordingLocked) ...[
                        const SizedBox(width: 8),
                        hasText || isEditing
                            ? IconButton(
                                icon: Icon(isEditing ? Icons.check : Icons.send, color: Colors.blue), 
                                onPressed: _sendMessage,
                                onLongPress: isEditing ? null : _pickSchedule,
                              )
                            : GestureDetector(
                                onTap: () {
                                  if (mounted) { setState(() => _isAudioMode = !_isAudioMode); if (!_isAudioMode) { _initCamera(); } else { _cameraController?.dispose(); _cameraController = null; _isCameraInitialized = false; } }
                                  HapticFeedback.selectionClick();
                                },
                                onLongPressStart: (_) { if (_isAudioMode) {
                                  _startRecording();
                                } else {
                                  _startVideoRecording();
                                } },
                                onLongPressMoveUpdate: (details) {
                                  if (_isRecording && !_isRecordingLocked) {
                                    if (mounted) setState(() => _dragOffset = details.localOffsetFromOrigin);
                                    if (_dragOffset.dx < _cancelThreshold && !_isCanceledBySwipe) { if (mounted) setState(() => _isCanceledBySwipe = true); }
                                    if (_dragOffset.dy < -50) { HapticFeedback.heavyImpact(); if (mounted) { setState(() { _isRecordingLocked = true; _dragOffset = Offset.zero; }); } }
                                  }
                                },
                                onLongPressEnd: (_) { if (_isRecording && !_isRecordingLocked) { if (_isAudioMode) {
                                  _stopRecordingAndHandle();
                                } else {
                                  _stopVideoRecordingAndHandle();
                                } } },
                                onLongPressCancel: () { if (_isRecording && !_isRecordingLocked) { if (_isAudioMode) {
                                  _stopRecordingAndHandle();
                                } else {
                                  _stopVideoRecordingAndHandle();
                                } } },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200), padding: EdgeInsets.all(_isRecording ? 14 : 10),
                                  decoration: BoxDecoration(color: _isRecording ? (_isCanceledBySwipe ? Colors.red : Colors.blue) : Colors.transparent, shape: BoxShape.circle),
                                  child: Icon(_isRecording ? (_isAudioMode ? Icons.mic : Icons.camera_alt) : (_isAudioMode ? Icons.mic_none : Icons.camera_alt_outlined), color: _isRecording ? Colors.white : Colors.blue, size: 28),
                                ),
                              ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildMentionSuggestions(Theme.of(context).brightness == Brightness.dark),
        _buildMultiSelectBar(),
        if (_showEmojiPicker) SizedBox(height: 250, child: EmojiPicker(textEditingController: _messageController, onEmojiSelected: (category, emoji) { _onTextChanged(_messageController.text); })),
      ],
    );
  }

 Widget _buildRecordingStatus(bool isDark) {
    if (_isRecordingLocked) {
      return Container(
        height: 48, padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 28), onPressed: () { HapticFeedback.heavyImpact(); setState(() { _isCanceledBySwipe = true; _isRecordingLocked = false; }); if (_isAudioMode) {
              _stopRecordingAndHandle();
            } else {
              _stopVideoRecordingAndHandle();
            } }),
            Row(children: [const _BlinkingMicIcon(), const SizedBox(width: 8), Text(_formatDuration(_recordingDuration), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red))]),
            IconButton(icon: const Icon(Icons.send, color: Colors.blue, size: 28), onPressed: () { setState(() => _isRecordingLocked = false); if (_isAudioMode) {
              _stopRecordingAndHandle();
            } else {
              _stopVideoRecordingAndHandle();
            } }),
          ],
        ),
      );
    }
    return Container(
      height: 48, padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        clipBehavior: Clip.none, alignment: Alignment.center,
        children: [
          Row(
            children: [
              const _BlinkingMicIcon(), const SizedBox(width: 8), Text(_formatDuration(_recordingDuration), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)), const SizedBox(width: 8),
              Expanded(
                child: Transform.translate(
                  offset: Offset(_dragOffset.dx.clamp(_cancelThreshold, 0), 0),
                  child: Opacity(
                    opacity: (1.0 - (_dragOffset.dx / (_cancelThreshold * 1.5))).clamp(0.0, 1.0),
                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey[600]), const SizedBox(width: 4), Flexible(child: Text(_isCanceledBySwipe ? "Отпускаю..." : "Смахните для отмены", style: TextStyle(color: Colors.grey[600], fontSize: 14), overflow: TextOverflow.ellipsis))]),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 0, bottom: 60, 
            child: Opacity(
              opacity: (1.0 - (_dragOffset.dy / -50)).clamp(0.0, 1.0), 
              child: Transform.translate(
                offset: Offset(0, _dragOffset.dy.clamp(-50.0, 0.0)), 
                child: Container(
                  padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                  child: const Column(children: [Icon(Icons.lock_outline, color: Colors.white, size: 20), Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 16)]),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _pickSchedule() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _scheduledAt = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          ).toUtc();
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Сообщение запланировано на: ${_scheduledAt!.toLocal().toString().substring(0, 16)}"))
        );
      }
    }
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color textColor, Color bgColor) {
    return AppBar(
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(color: Colors.transparent),
        ),
      ),
      backgroundColor: isDark ? const Color(0xAA000000) : bgColor.withValues(alpha: 0.85),
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.blue), onPressed: () => Navigator.pop(context)),
      actions: [
        if (widget.otherUserId != null)
          IconButton(
            icon: const Icon(Icons.call, color: Colors.blue),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => CallScreen(
                targetUserId: widget.otherUserId!,
                targetUserName: widget.chatName,
              )));
            },
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.blue),
          onSelected: (value) async {
            if (value == 'search') {
              // Открываем полнотекстовый поиск по сообщениям
              Navigator.push(context, MaterialPageRoute(builder: (context) => SearchMessagesScreen(currentUserId: widget.currentUserId)));
            } else if (value == 'clear') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Очистить историю?"),
                  content: const Text("Все сообщения будут удалены без возможности восстановления."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Отмена")),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Очистить", style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) {
                await _chatService.clearChatHistory(widget.chatId);
                if (mounted) {
                  setState(() => _messages = []);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("История очищена ✅")));
                }
              }
            } else if (value == 'delete') {
              await _chatService.deleteChat(widget.chatId, widget.currentUserId);
              if (mounted) Navigator.pop(context);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'search', child: Row(children: [Icon(Icons.search, size: 20), SizedBox(width: 10), Text("Поиск")])),
            const PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.cleaning_services, size: 20), SizedBox(width: 10), Text("Очистить историю")])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, color: Colors.red, size: 20), SizedBox(width: 10), Text("Удалить чат", style: TextStyle(color: Colors.red))])),
          ],
        ),
      ],
      title: GestureDetector(
        // 🪄 МАГИЯ ПЕРЕХОДА: Личный профиль ИЛИ Профиль группы 🪄
        onTap: () { 
          if (widget.otherUserId != null) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ForeignProfileScreen(userId: widget.otherUserId!, initialName: widget.chatName))); 
          } else if (widget.otherUserId == null && widget.chatName != "Избранное" && widget.chatName != "Saved Messages") {
            // ЭТО ГРУППА! Открываем профиль группы
            Navigator.push(context, MaterialPageRoute(builder: (context) => GroupInfoScreen(chatId: widget.chatId, groupName: widget.chatName, currentUserId: widget.currentUserId)));
          }
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 16, 
              backgroundColor: widget.otherUserId == null && widget.chatName != "Избранное" ? Colors.orangeAccent : (isDark ? Colors.grey[800] : Colors.grey[300]), 
              child: widget.otherUserId == null && widget.chatName != "Избранное" 
                  ? const Icon(Icons.people, color: Colors.white, size: 18) // Иконка группы в чате
                  : Text(widget.chatName.isNotEmpty ? widget.chatName[0].toUpperCase() : '?', style: TextStyle(fontSize: 14, color: textColor))
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.chatName, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  if (_isTyping) const Text("печатает...", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedMessageBar(dynamic msg, bool isDark) {
    String text = msg['contentText'] ?? msg['ContentText'] ?? '';
    final String type = (msg['messageType'] ?? msg['MessageType'] ?? 'text').toString().toLowerCase();

    if (text.isEmpty) {
      if (type == 'image') {
        text = '📷 Фотография';
      } else if (type == 'audio') {
        text = '🎤 Голосовое сообщение';
      } else if (type == 'videonote') {
        text = '📹 Видеосообщение';
      } else if (type == 'video') {
        text = '🎥 Видео';
      } else {
        text = '📎 Медиафайл';
      }
    }

    return GestureDetector(
      onTap: () => _scrollToMessage((msg['messageID'] ?? msg['MessageID'])?.toString()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900]!.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95), 
          border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Row(
          children: [
            Container(width: 3, height: 35, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Закрепленное сообщение", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                ],
              ),
            ),
            IconButton(icon: Icon(Icons.push_pin, color: isDark ? Colors.white54 : Colors.grey, size: 20), onPressed: () async { await _chatService.togglePinMessage(msg['messageID'] ?? msg['MessageID']); _safeSignalRSend("ReceiveMessage", []); _loadMessages(isRefresh: true); })
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    String dateStr = date.year == now.year ? "${date.day} ${months[date.month - 1]}" : "${date.day} ${months[date.month - 1]} ${date.year}";
    
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
        child: Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
      ),
    );
  }

  // ── Вспомогательный виджет для элемента панели вложений ──
  Widget _attachItem(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { Navigator.pop(ctx); onTap(); },
      child: SizedBox(
        width: 90,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  // ── Выбор фото/видео из галереи или камеры ──
  Future<void> _pickImageOrVideo({required bool fromGallery}) async {
    final picker = ImagePicker();
    final XFile? file = fromGallery
        ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 85)
        : await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null || !mounted) return;
    await _uploadAndSendMedia(File(file.path), 'Image');
  }

  // ── Панель подсказок упоминаний (@username) ──
  Widget _buildMentionSuggestions(bool isDark) {
    if (!_showMentions || _mentionSuggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _mentionSuggestions.length,
        itemBuilder: (ctx, i) {
          final user = _mentionSuggestions[i];
          final name = user['displayName'] ?? user['DisplayName'] ?? 'User';
          final username = user['username'] ?? user['UserName'] ?? name;
          final avatar = user['avatarUrl'] ?? user['AvatarUrl'];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.withValues(alpha: 0.2),
              backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
              child: avatar == null ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)) : null,
            ),
            title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text('@$username', style: const TextStyle(fontSize: 12, color: Colors.blue)),
            onTap: () => _insertMention(username),
          );
        },
      ),
    );
  }

  // ── Панель мультиселекта (появляется поверх если активен) ──
  Widget _buildMultiSelectBar() {
    if (!_isMultiSelectMode) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: Colors.blue,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() { _isMultiSelectMode = false; _selectedMessages.clear(); }),
            ),
            Text('${_selectedMessages.length} выбрано', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.forward, color: Colors.white),
              tooltip: 'Переслать',
              onPressed: _selectedMessages.isNotEmpty ? _forwardSelected : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Удалить',
              onPressed: _selectedMessages.isNotEmpty ? _deleteSelected : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Опции чата: мьют, обои, экспорт ──
  void _showChatOptionsSheet() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
              // Мьют
              ListTile(
                leading: Icon(_isMuted ? Icons.volume_up : Icons.volume_off, color: _isMuted ? Colors.green : Colors.orange),
                title: Text(_isMuted ? 'Включить уведомления' : 'Заглушить чат'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (_isMuted) {
                    await NotificationService.unmuteChat(widget.chatId);
                    if (mounted) setState(() => _isMuted = false);
                  } else {
                    // Выбор времени мьюта
                    final options = [
                      {'label': '1 час', 'dur': const Duration(hours: 1)},
                      {'label': '8 часов', 'dur': const Duration(hours: 8)},
                      {'label': '24 часа', 'dur': const Duration(hours: 24)},
                      {'label': 'Навсегда', 'dur': null},
                    ];
                    final picked = await showDialog<Duration?>(
                      context: context,
                      builder: (d) => SimpleDialog(
                        title: const Text('Заглушить на...'),
                        children: options.map((o) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(d, o['dur'] as Duration?),
                          child: Text(o['label'] as String),
                        )).toList(),
                      ),
                    );
                    if (picked != null || options.any((o) => o['dur'] == null)) {
                      await NotificationService.muteChat(widget.chatId, picked);
                      if (mounted) setState(() => _isMuted = true);
                    }
                  }
                },
              ),
              // Обои
              ListTile(
                leading: const Icon(Icons.wallpaper, color: Colors.purple),
                title: const Text('Обои чата'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChatWallpaperScreen(
                    chatId: widget.chatId,
                    chatName: widget.chatName,
                  ))).then((_) {
                    NotificationService.getChatWallpaper(widget.chatId).then((w) {
                      if (mounted) setState(() => _wallpaperPath = w);
                    });
                  });
                },
              ),
              // Экспорт
              ListTile(
                leading: const Icon(Icons.download, color: Colors.blue),
                title: const Text('Экспорт истории'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ExportChatScreen(
                    chatId: widget.chatId,
                    chatName: widget.chatName,
                    currentUserId: widget.currentUserId,
                  )));
                },
              ),
              // Авто-удаление
              ListTile(
                leading: const Icon(Icons.timer, color: Colors.amber),
                title: const Text('Авто-удаление сообщений'),
                onTap: () { Navigator.pop(ctx); _showAutoDeleteSheet(); },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BlinkingMicIcon extends StatefulWidget {
  const _BlinkingMicIcon();
  @override
  _BlinkingMicIconState createState() => _BlinkingMicIconState();
}
class _BlinkingMicIconState extends State<_BlinkingMicIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 18));
  }
}