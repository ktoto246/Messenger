import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

class CallService {
  HubConnection? _callHub;
  
  Function(int fromUserId, String offer)? onIncomingCall;
  Function(int fromUserId, String answer)? onCallAnswered;
  Function(int fromUserId, String candidate)? onIceCandidate;
  Function(int fromUserId)? onCallEnded;

  Future<void> init() async {
    final token = await AuthService.getToken();
    _callHub = HubConnectionBuilder()
        .withUrl(AppConfig.callHubUrl, options: HttpConnectionOptions(accessTokenFactory: () async => token ?? ''))
        .build();

    _callHub?.on("IncomingCall", (args) {
      try { onIncomingCall?.call(args![0] as int, args[1] as String); } catch (e) { debugPrint("IncomingCall args error: $e"); }
    });
    _callHub?.on("CallAnswered", (args) {
      try { onCallAnswered?.call(args![0] as int, args[1] as String); } catch (e) { debugPrint("CallAnswered args error: $e"); }
    });
    _callHub?.on("ReceiveIceCandidate", (args) {
      try { onIceCandidate?.call(args![0] as int, args[1] as String); } catch (e) { debugPrint("ReceiveIceCandidate args error: $e"); }
    });
    _callHub?.on("CallEnded", (args) {
      try { onCallEnded?.call(args![0] as int); } catch (e) { debugPrint("CallEnded args error: $e"); }
    });

    await _callHub?.start();
  }

  Future<void> makeCall(int targetUserId, String offer) async {
    await _callHub?.invoke("CallUser", args: [targetUserId, offer]);
  }

  Future<void> answerCall(int targetUserId, String answer) async {
    await _callHub?.invoke("AnswerCall", args: [targetUserId, answer]);
  }

  Future<void> sendIceCandidate(int targetUserId, String candidate) async {
    await _callHub?.invoke("SendIceCandidate", args: [targetUserId, candidate]);
  }

  Future<void> hangup(int targetUserId) async {
    await _callHub?.invoke("Hangup", args: [targetUserId]);
  }
  
  void dispose() {
    _callHub?.stop();
  }
}
