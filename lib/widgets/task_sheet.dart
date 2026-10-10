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
  final writableCalendars = calendars.where((c) => c.id != null && !(c.isReadOnly ?? false)).toList();

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

  final end = time == null ? start.add(const Duration(days: 1)) : start.add(const Duration(minutes: 5));

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
  final TextEditingController titleController = TextEditingController(text: existingTask?.title ?? '');
  final TextEditingController descController = TextEditingController(text: existingTask?.description ?? '');

  DateTime? taskDate = existingTask != null ? existingTask.date : defaultDate;
  TimeOfDay? selectedTime = existingTask?.time;
  bool addToCalendar = existingTask?.addToCalendar ?? false;
  bool isEvent = existingTask?.isEvent ?? false;
  String? selectedList = existingTask?.listName ?? defaultList;
  List<String> selectedTags = existingTask?.tags.toList() ?? defaultTags ?? [];
  RepeatConfig? currentRepeat;

  String? selectedBucket = existingTask?.timeBucket ?? defaultTimeBucket;
  String? selectedChainId = existingTask?.chainId;

  String timerMode = existingTask?.timerMode ?? taskData.defaultTimerMode;
  int countdownMinutes = existingTask?.countdownMinutes ?? taskData.defaultCountdownMinutes;
  int prepMinutes = existingTask?.prepMinutes ?? taskData.defaultPrepMinutes;
  bool allowPause = existingTask?.allowPause ?? taskData.defaultAllowPause;
  int pauseLimitMinutes = existingTask?.pauseLimitMinutes ?? taskData.defaultPauseLimitMinutes;

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

  void _showNewChainDialog(BuildContext ctx, Function(TaskChain) onCreated) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('新建链', style: TextStyle(color: Colors.lightBlue, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '如：背单词、每日早起、健身打卡'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                final chain = taskData.addChain(ctrl.text.trim());
                onCreated(chain);
                Navigator.pop(dCtx);
              }
            },
            child: const Text('创建', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCustomMinutesDialog(BuildContext ctx, String title, int initialVal, Function(int) onVal) {
    final ctrl = TextEditingController(text: '$initialVal');
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.lightBlue, fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(suffixText: '分钟'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v >= 0) {
                onVal(v);
                Navigator.pop(dCtx);
              }
            },
            child: const Text('确定', style: TextStyle(color: Colors.lightBlue)),
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
          final currentChain = taskData.getChain(selectedChainId);

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
                // 顶部代办/事件切换 与 浅蓝风格链选择器
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoSlidingSegmentedControl<bool>(
                      groupValue: isEvent,
                      children: const {
                        false: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7), child: Text('代办', style: TextStyle(fontSize: 12))),
                        true: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7), child: Text('事件', style: TextStyle(fontSize: 12))),
                      },
                      thumbColor: Colors.lightBlue.shade50,
                      backgroundColor: Colors.grey.shade100,
                      onValueChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          isEvent = value;
                          if (isEvent) selectedChainId = null;
                        });
                      },
                    ),
                    if (!isEvent)
                      PopupMenuButton<String>(
                        tooltip: '选择链',
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) {
                          if (val == '__new__') {
                            _showNewChainDialog(context, (c) {
                              setModalState(() => selectedChainId = c.id);
                            });
                          } else if (val == '__none__') {
                            setModalState(() => selectedChainId = null);
                          } else {
                            setModalState(() => selectedChainId = val);
                          }
                        },
                        itemBuilder: (pCtx) {
                          final items = <PopupMenuEntry<String>>[];
                          if (taskData.myChains.isEmpty) {
                            items.add(
                              const PopupMenuItem<String>(
                                value: '__new__',
                                child: Row(
                                  children: [
                                    Icon(Icons.add, size: 16, color: Colors.lightBlue),
                                    SizedBox(width: 6),
                                    Text('新建链', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            items.add(
                              const PopupMenuItem<String>(
                                value: '__none__',
                                child: Text('无链', style: TextStyle(color: Colors.grey)),
                              ),
                            );
                            for (final c in taskData.myChains) {
                              items.add(
                                PopupMenuItem<String>(
                                  value: c.id,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.lightBlue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('#${c.count}', style: TextStyle(fontSize: 11, color: Colors.lightBlue.shade800, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            items.add(const PopupMenuDivider());
                            items.add(
                              const PopupMenuItem<String>(
                                value: '__new__',
                                child: Row(
                                  children: [
                                    Icon(Icons.add, size: 16, color: Colors.lightBlue),
                                    SizedBox(width: 6),
                                    Text('新建链...', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );
                          }
                          return items;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedChainId != null ? Colors.lightBlue.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selectedChainId != null ? Colors.lightBlue.shade200 : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.link,
                                size: 15,
                                color: selectedChainId != null ? Colors.lightBlue.shade700 : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                currentChain != null ? currentChain.name : '链',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selectedChainId != null ? Colors.lightBlue.shade800 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_drop_down,
                                size: 16,
                                color: selectedChainId != null ? Colors.lightBlue.shade700 : Colors.grey.shade700,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
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

                // 日期选择行
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

                // 时段分栏行
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

                // 计时设定：去除外框，同一栏横向排布，最右侧放置允许暂停控件
                if (!isEvent) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: Colors.lightBlue),
                        const SizedBox(width: 8),
                        CupertinoSlidingSegmentedControl<String>(
                          groupValue: timerMode,
                          children: const {
                            'countdown': Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text('倒计时', style: TextStyle(fontSize: 11))),
                            'countup': Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text('正计时', style: TextStyle(fontSize: 11))),
                          },
                          thumbColor: Colors.lightBlue.shade50,
                          backgroundColor: Colors.grey.shade100,
                          onValueChanged: (v) {
                            if (v != null) setModalState(() => timerMode = v);
                          },
                        ),
                        if (timerMode == 'countdown') ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _showCustomMinutesDialog(
                              context,
                              '设定倒计时时长',
                              countdownMinutes,
                              (v) => setModalState(() => countdownMinutes = v),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.lightBlue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$countdownMinutes 分钟',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.lightBlue.shade800),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        // 预约控件全部切为蓝色
                        InkWell(
                          onTap: () => _showCustomMinutesDialog(
                            context,
                            '设定预约时长',
                            prepMinutes,
                            (v) => setModalState(() => prepMinutes = v),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: prepMinutes > 0 ? Colors.lightBlue.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              prepMinutes > 0 ? '预约 $prepMinutes 分' : '无预约',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: prepMinutes > 0 ? Colors.lightBlue.shade800 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 允许暂停控件（同一栏最右侧，浅蓝体系）
                        InkWell(
                          onTap: () {
                            setModalState(() {
                              allowPause = !allowPause;
                            });
                          },
                          onLongPress: () {
                            _showCustomMinutesDialog(
                              context,
                              '设定暂停限时',
                              pauseLimitMinutes,
                              (v) => setModalState(() {
                                allowPause = true;
                                pauseLimitMinutes = v;
                              }),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: allowPause ? Colors.lightBlue.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: allowPause ? Colors.lightBlue.shade200 : Colors.transparent,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  allowPause ? Icons.pause_circle_filled : Icons.pause_circle_outline,
                                  size: 14,
                                  color: allowPause ? Colors.lightBlue.shade800 : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  allowPause ? '允许暂停 $pauseLimitMinutes分' : '不可暂停',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: allowPause ? Colors.lightBlue.shade800 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // 标签栏
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
                          newChainId: selectedChainId,
                          clearChainId: selectedChainId == null,
                          newTimerMode: timerMode,
                          newCountdownMinutes: countdownMinutes,
                          newPrepMinutes: prepMinutes,
                          newAllowPause: allowPause,
                          newPauseLimitMinutes: pauseLimitMinutes,
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
                            chainId: isEvent ? null : selectedChainId,
                            timerMode: timerMode,
                            countdownMinutes: countdownMinutes,
                            prepMinutes: prepMinutes,
                            allowPause: allowPause,
                            pauseLimitMinutes: pauseLimitMinutes,
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