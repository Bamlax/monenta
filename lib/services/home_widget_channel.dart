import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/task_data.dart';

class HomeWidgetChannel {
  static const MethodChannel _channel = MethodChannel('com.monenta.app/widget');
  static const _weekStrings = ['一', '二', '三', '四', '五', '六', '日'];

  static Future<void> updateTodayWidget(TaskData data) async {
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month}-${now.day}';
    final dateTitle = '${now.month}月${now.day}日 周${_weekStrings[now.weekday - 1]}';

    final todayTasks = data.getTasksByDate(now);
    final todos = todayTasks.where((t) => !t.isEvent && !t.isReadOnly).toList();
    final doneCount = todos.where((t) => t.isDone).length;

    final items = todayTasks.map((t) {
      final listColor = t.isReadOnly
          ? 0xFFFF9800
          : (t.listName != null ? data.getListColor(t.listName!).value : 0xFF03A9F4);

      String meta = '';
      if (t.time != null) {
        final h = t.time!.hour.toString().padLeft(2, '0');
        final m = t.time!.minute.toString().padLeft(2, '0');
        meta = '$h:$m';
      } else if (data.enableTimeBuckets && t.timeBucket != null && t.timeBucket!.isNotEmpty) {
        meta = t.timeBucket!;
      } else if (t.chainId != null) {
        final chain = data.getChain(t.chainId);
        meta = t.isDone ? '#${t.chainNumber ?? chain?.count ?? 1}' : (chain?.name ?? '');
      }

      return {
        'title': t.title,
        'isDone': t.isDone,
        'isFailed': t.isFailed,
        'isEvent': t.isEvent,
        'color': listColor,
        'meta': meta,
      };
    }).toList();

    final payload = json.encode({
      'dateKey': dateKey,
      'dateTitle': dateTitle,
      'doneCount': doneCount,
      'totalCount': todos.length,
      'items': items,
    });

    try {
      await _channel.invokeMethod('updateTodayWidget', {'payload': payload});
    } on PlatformException catch (_) {}
  }
}