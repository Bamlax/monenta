import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_data.dart';

class HolidayService {
  static const String _cacheKeyPrefix = 'cached_holidays_';

  // 兜底常用法定节日（公历固定及常见日期，断网时自动保障可用）
  static final Map<String, String> _builtinFallback = {
    // 2025
    '2025-01-01': '元旦',
    '2025-01-28': '除夕',
    '2025-01-29': '春节',
    '2025-01-30': '春节',
    '2025-01-31': '春节',
    '2025-02-01': '春节',
    '2025-02-02': '春节',
    '2025-02-03': '春节',
    '2025-02-04': '春节',
    '2025-04-04': '清明节',
    '2025-05-01': '劳动节',
    '2025-05-31': '端午节',
    '2025-10-01': '国庆节',
    '2025-10-06': '中秋节',

    // 2026
    '2026-01-01': '元旦',
    '2026-02-15': '除夕',
    '2026-02-16': '春节',
    '2026-02-17': '春节',
    '2026-02-18': '春节',
    '2026-02-19': '春节',
    '2026-02-20': '春节',
    '2026-02-21': '春节',
    '2026-02-22': '春节',
    '2026-02-23': '春节',
    '2026-04-05': '清明节',
    '2026-05-01': '劳动节',
    '2026-06-19': '端午节',
    '2026-09-25': '中秋节',
    '2026-10-01': '国庆节',

    // 2027
    '2027-01-01': '元旦',
    '2027-02-05': '除夕',
    '2027-02-06': '春节',
    '2027-04-05': '清明节',
    '2027-05-01': '劳动节',
    '2027-06-09': '端午节',
    '2027-09-15': '中秋节',
    '2027-10-01': '国庆节',
  };

  static Future<List<Task>> fetchHolidaysForYear(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cacheKeyPrefix$year';

    // 1. 优先读取已成功缓存的离线数据
    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson != null) {
      try {
        final List<dynamic> list = json.decode(cachedJson);
        if (list.isNotEmpty) {
          return list.map((item) => _mapToTask(item)).toList();
        }
      } catch (e) {
        debugPrint('读取节假日缓存解析失败: $e');
      }
    }

    // 2. 尝试从网络 CDN 拉取官方最新安排
    try {
      final url = Uri.parse('https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/$year.json');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> days = data['days'] ?? [];
        final holidayDays = days.where((d) => d['isOffDay'] == true).toList();

        if (holidayDays.isNotEmpty) {
          await prefs.setString(cacheKey, json.encode(holidayDays));
          return holidayDays.map((item) => _mapToTask(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('网络拉取 $year 节假日失败，启用本地保底: $e');
    }

    // 3. 网络异常或无缓存时，使用本地内置保底生成（保证必定有数据显示）
    final List<Task> fallbackTasks = [];
    _builtinFallback.forEach((dateStr, name) {
      if (dateStr.startsWith('$year-')) {
        final parts = dateStr.split('-');
        fallbackTasks.add(Task(
          id: 'holiday_$dateStr',
          title: name,
          description: '',
          date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
          isEvent: true,
          isReadOnly: true,
          tags: const ['节假日'],
        ));
      }
    });

    // 任意年份的公历固定节日（元旦、五一、十一）兜底
    if (fallbackTasks.isEmpty) {
      fallbackTasks.addAll([
        _createFixedTask(year, 1, 1, '元旦'),
        _createFixedTask(year, 5, 1, '劳动节'),
        _createFixedTask(year, 10, 1, '国庆节'),
      ]);
    }

    return fallbackTasks;
  }

  static Task _createFixedTask(int year, int month, int day, String title) {
    final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    return Task(
      id: 'holiday_$dateStr',
      title: title,
      description: '',
      date: DateTime(year, month, day),
      isEvent: true,
      isReadOnly: true,
      tags: const ['节假日'],
    );
  }

  static Task _mapToTask(dynamic item) {
    final String dateStr = item['date'];
    final String name = item['name'] ?? '节假日';
    final parts = dateStr.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    return Task(
      id: 'holiday_$dateStr',
      title: name,
      description: '',
      date: DateTime(year, month, day),
      isEvent: true,
      isReadOnly: true,
      tags: const ['节假日'],
    );
  }
}