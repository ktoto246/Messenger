import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

/// Расширенный сервис уведомлений, обоев, мьюта, ночного режима и компактного режима
class NotificationService {
  static const String _box = 'notification_settings';

  static Future<Box> _getBox() async =>
      Hive.isBoxOpen(_box) ? Hive.box(_box) : await Hive.openBox(_box);

  // ══════════════════════════════════════════════
  // МЬЮ ЧАТА (локально + бэкенд)
  // ══════════════════════════════════════════════

  /// Заглушить чат: null = навсегда, Duration = на время
  static Future<void> muteChat(int chatId, Duration? duration) async {
    final box = await _getBox();
    if (duration == null) {
      await box.put('mute_$chatId', -1); // -1 = навсегда
    } else {
      final until = DateTime.now().add(duration).millisecondsSinceEpoch;
      await box.put('mute_$chatId', until);
    }
    // Уведомляем бэкенд (опционально)
    try {
      final token = await AuthService.getToken();
      await http.put(
        Uri.parse('${AppConfig.baseUrl}/chats/$chatId/mute'),
        headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
        body: jsonEncode({'durationSeconds': duration?.inSeconds}),
      );
    } catch (_) {}
  }

  static Future<void> unmuteChat(int chatId) async {
    final box = await _getBox();
    await box.delete('mute_$chatId');
    try {
      final token = await AuthService.getToken();
      await http.delete(
        Uri.parse('${AppConfig.baseUrl}/chats/$chatId/mute'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  static Future<bool> isChatMuted(int chatId) async {
    final box = await _getBox();
    final val = box.get('mute_$chatId');
    if (val == null) return false;
    if (val == -1) return true; // навсегда
    return DateTime.now().millisecondsSinceEpoch < (val as int);
  }

  static Future<DateTime?> mutedUntil(int chatId) async {
    final box = await _getBox();
    final val = box.get('mute_$chatId');
    if (val == null || val == -1) return null;
    return DateTime.fromMillisecondsSinceEpoch(val as int);
  }

  // ══════════════════════════════════════════════
  // НОЧНОЙ РЕЖИМ ПО РАСПИСАНИЮ
  // ══════════════════════════════════════════════

  static Future<void> setNightModeSchedule({
    required bool enabled,
    int fromHour = 22,
    int fromMinute = 0,
    int toHour = 7,
    int toMinute = 0,
  }) async {
    final box = await _getBox();
    await box.put('night_schedule_enabled', enabled);
    await box.put('night_from_hour', fromHour);
    await box.put('night_from_min', fromMinute);
    await box.put('night_to_hour', toHour);
    await box.put('night_to_min', toMinute);
  }

  static Future<Map<String, dynamic>> getNightModeSchedule() async {
    final box = await _getBox();
    return {
      'enabled': box.get('night_schedule_enabled', defaultValue: false),
      'fromHour': box.get('night_from_hour', defaultValue: 22),
      'fromMinute': box.get('night_from_min', defaultValue: 0),
      'toHour': box.get('night_to_hour', defaultValue: 7),
      'toMinute': box.get('night_to_min', defaultValue: 0),
    };
  }

  /// Проверить, нужен ли тёмный режим сейчас по расписанию
  static Future<bool> shouldBeDarkNow() async {
    final schedule = await getNightModeSchedule();
    if (!(schedule['enabled'] as bool)) return false;
    final now = DateTime.now();
    final fromMin = (schedule['fromHour'] as int) * 60 + (schedule['fromMinute'] as int);
    final toMin = (schedule['toHour'] as int) * 60 + (schedule['toMinute'] as int);
    final nowMin = now.hour * 60 + now.minute;
    if (fromMin > toMin) {
      // Переход через полночь: 22:00 → 07:00
      return nowMin >= fromMin || nowMin < toMin;
    } else {
      return nowMin >= fromMin && nowMin < toMin;
    }
  }

  // ══════════════════════════════════════════════
  // КОМПАКТНЫЙ РЕЖИМ
  // ══════════════════════════════════════════════

  static Future<void> setCompactMode(bool compact) async {
    final box = await _getBox();
    await box.put('compact_mode', compact);
  }

  static Future<bool> isCompactMode() async {
    final box = await _getBox();
    return box.get('compact_mode', defaultValue: false) as bool;
  }

  // ══════════════════════════════════════════════
  // ОБОИ ЧАТА
  // ══════════════════════════════════════════════

  static Future<void> setChatWallpaper(int chatId, String? imagePath) async {
    final box = await _getBox();
    if (imagePath == null) {
      await box.delete('wallpaper_$chatId');
    } else {
      await box.put('wallpaper_$chatId', imagePath);
    }
  }

  static Future<String?> getChatWallpaper(int chatId) async {
    final box = await _getBox();
    return box.get('wallpaper_$chatId') as String?;
  }

  // ══════════════════════════════════════════════
  // ТЕГИ В ИЗБРАННОМ
  // ══════════════════════════════════════════════

  static Future<void> setMessageTag(int messageId, String tag) async {
    final box = await _getBox();
    await box.put('tag_$messageId', tag);
  }

  static Future<String?> getMessageTag(int messageId) async {
    final box = await _getBox();
    return box.get('tag_$messageId') as String?;
  }

  static Future<List<String>> getAllTags() async {
    final box = await _getBox();
    final tags = <String>{};
    for (final key in box.keys) {
      if (key.toString().startsWith('tag_')) {
        final v = box.get(key);
        if (v != null) tags.add(v as String);
      }
    }
    return tags.toList()..sort();
  }
}
