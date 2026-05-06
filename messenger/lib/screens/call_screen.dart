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

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _initCall();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initCall() async {
    await _callService.init();
    
    _callService.onCallAnswered = (id, answer) async {
      if (id == widget.targetUserId) {
        await _peerConnection?.setRemoteDescription(RTCSessionDescription(jsonDecode(answer)['sdp'], 'answer'));
      }
    };

    _callService.onIceCandidate = (id, candidate) async {
      if (id == widget.targetUserId) {
        var data = jsonDecode(candidate);
        await _peerConnection?.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
      }
    };

    _callService.onCallEnded = (id) {
      if (id == widget.targetUserId) _endCall();
    };

    await _createPeerConnection();

    if (widget.isIncoming && widget.remoteOffer != null) {
      // Авто-ответ для упрощения демонстрации (в идеале кнопка "Принять")
      await _handleIncomingCall(widget.remoteOffer!);
    } else {
      await _makeOffer();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: RTCVideoView(_remoteRenderer)),
          Positioned(right: 20, top: 40, width: 120, height: 160, child: Container(color: Colors.black54, child: RTCVideoView(_localRenderer, mirror: true))),
          Positioned(bottom: 50, left: 0, right: 0, child: Column(
            children: [
              Text(widget.targetUserName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              CircleAvatar(radius: 35, backgroundColor: Colors.red, child: IconButton(icon: const Icon(Icons.call_end, color: Colors.white, size: 30), onPressed: _endCall)),
            ],
          )),
        ],
      ),
    );
  }
}
