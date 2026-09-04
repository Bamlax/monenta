import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_data.dart';

class HolidayService {
  static const String _cacheKeyPrefix = 'cached_holidays_';

  /// 获取指定年份的节假日（优先本地缓存，同时自动联网更新）
  static Future<List<Task>> fetchHolidaysForYear(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cacheKeyPrefix$year';

    // 1. 优先读取本地已缓存的数据
    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson != null) {
      try {
        final List<dynamic> list = json.decode(cachedJson);
        return list.map((item) => _mapToTask(item)).toList();
      } catch (e) {
        debugPrint('读取节假日缓存失败: $e');
      }
    }

    // 2. 缓存不存在或需要拉取时，通过 CDN 获取官方当年放假安排
    final url = Uri.parse('https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/$year.json');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> days = data['days'] ?? [];

        // 仅保留放假的法定节假日（过滤掉调休上班的日）
        final holidayDays = days.where((d) => d['isOffDay'] == true).toList();

        // 写入本地持久缓存
        await prefs.setString(cacheKey, json.encode(holidayDays));

        return holidayDays.map((item) => _mapToTask(item)).toList();
      }
    } catch (e) {
      debugPrint('拉取 $year 年节假日网络异常: $e');
    }

    return [];
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