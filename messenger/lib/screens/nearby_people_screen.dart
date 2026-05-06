import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/chat_service.dart';
import '../config/app_config.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'dart:convert';
import 'chat_detail_screen.dart';

/// Экран «Люди рядом» — поиск пользователей по геолокации
class NearbyPeopleScreen extends StatefulWidget {
  final int currentUserId;
  const NearbyPeopleScreen({super.key, required this.currentUserId});

  @override
  State<NearbyPeopleScreen> createState() => _NearbyPeopleScreenState();
}

class _NearbyPeopleScreenState extends State<NearbyPeopleScreen> {
  List<dynamic> _nearbyUsers = [];
  bool _isLoading = false;
  bool _isSharing = false;
  double _radiusKm = 5.0;
  Position? _myPosition;
  String? _error;

  @override
  void initState() {
    super.initState();
    _findNearby();
  }

  @override
  void dispose() {
    if (_isSharing) _stopSharing();
    super.dispose();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  Future<void> _findNearby() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Геолокация отключена');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Разрешение отклонено');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Разрешение навсегда запрещено. Включите в настройках');

      _myPosition = await Geolocator.getCurrentPosition();

      // Отправляем позицию и получаем людей рядом
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/users/nearby'),
        headers: headers,
        body: jsonEncode({
          'latitude': _myPosition!.latitude,
          'longitude': _myPosition!.longitude,
          'radiusKm': _radiusKm,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {
        setState(() { _nearbyUsers = jsonDecode(response.body); _isLoading = false; });
      } else {
        if (mounted) setState(() { _isLoading = false; _error = 'Сервер недоступен (${response.statusCode})'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  Future<void> _stopSharing() async {
    try {
      final headers = await _getHeaders();
      await http.delete(Uri.parse('${AppConfig.baseUrl}/users/nearby/location'), headers: headers);
    } catch (_) {}
    if (mounted) setState(() => _isSharing = false);
  }

  String _distanceText(double? distanceM) {
    if (distanceM == null) return '';
    if (distanceM < 1000) return '${distanceM.round()} м';
    return '${(distanceM / 1000).toStringAsFixed(1)} км';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Люди рядом', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _findNearby),
        ],
      ),
      body: Column(
        children: [
          // Предупреждение о конфиденциальности
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Геолокация видна людям рядом', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('Ваша точная позиция никогда не передаётся', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Слайдер радиуса
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.radar, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _radiusKm,
                    min: 0.5,
                    max: 50,
                    divisions: 20,
                    label: '${_radiusKm.toStringAsFixed(1)} км',
                    onChanged: (v) => setState(() => _radiusKm = v),
                    onChangeEnd: (_) => _findNearby(),
                  ),
                ),
                Text('${_radiusKm.toStringAsFixed(1)} км', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),

          // Список
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_off, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 15)),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Попробовать снова'),
                                onPressed: _findNearby,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _nearbyUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_search, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text('Никого нет в радиусе ${_radiusKm.toStringAsFixed(0)} км', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _nearbyUsers.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                            itemBuilder: (ctx, i) {
                              final user = _nearbyUsers[i];
                              final name = user['displayName'] ?? user['DisplayName'] ?? 'Пользователь';
                              final username = user['username'] ?? user['UserName'] ?? '';
                              final avatar = user['avatarUrl'] ?? user['AvatarUrl'];
                              final distance = user['distanceMeters'] ?? user['DistanceMeters'];
                              final userId = user['userID'] ?? user['UserId'];
                              final chatId = user['chatId'] ?? user['ChatId'];

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.blue.withValues(alpha: 0.15),
                                  backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                                  child: avatar == null
                                      ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
                                      : null,
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: username.isNotEmpty ? Text('@$username') : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                    const SizedBox(width: 2),
                                    Text(
                                      _distanceText(distance?.toDouble()),
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),
                                onTap: () {
                                  if (chatId != null && userId != null) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(
                                      chatId: chatId is int ? chatId : int.parse(chatId.toString()),
                                      chatName: name,
                                      currentUserId: widget.currentUserId,
                                      otherUserId: userId is int ? userId : int.parse(userId.toString()),
                                    )));
                                  }
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
