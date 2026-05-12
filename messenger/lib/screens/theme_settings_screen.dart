import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import '../services/auth_service.dart';
=======
import '../services/theme_service.dart';
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75

class ThemeSettingsScreen extends StatefulWidget {
  final int currentUserId;

  const ThemeSettingsScreen({super.key, required this.currentUserId});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
<<<<<<< HEAD
=======
  final ThemeService _themeService = ThemeService.instance;
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
  
  String _primaryColorHex = "#007AFF";
  double _bubbleOpacity = 0.8;
  bool _isGlassmorphism = true;
  String? _bgImageUrl;
  bool _isLoading = true;

  final List<String> _presetColors = [
    "#007AFF", // Blue
    "#FF2D55", // Pink
    "#AF52DE", // Purple
    "#34C759", // Green
    "#FF9500", // Orange
    "#5856D6", // Indigo
    "#FF3B30", // Red
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
<<<<<<< HEAD
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/themes'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _primaryColorHex = data['primaryColor'] ?? "#007AFF";
          _bubbleOpacity = (data['bubbleOpacity'] ?? 0.8).toDouble();
          _isGlassmorphism = data['isGlassmorphism'] ?? true;
          _bgImageUrl = data['bgImageUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
=======
    final data = await _themeService.getTheme();
    if (data != null) {
      setState(() {
        _primaryColorHex = data['primaryColor'] ?? "#007AFF";
        _bubbleOpacity = (data['bubbleOpacity'] ?? 0.8).toDouble();
        _isGlassmorphism = data['isGlassmorphism'] ?? true;
        _bgImageUrl = data['bgImageUrl'];
        _isLoading = false;
      });
    } else {
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTheme() async {
<<<<<<< HEAD
    try {
      final token = await AuthService.getToken();
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/themes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'primaryColor': _primaryColorHex,
          'bgImageUrl': _bgImageUrl,
          'bubbleOpacity': _bubbleOpacity,
          'isGlassmorphism': _isGlassmorphism,
        }),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Тема сохранена в облаке ☁️")));
    } catch (e) {
       debugPrint("Error saving theme: $e");
    }
=======
    await _themeService.updateTheme({
      'primaryColor': _primaryColorHex,
      'bgImageUrl': _bgImageUrl,
      'bubbleOpacity': _bubbleOpacity,
      'isGlassmorphism': _isGlassmorphism,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Тема сохранена в облаке ☁️")));
>>>>>>> 413b0d10d3c7aa05c3474b141964b6ead42dbc75
  }

  Color _parseHex(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.black;

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Тема и цвета"), actions: [IconButton(icon: const Icon(Icons.check), onPressed: _saveTheme)]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("ОСНОВНОЙ ЦВЕТ", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presetColors.map((hex) {
              bool isSelected = _primaryColorHex == hex;
              return GestureDetector(
                onTap: () => setState(() => _primaryColorHex = hex),
                child: Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(color: _parseHex(hex), shape: BoxShape.circle, border: isSelected ? Border.all(color: textColor, width: 3) : null),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          const Text("ЭФФЕКТЫ", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text("Glassmorphism"),
            subtitle: const Text("Эффект матового стекла для панелей"),
            value: _isGlassmorphism,
            onChanged: (val) => setState(() => _isGlassmorphism = val),
          ),
          const Text("Прозрачность пузырьков"),
          Slider(
            value: _bubbleOpacity,
            onChanged: (val) => setState(() => _bubbleOpacity = val),
            min: 0.1, max: 1.0,
          ),
          const SizedBox(height: 32),
          const Text("ПРЕВЬЮ", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.grey[200], borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _parseHex(_primaryColorHex).withValues(alpha: _bubbleOpacity), borderRadius: BorderRadius.circular(15)),
                    child: const Text("Привет! Как тебе новая тема?", style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.white, borderRadius: BorderRadius.circular(15)),
                    child: Text("Выглядит премиально! 🔥", style: TextStyle(color: textColor)),
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
