import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final int targetUserId;
  final String targetUserName;
  final bool isIncoming;
  final String? remoteOffer;

  const CallScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.isIncoming = false,
    this.remoteOffer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  // Флаг для входящих: ждём действия пользователя
  bool _isCallAccepted = false;
  bool _isCallConnecting = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    // Для исходящего звонка — сразу инициируем
    // Для входящего — ждём нажатия "Принять"
    if (!widget.isIncoming) {
      _initCall();
    } else {
      _callService.init();
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initCall() async {
    setState(() => _isCallConnecting = true);
    try {
      await _callService.init();

      _callService.onCallAnswered = (id, answer) async {
        if (!mounted) return;
        if (id == widget.targetUserId) {
          await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(jsonDecode(answer)['sdp'], 'answer'));
        }
      };

      _callService.onIceCandidate = (id, candidate) async {
        if (id == widget.targetUserId) {
          var data = jsonDecode(candidate);
          await _peerConnection?.addCandidate(
              RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
        }
      };

      _callService.onCallEnded = (id) {
        if (id == widget.targetUserId) _endCall();
      };

      await _createPeerConnection();

      if (widget.isIncoming && widget.remoteOffer != null) {
        await _handleIncomingCall(widget.remoteOffer!);
      } else {
        await _makeOffer();
      }
    } catch (e) {
      debugPrint("Ошибка инициализации звонка: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка звонка: $e"), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isCallConnecting = false);
    }
  }

  Future<void> _createPeerConnection() async {
    Map<String, dynamic> config = {
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceCandidate = (candidate) {
      _callService.sendIceCandidate(widget.targetUserId, jsonEncode({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }));
    };

    _peerConnection!.onTrack = (event) {
      if (event.track.kind == 'video') {
        _remoteRenderer.srcObject = event.streams[0];
        if (mounted) setState(() {});
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': true});
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
    _localRenderer.srcObject = _localStream;
    if (mounted) setState(() {});
  }

  Future<void> _makeOffer() async {
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    await _callService.makeCall(widget.targetUserId, jsonEncode({'sdp': offer.sdp}));
  }

  Future<void> _handleIncomingCall(String offerSdp) async {
    var data = jsonDecode(offerSdp);
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(data['sdp'], 'offer'));
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    await _callService.answerCall(widget.targetUserId, jsonEncode({'sdp': answer.sdp}));
  }

  void _acceptCall() {
    setState(() => _isCallAccepted = true);
    _initCall();
  }

  void _declineCall() {
    _callService.hangup(widget.targetUserId);
    if (mounted) Navigator.pop(context);
  }

  void _endCall() {
    _localStream?.dispose();
    _peerConnection?.close();
    _callService.hangup(widget.targetUserId);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Входящий звонок — показываем экран принятия/отклонения
    if (widget.isIncoming && !_isCallAccepted) {
      return _buildIncomingCallScreen();
    }
    return _buildActiveCallScreen();
  }

  /// Экран входящего звонка с кнопками «Принять» / «Отклонить»
  Widget _buildIncomingCallScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 60),
            // Аватар и имя
            Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue.withValues(alpha: 0.3),
                  child: Text(
                    widget.targetUserName.isNotEmpty ? widget.targetUserName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 50, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.targetUserName,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Входящий видеозвонок...",
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
              ],
            ),
            // Кнопки
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Отклонить
                  _buildCallButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: "Отклонить",
                    onTap: _declineCall,
                  ),
                  // Принять
                  _buildCallButton(
                    icon: Icons.call,
                    color: Colors.green,
                    label: "Принять",
                    onTap: _acceptCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  /// Активный звонок (после принятия или исходящий)
  Widget _buildActiveCallScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: RTCVideoView(_remoteRenderer)),
          Positioned(
            right: 20, top: 40, width: 120, height: 160,
            child: Container(color: Colors.black54, child: RTCVideoView(_localRenderer, mirror: true)),
          ),
          if (_isCallConnecting)
            const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text("Соединение...", style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            )),
          Positioned(
            bottom: 50, left: 0, right: 0,
            child: Column(
              children: [
                Text(
                  widget.targetUserName,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.red,
                  child: IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    onPressed: _endCall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
