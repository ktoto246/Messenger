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
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import '../widgets/audio_bubble.dart';
import '../widgets/video_circle.dart';
import 'fullscreen_image_screen.dart';
import 'fullscreen_video_screen.dart';
import '../widgets/inline_video_player.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'group_info_screen.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

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
  int _unreadCountWhileScrolled = 0;

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


  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && mounted) setState(() => _showEmojiPicker = false);
    });
    _initChat();
  }

  Future<void> _initCamera({int cameraIndex = 1}) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      _selectedCameraIndex = cameraIndex < _cameras.length ? cameraIndex : 0;
      _cameraController = CameraController(_cameras[_selectedCameraIndex], ResolutionPreset.medium);
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {}
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
      if (_hubConnection?.state == HubConnectionState.Connected) {
        _hubConnection?.send("LeaveChat", args: [widget.chatId.toString()]);
        _hubConnection?.stop();
      }
    } catch (e) {}
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
    } catch (e) {}
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
    } catch (e) {}
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
    } catch (e) {}
  }

  Future<void> _uploadAndSendMedia(File file, String messageType) async {
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
    try { if (_hubConnection?.state == HubConnectionState.Connected) _hubConnection?.send(methodName, args: args); } catch (e) {}
  }

  Future<void> _initSignalR() async {
    final token = await AuthService.getToken();
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          AppConfig.hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .build();
    _hubConnection?.on("UserTyping", (args) {
      if (args != null && args.isNotEmpty && args[0] as int != widget.currentUserId) { 
        setState(() => _isTyping = true);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () { if (mounted) setState(() => _isTyping = false); });
      }
    });
    _hubConnection?.on("ReceiveMessage", (args) {
      if (_showScrollToBottom) setState(() => _unreadCountWhileScrolled++);
      _loadMessages(isRefresh: true);
    });
    try { await _hubConnection?.start(); _safeSignalRSend("JoinChat", [widget.chatId.toString()]); } catch (e) {}
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
      final messages = await _chatService.fetchMessages(widget.chatId, skip: 0, take: 30);
      if (mounted) {
        setState(() { _messages = messages; _hasMore = messages.length == 30; _isLoading = false; });
        _chatService.markAsRead(widget.chatId, widget.currentUserId);
      }
    } catch (e) { 
      if (mounted && !isRefresh && _messages.isEmpty) setState(() => _isLoading = false); 
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore) return; 
    setState(() => _isLoadingMore = true);
    try {
      final newMessages = await _chatService.fetchMessages(widget.chatId, skip: _messages.length, take: 30);
      if (mounted) setState(() { if (newMessages.isEmpty) _hasMore = false; else _messages.addAll(newMessages); _isLoadingMore = false; });
    } catch (e) { if (mounted) setState(() => _isLoadingMore = false); }
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
        await _chatService.sendMessage(widget.chatId, widget.currentUserId, text, replyToMessageId: replyId, messageType: "Text");
      }
      if (!mounted) return; 
      _cancelAction(); 
      if (_scrollController.hasClients) _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      await _loadMessages(isRefresh: true);
      _safeSignalRSend("ReceiveMessage", []);
    } catch (e) {}
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
                const SizedBox(height: 8),
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 10),
                ListTile(leading: const Icon(Icons.reply, color: Colors.blue), title: Text('Ответить', style: TextStyle(color: sheetText)), onTap: () { Navigator.pop(context); _onSwipeToReply(msg); }),
                ListTile(leading: Icon((msg['isPinned'] ?? msg['IsPinned'] ?? false) ? Icons.push_pin_outlined : Icons.push_pin, color: Colors.blue), title: Text((msg['isPinned'] ?? msg['IsPinned'] ?? false) ? 'Открепить' : 'Закрепить', style: TextStyle(color: sheetText)), 
                  onTap: () async { Navigator.pop(context); await _chatService.togglePinMessage(msgId); _safeSignalRSend("ReceiveMessage", []); _loadMessages(isRefresh: true); }
                ),
                if (text.isNotEmpty) ListTile(leading: Icon(Icons.copy, color: isDark ? Colors.white54 : Colors.black54), title: Text('Скопировать', style: TextStyle(color: sheetText)), onTap: () { Clipboard.setData(ClipboardData(text: text)); Navigator.pop(context); }),
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
    showModalBottomSheet(context: context, backgroundColor: isDark ? Colors.grey[900] : Colors.white, builder: (context) => SafeArea(child: Wrap(children: [
      ListTile(leading: Icon(Icons.photo_library, color: isDark ? Colors.white : Colors.black), title: Text('Фото из галереи', style: TextStyle(color: isDark ? Colors.white : Colors.black)), onTap: () { Navigator.pop(context); _pickAndSendMedia(ImageSource.gallery, false); }),
      ListTile(leading: Icon(Icons.camera_alt, color: isDark ? Colors.white : Colors.black), title: Text('Сделать фото', style: TextStyle(color: isDark ? Colors.white : Colors.black)), onTap: () { Navigator.pop(context); _pickAndSendMedia(ImageSource.camera, false); }),
      ListTile(leading: Icon(Icons.video_library, color: isDark ? Colors.white : Colors.black), title: Text('Видео из галереи', style: TextStyle(color: isDark ? Colors.white : Colors.black)), onTap: () { Navigator.pop(context); _pickAndSendMedia(ImageSource.gallery, true); }),
    ])));
  }

  Future<void> _pickAndSendMedia(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    XFile? pickedFile;
    if (isVideo) pickedFile = await picker.pickVideo(source: source);
    else pickedFile = await picker.pickImage(source: source, imageQuality: 70);

    if (pickedFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Отправка ${isVideo ? 'видео' : 'фото'}...")));
      String? uploadedMediaUrl = await _chatService.uploadMedia(File(pickedFile.path));
      if (uploadedMediaUrl != null) {
        int? replyId = _replyingToMessage != null ? (_replyingToMessage['messageID'] ?? _replyingToMessage['MessageID']) : null;
        await _chatService.sendMessage(widget.chatId, widget.currentUserId, _messageController.text.trim(), replyToMessageId: replyId, mediaUrl: uploadedMediaUrl, messageType: isVideo ? "Video" : "Image");
        if(!mounted) return;
        _cancelAction();
        if (_scrollController.hasClients) _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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
      backgroundColor: bgColor,
      appBar: _buildAppBar(isDark, textColor, bgColor),
      body: Column(
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
                  Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.black.withOpacity(0.3)))),
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
                    child: FloatingActionButton(
                      mini: true, backgroundColor: isDark ? Colors.grey[800] : Colors.white, foregroundColor: Colors.blue,
                      child: const Icon(Icons.keyboard_arrow_down, size: 30),
                      onPressed: () { _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); setState(() => _unreadCountWhileScrolled = 0); },
                    ),
                  ),
              ],
            ),
          ),
          _buildMessageInput(isDark, textColor), 
        ],
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
            Icon(Icons.waving_hand_rounded, size: 70, color: Colors.blue.withOpacity(0.4)),
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

              bool isVisualMedia = isImage || isVideoNote || isRegularVideo;
              bool isVisualOnly = isVisualMedia && content.isEmpty && replyText == null;

              Color bubbleColor = isVisualOnly ? Colors.transparent : (isMe ? const Color(0xFF007AFF) : (isDark ? Colors.grey[800]! : const Color(0xFFE5E5EA)));
              EdgeInsets bubblePadding = isVisualOnly ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
              String displaySenderName = isMe ? "Вы" : widget.chatName;

              Widget timeAndChecks = Row(
                mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isEdited) Padding(padding: const EdgeInsets.only(right: 6), child: Text("изм.", style: TextStyle(color: isVisualOnly ? Colors.white70 : (isMe ? Colors.white70 : (isDark ? Colors.white54 : Colors.black54)), fontSize: 10, fontStyle: FontStyle.italic))),
                  Text(time, style: TextStyle(color: isVisualOnly ? Colors.white : (isMe ? Colors.white70 : (isDark ? Colors.white54 : Colors.black54)), fontSize: 10, fontWeight: isVisualOnly ? FontWeight.bold : FontWeight.normal)),
                  if (isMe) ...[const SizedBox(width: 4), Icon(isRead ? Icons.done_all : Icons.check, size: 14, color: isVisualOnly ? Colors.white : (isRead ? Colors.white : Colors.white70))]
                ],
              );

              Widget overlaidTime = Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(10)), child: timeAndChecks);

              Widget messageContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (replyText != null)
                    GestureDetector(
                      onTap: () => _scrollToMessage((msg['replyToMessageId'] ?? msg['ReplyToMessageId'])?.toString()),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                        decoration: BoxDecoration(color: isMe ? Colors.white.withOpacity(0.2) : (isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05)), border: Border(left: BorderSide(color: isMe ? Colors.white : Colors.blue, width: 3))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(replySender ?? "Unknown", style: TextStyle(color: isMe ? Colors.white : Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(replyText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isMe ? Colors.white70 : mainTextColor, fontSize: 12)),
                        ]),
                      ),
                    ),
                  if (isImage && imageUrl != null) GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenImageScreen(imageUrl: "${AppConfig.baseUrl.replaceAll('/api', '')}$imageUrl", senderName: displaySenderName, date: time))), child: CachedNetworkImage(imageUrl: "${AppConfig.baseUrl.replaceAll('/api', '')}$imageUrl", fit: BoxFit.cover, placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)), errorWidget: (context, url, error) => const Icon(Icons.error))),
                  if (isRegularVideo && imageUrl != null) InlineVideoPlayer(url: "${AppConfig.baseUrl.replaceAll('/api', '')}$imageUrl", senderName: displaySenderName, date: time),
                  if (isAudio && imageUrl != null) Padding(padding: EdgeInsets.only(bottom: isVisualOnly ? 0 : 8.0), child: AudioBubble(url: "${AppConfig.baseUrl.replaceAll('/api', '')}$imageUrl", isMe: isMe)),
                  if (isVideoNote && imageUrl != null) Padding(padding: EdgeInsets.only(bottom: isVisualOnly ? 0 : 8.0), child: VideoCircle(url: "${AppConfig.baseUrl.replaceAll('/api', '')}$imageUrl")),
                  if (content.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Text(content, style: TextStyle(color: isMe ? Colors.white : mainTextColor, fontSize: 16))),
                  if (!isVisualOnly) timeAndChecks,
                ],
              );

              Widget finalMessageContent = messageContent;
              if (isVisualOnly && !isVideoNote) {
                finalMessageContent = Stack(children: [messageContent, Positioned(bottom: 6, right: 6, child: overlaidTime)]);
              } else if (isVisualOnly && isVideoNote) {
                finalMessageContent = Stack(alignment: Alignment.bottomCenter, children: [messageContent, Positioned(bottom: 0, child: overlaidTime)]);
              }

              Widget messageBubble = AnimatedContainer(
                key: _messageKeys[msgId], duration: const Duration(milliseconds: 500), color: _highlightedMessageId == msgId ? Colors.blue.withOpacity(0.3) : Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 2), 
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
                                  IconButton(icon: const Icon(Icons.add, color: Colors.blue), onPressed: () => _showImageSourceMenu(isDark)),
                                  IconButton(
                                    icon: Icon(_showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined, color: Colors.blue),
                                    onPressed: () { setState(() { _showEmojiPicker = !_showEmojiPicker; if (_showEmojiPicker) { _focusNode.unfocus(); } else { _focusNode.requestFocus(); } }); },
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
                            ? IconButton(icon: Icon(isEditing ? Icons.check : Icons.send, color: Colors.blue), onPressed: _sendMessage)
                            : GestureDetector(
                                onTap: () {
                                  if (mounted) { setState(() => _isAudioMode = !_isAudioMode); if (!_isAudioMode) { _initCamera(); } else { _cameraController?.dispose(); _cameraController = null; _isCameraInitialized = false; } }
                                  HapticFeedback.selectionClick();
                                },
                                onLongPressStart: (_) { if (_isAudioMode) _startRecording(); else _startVideoRecording(); },
                                onLongPressMoveUpdate: (details) {
                                  if (_isRecording && !_isRecordingLocked) {
                                    if (mounted) setState(() => _dragOffset = details.localOffsetFromOrigin);
                                    if (_dragOffset.dx < _cancelThreshold && !_isCanceledBySwipe) { if (mounted) setState(() => _isCanceledBySwipe = true); }
                                    if (_dragOffset.dy < -50) { HapticFeedback.heavyImpact(); if (mounted) { setState(() { _isRecordingLocked = true; _dragOffset = Offset.zero; }); } }
                                  }
                                },
                                onLongPressEnd: (_) { if (_isRecording && !_isRecordingLocked) { if (_isAudioMode) _stopRecordingAndHandle(); else _stopVideoRecordingAndHandle(); } },
                                onLongPressCancel: () { if (_isRecording && !_isRecordingLocked) { if (_isAudioMode) _stopRecordingAndHandle(); else _stopVideoRecordingAndHandle(); } },
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
            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 28), onPressed: () { HapticFeedback.heavyImpact(); setState(() { _isCanceledBySwipe = true; _isRecordingLocked = false; }); if (_isAudioMode) _stopRecordingAndHandle(); else _stopVideoRecordingAndHandle(); }),
            Row(children: [const _BlinkingMicIcon(), const SizedBox(width: 8), Text(_formatDuration(_recordingDuration), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red))]),
            IconButton(icon: const Icon(Icons.send, color: Colors.blue, size: 28), onPressed: () { setState(() => _isRecordingLocked = false); if (_isAudioMode) _stopRecordingAndHandle(); else _stopVideoRecordingAndHandle(); }),
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
                  padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                  child: const Column(children: [Icon(Icons.lock_outline, color: Colors.white, size: 20), Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 16)]),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color textColor, Color bgColor) {
    return AppBar(
      backgroundColor: bgColor, elevation: isDark ? 0 : 0.5,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.blue), onPressed: () => Navigator.pop(context)),
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
      if (type == 'image') text = '📷 Фотография'; else if (type == 'audio') text = '🎤 Голосовое сообщение'; else if (type == 'videonote') text = '📹 Видеосообщение'; else if (type == 'video') text = '🎥 Видео'; else text = '📎 Медиафайл';
    }

    return GestureDetector(
      onTap: () => _scrollToMessage((msg['messageID'] ?? msg['MessageID'])?.toString()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900]!.withOpacity(0.95) : Colors.white.withOpacity(0.95), 
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
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
        child: Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)), 
      ),
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