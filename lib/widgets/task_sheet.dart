import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_data.dart';

bool _calendarTimeZonesInitialized = false;

void _ensureCalendarTimeZones() {
  if (!_calendarTimeZonesInitialized) {
    tz.initializeTimeZones();
    _calendarTimeZonesInitialized = true;
  }
}

String _calendarErrors(dc.Result<dynamic>? result) {
  if (result == null) return '未知错误：插件没有返回结果';
  if (result.errors.isEmpty) return '未知错误';
  return result.errors.map((e) => e.errorMessage).join('；');
}

void _showCalendarSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}

Future<String?> _createSystemCalendarEvent({
  required BuildContext context,
  required String title,
  required String description,
  required DateTime? date,
  required TimeOfDay? time,
  RepeatConfig? repeatConfig,
}) async {
  if (date == null) {
    _showCalendarSnackBar(context, '请先选择日期，再添加到系统日程');
    return null;
  }

  _ensureCalendarTimeZones();

  final dcPlugin = dc.DeviceCalendarPlugin();
  var permission = await dcPlugin.hasPermissions();

  if (!permission.isSuccess || !(permission.data ?? false)) {
    permission = await dcPlugin.requestPermissions();
  }

  if (!permission.isSuccess || !(permission.data ?? false)) {
    _showCalendarSnackBar(context, '需要允许日历权限才能添加日程');
    return null;
  }

  final calendarsResult = await dcPlugin.retrieveCalendars();
  if (!calendarsResult.isSuccess) {
    _showCalendarSnackBar(context, '获取系统日历失败');
    return null;
  }

  final calendars = calendarsResult.data?.toList() ?? [];
  final writableCalendars = calendars
      .where((c) => c.id != null && !(c.isReadOnly ?? false))
      .toList();

  dc.Calendar? targetCalendar;
  for (final c in writableCalendars) {
    if (c.isDefault == true) {
      targetCalendar = c;
      break;
    }
  }

  targetCalendar ??= writableCalendars.isNotEmpty ? writableCalendars.first : null;
  String? calendarId = targetCalendar?.id;

  if (calendarId == null) {
    final createCalendarResult = await dcPlugin.createCalendar('Monenta');
    if (createCalendarResult.isSuccess && createCalendarResult.data != null) {
      calendarId = createCalendarResult.data;
    } else {
      _showCalendarSnackBar(context, '没有可写日历');
      return null;
    }
  }

  final chinaLocation = tz.getLocation('Asia/Shanghai');
  final start = tz.TZDateTime(
    chinaLocation,
    date.year,
    date.month,
    date.day,
    time?.hour ?? 0,
    time?.minute ?? 0,
  );

  final end = time == null
      ? start.add(const Duration(days: 1))
      : start.add(const Duration(minutes: 5));

  final event = dc.Event(
    calendarId,
    title: title.trim().isEmpty ? '新事件' : title.trim(),
    description: description.trim(),
    start: start,
    end: end,
    allDay: time == null,
  );

  if (repeatConfig != null) {
    dc.RecurrenceFrequency freq = dc.RecurrenceFrequency.Daily;
    if (repeatConfig.unit == 'week') freq = dc.RecurrenceFrequency.Weekly;
    if (repeatConfig.unit == 'month') freq = dc.RecurrenceFrequency.Monthly;
    if (repeatConfig.unit == 'year') freq = dc.RecurrenceFrequency.Yearly;

    event.recurrenceRule = dc.RecurrenceRule(
      freq,
      interval: repeatConfig.interval,
      endDate: repeatConfig.endDate,
    );
  }

  final saveResult = await dcPlugin.createOrUpdateEvent(event);
  if (saveResult == null || !saveResult.isSuccess || saveResult.data == null) {
    _showCalendarSnackBar(context, '系统日程创建失败：${_calendarErrors(saveResult)}');
    return null;
  }

  return saveResult.data;
}

