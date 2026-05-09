import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Экран QR-кода профиля — как в Telegram
class QrProfileScreen extends StatelessWidget {
  final int userId;
  final String displayName;
  final String username;
  final String? avatarUrl;

  const QrProfileScreen({
    super.key,
    required this.userId,
    required this.displayName,
    required this.username,
    this.avatarUrl,
  });

  String get _profileLink => 'veinapp://user/$userId';

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFF1A3A6B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('QR-код', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _profileLink));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ссылка скопирована 📋')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // QR-код в карточке
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5)],
              ),
              child: Column(
                children: [
                  // Аватар над QR
                  if (avatarUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Image.network(avatarUrl!, width: 80, height: 80, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF007AFF), Color(0xFF5856D6)]),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  Text(
                    '@$username',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  // QR-код
                  QrImageView(
                    data: _profileLink,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF007AFF),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Отсканируйте QR-код в приложении',
                    style: TextStyle(fontSize: 12, color: Colors.black38),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Кнопка копирования ссылки
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _profileLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ссылка скопирована 📋')),
                );
              },
              icon: const Icon(Icons.link, color: Colors.white70),
              label: Text(
                _profileLink,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
