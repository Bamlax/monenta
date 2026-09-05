import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_data.dart';

class HolidayService {
  static const String _cacheKeyPrefix = 'cached_holidays_';

  // 🔴 兜底全量法定放假（覆盖每一天，避免多天长假只显示第一天）
  static final Map<String, String> _builtinFallback = {
    // 2025年完整放假逐日
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
    '2025-04-05': '清明节',
    '2025-04-06': '清明节',
    '2025-05-01': '劳动节',
    '2025-05-02': '劳动节',
    '2025-05-03': '劳动节',
    '2025-05-04': '劳动节',
    '2025-05-05': '劳动节',
    '2025-05-31': '端午节',
    '2025-06-01': '端午节',
    '2025-06-02': '端午节',
    '2025-10-01': '国庆节',
    '2025-10-02': '国庆节',
    '2025-10-03': '国庆节',
    '2025-10-04': '国庆节',
    '2025-10-05': '国庆节',
    '2025-10-06': '中秋节',
    '2025-10-07': '国庆节',
    '2025-10-08': '国庆节',

    // 2026年完整放假逐日
    '2026-01-01': '元旦',
    '2026-01-02': '元旦',
    '2026-01-03': '元旦',
    '2026-02-15': '除夕',
    '2026-02-16': '春节',
    '2026-02-17': '春节',
    '2026-02-18': '春节',
    '2026-02-19': '春节',
    '2026-02-20': '春节',
    '2026-02-21': '春节',
    '2026-02-22': '春节',
    '2026-02-23': '春节',
    '2026-04-04': '清明节',
    '2026-04-05': '清明节',
    '2026-04-06': '清明节',
    '2026-05-01': '劳动节',
    '2026-05-02': '劳动节',
    '2026-05-03': '劳动节',
    '2026-05-04': '劳动节',
    '2026-05-05': '劳动节',
    '2026-06-19': '端午节',
    '2026-06-20': '端午节',
    '2026-06-21': '端午节',
    '2026-09-25': '中秋节',
    '2026-09-26': '中秋节',
    '2026-09-27': '中秋节',
    '2026-10-01': '国庆节',
    '2026-10-02': '国庆节',
    '2026-10-03': '国庆节',
    '2026-10-04': '国庆节',
    '2026-10-05': '国庆节',
    '2026-10-06': '国庆节',
    '2026-10-07': '国庆节',

    // 2027年完整放假逐日
    '2027-01-01': '元旦',
    '2027-01-02': '元旦',
    '2027-01-03': '元旦',
    '2027-02-05': '除夕',
    '2027-02-06': '春节',
    '2027-02-07': '春节',
    '2027-02-08': '春节',
    '2027-02-09': '春节',
    '2027-02-10': '春节',
    '2027-02-11': '春节',
    '2027-02-12': '春节',
    '2027-04-04': '清明节',
    '2027-04-05': '清明节',
    '2027-05-01': '劳动节',
    '2027-05-02': '劳动节',
    '2027-05-03': '劳动节',
    '2027-06-09': '端午节',
    '2027-09-15': '中秋节',
    '2027-10-01': '国庆节',
    '2027-10-02': '国庆节',
    '2027-10-03': '国庆节',
    '2027-10-04': '国庆节',
    '2027-10-05': '国庆节',
    '2027-10-06': '国庆节',
    '2027-10-07': '国庆节',
  };

  static Future<List<Task>> fetchHolidaysForYear(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cacheKeyPrefix$year';

    // 1. 读取本地缓存
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

    // 2. 联网拉取官方安排（包含长假中每一天）
    try {
      final url = Uri.parse('https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/$year.json');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> days = data['days'] ?? [];

        // 包含所有连休日（isOffDay == true）
        final holidayDays = days.where((d) => d['isOffDay'] == true).toList();

        if (holidayDays.isNotEmpty) {
          await prefs.setString(cacheKey, json.encode(holidayDays));
          return holidayDays.map((item) => _mapToTask(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('网络拉取 $year 节假日失败，转本地全量兜底: $e');
    }

    // 3. 本地兜底数据（长假多天全量录入）
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

    return fallbackTasks;
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