void showTaskBottomSheet(
  BuildContext context, {
  Task? existingTask,
  DateTime? defaultDate,
  String? defaultList,
  List<String>? defaultTags,
  String? defaultTimeBucket,
}) {
  final TextEditingController titleController =
      TextEditingController(text: existingTask?.title ?? '');
  final TextEditingController descController =
      TextEditingController(text: existingTask?.description ?? '');

  DateTime? taskDate = existingTask != null ? existingTask.date : defaultDate;
  TimeOfDay? selectedTime = existingTask?.time;
  bool addToCalendar = existingTask?.addToCalendar ?? false;
  bool isEvent = existingTask?.isEvent ?? false;
  String? selectedList = existingTask?.listName ?? defaultList;
  List<String> selectedTags = existingTask?.tags.toList() ?? defaultTags ?? [];
  RepeatConfig? currentRepeat;

  // 选中的分栏
  String? selectedBucket = existingTask?.timeBucket ?? defaultTimeBucket;

  bool skipOverdue = false;

  bool isToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool isTomorrow(DateTime? d) {
    if (d == null) return false;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day;
  }

  bool isCustom(DateTime? d) {
    return d != null && !isToday(d) && !isTomorrow(d);
  }

  Future<void> confirmSkipOverdueDialog(BuildContext ctx, VoidCallback onConfirm) async {
    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('提示', style: TextStyle(color: Colors.lightBlue, fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('长按更改日期不会统计逾期'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              skipOverdue = true;
              onConfirm();
              Navigator.pop(c);
            },
            child: const Text('确定', style: TextStyle(color: Colors.lightBlue)),
          ),
        ],
      ),
    );
  }

  Future<void> confirmMoveToInboxWithDelayDialog(BuildContext ctx, VoidCallback onConfirm) async {
    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('移至待办箱', style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('将已安排日期的待办移到待办箱会记录 1 次延迟。\n（长按“无日期”可免记延迟）'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(c);
            },
            child: const Text('继续移动', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          void _showNewListDialog() {
            final ctrl = TextEditingController();
            Color selectedColor = Colors.blue;
            final colors = [
              Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
              Colors.teal, Colors.pink, Colors.amber, Colors.indigo, Colors.cyan,
            ];

            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('新建清单', style: TextStyle(color: Colors.lightBlue)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '清单名称')),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: colors.map((c) => GestureDetector(
                        onTap: () => selectedColor = c,
                        child: CircleAvatar(backgroundColor: c, radius: 16),
                      )).toList(),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
                  TextButton(
                    onPressed: () {
                      if (ctrl.text.trim().isNotEmpty) {
                        taskData.addList(ctrl.text.trim(), selectedColor);
                        setModalState(() => selectedList = ctrl.text.trim());
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('保存', style: TextStyle(color: Colors.lightBlue)),
                  ),
                ],
              ),
            );
          }

          void _showNewTagDialog() {
            final ctrl = TextEditingController();
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('新建标签', style: TextStyle(color: Colors.lightBlue)),
                content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '标签名称')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
                  TextButton(
                    onPressed: () {
                      if (ctrl.text.trim().isNotEmpty) {
                        taskData.addTag(ctrl.text.trim());
                        setModalState(() => selectedTags.add(ctrl.text.trim()));
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('保存', style: TextStyle(color: Colors.lightBlue)),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: CupertinoSlidingSegmentedControl<bool>(
                    groupValue: isEvent,
                    children: const {
                      false: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7), child: Text('代办', style: TextStyle(fontSize: 12))),
                      true: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7), child: Text('事件', style: TextStyle(fontSize: 12))),
                    },
                    thumbColor: Colors.lightBlue.shade50,
                    backgroundColor: Colors.grey.shade100,
                    onValueChanged: (value) {
                      if (value == null) return;
                      setModalState(() => isEvent = value);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...taskData.myLists.map(
                        (list) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(list.name, style: TextStyle(color: selectedList == list.name ? list.color : Colors.black87)),
                            selected: selectedList == list.name,
                            selectedColor: list.color.withOpacity(0.1),
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide.none,
                            onSelected: (val) {
                              setModalState(() => selectedList = val ? list.name : null);
                            },
                          ),
                        ),
                      ),
                      ActionChip(
                        label: const Text('+ 清单', style: TextStyle(color: Colors.lightBlue, fontSize: 12)),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.lightBlue.shade200),
                        onPressed: _showNewListDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: isEvent ? '会发生什么事？' : '准备做什么？',
                    border: InputBorder.none,
                    hintStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(hintText: '添加描述...', border: InputBorder.none),
                ),
                const SizedBox(height: 10),

                // 日期选择芯片
                Wrap(
                  spacing: 8,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onLongPress: () {
                        confirmSkipOverdueDialog(context, () {
                          setModalState(() => taskDate = DateTime.now());
                        });
                      },
                      child: ChoiceChip(
                        label: const Text('今天'),
                        selected: isToday(taskDate),
                        selectedColor: Colors.lightBlue.shade100,
                        backgroundColor: Colors.grey.shade100,
                        side: BorderSide.none,
                        onSelected: (val) => setModalState(() => taskDate = DateTime.now()),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onLongPress: () {
                        confirmSkipOverdueDialog(context, () {
                          setModalState(() => taskDate = DateTime.now().add(const Duration(days: 1)));
                        });
                      },
                      child: ChoiceChip(
                        label: const Text('明天'),
                        selected: isTomorrow(taskDate),
                        selectedColor: Colors.lightBlue.shade100,
                        backgroundColor: Colors.grey.shade100,
                        side: BorderSide.none,
                        onSelected: (val) => setModalState(() => taskDate = DateTime.now().add(const Duration(days: 1))),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onLongPress: () {
                        if (existingTask?.date != null) {
                          confirmSkipOverdueDialog(context, () {
                            setModalState(() {
                              taskDate = null;
                              addToCalendar = false;
                            });
                          });
                        } else {
                          setModalState(() {
                            taskDate = null;
                            addToCalendar = false;
                          });
                        }
                      },
                      child: ChoiceChip(
                        label: const Text('无日期'),
                        selected: taskDate == null,
                        selectedColor: Colors.lightBlue.shade100,
                        backgroundColor: Colors.grey.shade100,
                        side: BorderSide.none,
                        onSelected: (val) {
                          if (existingTask?.date != null) {
                            confirmMoveToInboxWithDelayDialog(context, () {
                              setModalState(() {
                                skipOverdue = false;
                                taskDate = null;
                                addToCalendar = false;
                              });
                            });
                          } else {
                            setModalState(() {
                              taskDate = null;
                              addToCalendar = false;
                            });
                          }
                        },
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onLongPress: () {
                        confirmSkipOverdueDialog(context, () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: taskDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            locale: const Locale('zh', 'CN'),
                          );
                          if (picked != null) setModalState(() => taskDate = picked);
                        });
                      },
                      child: ActionChip(
                        label: Text(isCustom(taskDate) ? '${taskDate!.month}月${taskDate!.day}日' : '自定日期'),
                        backgroundColor: isCustom(taskDate) ? Colors.lightBlue.shade100 : Colors.grey.shade100,
                        side: BorderSide.none,
                        avatar: const Icon(Icons.calendar_month, size: 16, color: Colors.lightBlue),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: taskDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            locale: const Locale('zh', 'CN'),
                          );
                          if (picked != null) setModalState(() => taskDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 🔴 每日分栏选择区（仅在设置中开启分栏时展示）
                if (taskData.enableTimeBuckets && taskData.timeBuckets.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.view_agenda_outlined, size: 16, color: Colors.lightBlue),
                      const SizedBox(width: 8),
                      const Text('时段分栏：', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('不分栏', style: TextStyle(fontSize: 11)),
                                selected: selectedBucket == null,
                                selectedColor: Colors.lightBlue.shade100,
                                backgroundColor: Colors.grey.shade100,
                                side: BorderSide.none,
                                onSelected: (val) => setModalState(() => selectedBucket = null),
                              ),
                              const SizedBox(width: 6),
                              ...taskData.timeBuckets.map((bucket) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(bucket, style: const TextStyle(fontSize: 11)),
                                  selected: selectedBucket == bucket,
                                  selectedColor: Colors.lightBlue.shade100,
                                  backgroundColor: Colors.grey.shade100,
                                  side: BorderSide.none,
                                  onSelected: (val) => setModalState(() => selectedBucket = val ? bucket : null),
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // 标签选择行
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.tag, color: Colors.lightBlue),
                      const SizedBox(width: 10),
                      ...taskData.myTags.map((tag) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(tag, style: TextStyle(color: selectedTags.contains(tag) ? Colors.lightBlue : Colors.black87, fontSize: 12)),
                          selected: selectedTags.contains(tag),
                          selectedColor: Colors.lightBlue.shade50,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: selectedTags.contains(tag) ? Colors.lightBlue : Colors.grey.shade300),
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                selectedTags.add(tag);
                              } else {
                                selectedTags.remove(tag);
                              }
                            });
                          },
                        ),
                      )),
                      ActionChip(
                        label: const Text('+ 标签', style: TextStyle(color: Colors.lightBlue, fontSize: 12)),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.lightBlue.shade200),
                        onPressed: _showNewTagDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, elevation: 0),
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) return;

                      bool calendarSaved = false;
                      if (addToCalendar) {
                        final eventId = await _createSystemCalendarEvent(
                          context: context,
                          title: titleController.text,
                          description: descController.text,
                          date: taskDate,
                          time: selectedTime,
                          repeatConfig: currentRepeat,
                        );
                        calendarSaved = eventId != null;
                        if (!calendarSaved) return;
                      }

                      if (existingTask != null) {
                        taskData.editTaskFull(
                          existingTask.id,
                          titleController.text,
                          descController.text,
                          taskDate,
                          selectedTime,
                          calendarSaved,
                          selectedList,
                          selectedTags,
                          updateFuture: false,
                          newIsEvent: isEvent,
                          skipOverdueCount: skipOverdue,
                          newTimeBucket: selectedBucket,
                          clearTimeBucket: selectedBucket == null,
                        );
                      } else {
                        taskData.addTask(
                          Task(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: titleController.text,
                            description: descController.text,
                            date: taskDate,
                            time: selectedTime,
                            addToCalendar: calendarSaved,
                            listName: selectedList,
                            tags: selectedTags,
                            isEvent: isEvent,
                            timeBucket: selectedBucket,
                          ),
                          repeat: currentRepeat,
                        );
                      }

                      Navigator.pop(context);
                    },
                    child: const Text('保存', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    },
  );
}