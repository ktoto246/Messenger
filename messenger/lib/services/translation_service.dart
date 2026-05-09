import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Сервис перевода сообщений через LibreTranslate (бесплатный open-source)
/// Fallback: Google Translate unofficial endpoint
class TranslationService {
  // Бесплатный публичный инстанс LibreTranslate
  static const String _libreUrl = 'https://libretranslate.com/translate';
  // API ключ (бесплатная регистрация на libretranslate.com)
  static const String _apiKey = '';  // Заполни на libretranslate.com

  static Future<String?> translate(String text, {String target = 'ru', String source = 'auto'}) async {
    if (text.trim().isEmpty) return null;
    try {
      // Пробуем LibreTranslate
      final response = await http.post(
        Uri.parse(_libreUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': text,
          'source': source,
          'target': target,
          if (_apiKey.isNotEmpty) 'api_key': _apiKey,
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translated = data['translatedText'] as String?;
        if (translated != null && translated != text) return translated;
      }
    } catch (e) {
      debugPrint('LibreTranslate error: $e');
    }

    // Fallback: неофициальный Google Translate endpoint
    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
        '?client=gtx&sl=$source&tl=$target&dt=t&q=${Uri.encodeComponent(text)}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final buffer = StringBuffer();
        for (final part in data[0]) {
          if (part[0] != null) buffer.write(part[0]);
        }
        return buffer.toString();
      }
    } catch (e) {
      debugPrint('Google Translate fallback error: $e');
    }
    return null;
  }

  /// Определить язык текста
  static Future<String?> detectLanguage(String text) async {
    try {
      final response = await http.post(
        Uri.parse('https://libretranslate.com/detect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'q': text, if (_apiKey.isNotEmpty) 'api_key': _apiKey}),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data[0]['language'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Список поддерживаемых языков с именами
  static const Map<String, String> languages = {
    'ru': '🇷🇺 Русский',
    'en': '🇬🇧 English',
    'de': '🇩🇪 Deutsch',
    'fr': '🇫🇷 Français',
    'es': '🇪🇸 Español',
    'it': '🇮🇹 Italiano',
    'zh': '🇨🇳 中文',
    'ja': '🇯🇵 日本語',
    'ko': '🇰🇷 한국어',
    'ar': '🇸🇦 العربية',
    'tr': '🇹🇷 Türkçe',
    'uk': '🇺🇦 Українська',
    'pl': '🇵🇱 Polski',
    'pt': '🇧🇷 Português',
  };
}
