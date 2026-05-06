import 'package:flutter/material.dart';

class FullscreenImageScreen extends StatelessWidget {
  final String imageUrl;
  final String senderName;
  final String date;

  const FullscreenImageScreen({super.key, required this.imageUrl, required this.senderName, required this.date});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(senderName, style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text(date, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
      extendBodyBehindAppBar: true, 
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0, 
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}