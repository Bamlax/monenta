import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/holiday_service.dart';

class RepeatConfig {
  final String groupId;
  final int interval;
  final String unit;
  final DateTime? endDate;

  RepeatConfig({
    required this.groupId,
    required this.interval,
    required this.unit,
    this.endDate,
  });

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'interval': interval,
        'unit': unit,
        'endDate': endDate?.toIso8601String(),
      };

  static RepeatConfig fromJson(Map<String, dynamic> json) => RepeatConfig(
        groupId: json['groupId'],
        interval: json['interval'],
        unit: json['unit'],
        endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      );
}

class TaskList {
  String name;
  Color color;

  TaskList({
    required this.name,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'color': color.value,
      };

  static TaskList fromJson(Map<String, dynamic> json) => TaskList(
        name: json['name'],
        color: Color(json['color']),
      );
}

class TaskChain {
  String id;
  String name;
  int count;

  TaskChain({
    required this.id,
    required this.name,
    this.count = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'count': count,
      };

  static TaskChain fromJson(Map<String, dynamic> json) => TaskChain(
        id: json['id'],
        name: json['name'],
        count: json['count'] ?? 1,
      );
}

class FocusRecord {
  final String id;
  final DateTime date;
  final int seconds;
  final String? listName;
  final String? taskId;

  FocusRecord({
    required this.id,
    required this.date,
    required this.seconds,
    this.listName,
    this.taskId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'seconds': seconds,
        'listName': listName,
        'taskId': taskId,
      };

  static FocusRecord fromJson(Map<String, dynamic> json) => FocusRecord(
        id: json['id'],
        date: DateTime.parse(json['date']),
        seconds: json['seconds'] ?? 0,
        listName: json['listName'],
        taskId: json['taskId'],
      );
}

class Task {
  String id;
  String title;
  String description;
  DateTime? date;
  TimeOfDay? time;
  bool addToCalendar;
  String? listName;
  bool isDone;
  DateTime? doneDate;
  bool isEvent;
  List<String> tags;
  String? repeatGroupId;
  String? repeatRuleText;
  bool isReadOnly;
  int overdueCount;
  String? timeBucket;
  int focusDurationSeconds;

  String? chainId;
  int? chainNumber;
  bool isFailed;
  String? failRemark;

  String timerMode; // 'countdown' | 'countup'
  int countdownMinutes;
  int prepMinutes;

  // 暂停控制配置
  bool allowPause;
  int pauseLimitMinutes;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.date,
    this.time,
    this.addToCalendar = false,
    this.listName,
    this.isDone = false,
    this.doneDate,
    this.isEvent = false,
    this.tags = const [],
    this.repeatGroupId,
    this.repeatRuleText,
    this.isReadOnly = false,
    this.overdueCount = 0,
    this.timeBucket,
    this.focusDurationSeconds = 0,
    this.chainId,
    this.chainNumber,
    this.isFailed = false,
    this.failRemark,
    this.timerMode = 'countdown',
    this.countdownMinutes = 25,
    this.prepMinutes = 0,
    this.allowPause = false,
    this.pauseLimitMinutes = 5,
  });

  Task copyWith({
    String? id,
    DateTime? date,
    String? repeatGroupId,
    String? repeatRuleText,
    bool? isEvent,
    bool? isReadOnly,
    int? overdueCount,
    String? timeBucket,
    bool clearTimeBucket = false,
    int? focusDurationSeconds,
    String? chainId,
    bool clearChainId = false,
    int? chainNumber,
    bool? isFailed,
    String? failRemark,
    String? timerMode,
    int? countdownMinutes,
    int? prepMinutes,
    bool? allowPause,
    int? pauseLimitMinutes,
  }) {
    return Task(
      id: id ?? this.id,
      title: title,
      description: description,
      date: date ?? this.date,
      time: time,
      addToCalendar: addToCalendar,
      listName: listName,
      isDone: isDone,
      doneDate: doneDate,
      isEvent: isEvent ?? this.isEvent,
      tags: List.from(tags),
      repeatGroupId: repeatGroupId ?? this.repeatGroupId,
      repeatRuleText: repeatRuleText ?? this.repeatRuleText,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      overdueCount: overdueCount ?? this.overdueCount,
      timeBucket: clearTimeBucket ? null : (timeBucket ?? this.timeBucket),
      focusDurationSeconds: focusDurationSeconds ?? this.focusDurationSeconds,
      chainId: clearChainId ? null : (chainId ?? this.chainId),
      chainNumber: chainNumber ?? this.chainNumber,
      isFailed: isFailed ?? this.isFailed,
      failRemark: failRemark ?? this.failRemark,
      timerMode: timerMode ?? this.timerMode,
      countdownMinutes: countdownMinutes ?? this.countdownMinutes,
      prepMinutes: prepMinutes ?? this.prepMinutes,
      allowPause: allowPause ?? this.allowPause,
      pauseLimitMinutes: pauseLimitMinutes ?? this.pauseLimitMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date?.toIso8601String(),
        'timeHour': time?.hour,
        'timeMinute': time?.minute,
        'addToCalendar': addToCalendar,
        'listName': listName,
        'isDone': isDone,
        'doneDate': doneDate?.toIso8601String(),
        'isEvent': isEvent,
        'tags': tags,
        'repeatGroupId': repeatGroupId,
        'repeatRuleText': repeatRuleText,
        'isReadOnly': isReadOnly,
        'overdueCount': overdueCount,
        'timeBucket': timeBucket,
        'focusDurationSeconds': focusDurationSeconds,
        'chainId': chainId,
        'chainNumber': chainNumber,
        'isFailed': isFailed,
        'failRemark': failRemark,
        'timerMode': timerMode,
        'countdownMinutes': countdownMinutes,
        'prepMinutes': prepMinutes,
        'allowPause': allowPause,
        'pauseLimitMinutes': pauseLimitMinutes,
      };

  static Task fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        description: json['description'] ?? '',
        date: json['date'] != null ? DateTime.parse(json['date']) : null,
        time: json['timeHour'] != null
            ? TimeOfDay(hour: json['timeHour'], minute: json['timeMinute'])
            : null,
        addToCalendar: json['addToCalendar'] ?? false,
        listName: json['listName'],
        isDone: json['isDone'] ?? false,
        doneDate: json['doneDate'] != null ? DateTime.parse(json['doneDate']) : null,
        isEvent: json['isEvent'] ?? false,
        tags: List<String>.from(json['tags'] ?? []),
        repeatGroupId: json['repeatGroupId'],
        repeatRuleText: json['repeatRuleText'],
        isReadOnly: json['isReadOnly'] ?? false,
        overdueCount: json['overdueCount'] ?? 0,
        timeBucket: json['timeBucket'],
        focusDurationSeconds: json['focusDurationSeconds'] ?? 0,
        chainId: json['chainId'],
        chainNumber: json['chainNumber'],
        isFailed: json['isFailed'] ?? false,
        failRemark: json['failRemark'],
        timerMode: json['timerMode'] ?? 'countdown',
        countdownMinutes: json['countdownMinutes'] ?? 25,
        prepMinutes: json['prepMinutes'] ?? 0,
        allowPause: json['allowPause'] ?? false,
        pauseLimitMinutes: json['pauseLimitMinutes'] ?? 5,
      );
}

final ValueNotifier<int> appTabIndex = ValueNotifier<int>(0);

class TaskData extends ChangeNotifier {
  final List<Task> _tasks = [];
  final List<TaskList> myLists = [];
  final List<String> myTags = [];
  final List<TaskChain> myChains = [];
  final List<FocusRecord> focusRecords = [];

  Task? currentFocusTask;
  String currentHomeMode = 'todo';
  String? currentHomeParam;

  bool enableHolidays = false;
  bool enableTimeBuckets = false;
  List<String> timeBuckets = ['上午', '中午', '下午', '晚上'];

  String defaultTimerMode = 'countdown';
  int defaultCountdownMinutes = 25;
  int defaultPrepMinutes = 0;
  bool defaultAllowPause = false;
  int defaultPauseLimitMinutes = 5;

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    enableHolidays = prefs.getBool('monenta_enable_holidays') ?? false;
    enableTimeBuckets = prefs.getBool('monenta_enable_time_buckets') ?? false;

    defaultTimerMode = prefs.getString('monenta_def_timer_mode') ?? 'countdown';
    defaultCountdownMinutes = prefs.getInt('monenta_def_countdown_mins') ?? 25;
    defaultPrepMinutes = prefs.getInt('monenta_def_prep_mins') ?? 0;
    defaultAllowPause = prefs.getBool('monenta_def_allow_pause') ?? false;
    defaultPauseLimitMinutes = prefs.getInt('monenta_def_pause_limit_mins') ?? 5;

    final bucketsStr = prefs.getString('monenta_time_buckets');
    if (bucketsStr != null) {
      final List<dynamic> decoded = json.decode(bucketsStr);
      timeBuckets = decoded.map((e) => e.toString()).toList();
    }

    final chainsStr = prefs.getString('monenta_chains');
    if (chainsStr != null) {
      final Iterable c = json.decode(chainsStr);
      myChains.clear();
      myChains.addAll(List<TaskChain>.from(c.map((m) => TaskChain.fromJson(m))));
    }

    final listsStr = prefs.getString('monenta_lists');
    if (listsStr != null) {
      final Iterable l = json.decode(listsStr);
      myLists.clear();
      myLists.addAll(List<TaskList>.from(l.map((m) => TaskList.fromJson(m))));
    }

    final tagsStr = prefs.getString('monenta_tags');
    if (tagsStr != null) {
      final Iterable t = json.decode(tagsStr);
      myTags.clear();
      myTags.addAll(List<String>.from(t));
    }

    final tasksStr = prefs.getString('monenta_tasks');
    if (tasksStr != null) {
      final Iterable t = json.decode(tasksStr);
      _tasks.clear();
      _tasks.addAll(List<Task>.from(t.map((m) => Task.fromJson(m))));
    }

    final recordsStr = prefs.getString('monenta_focus_records');
    if (recordsStr != null) {
      final Iterable r = json.decode(recordsStr);
      focusRecords.clear();
      focusRecords.addAll(List<FocusRecord>.from(r.map((m) => FocusRecord.fromJson(m))));
    }

    if (enableHolidays) {
      _syncHolidays(notify: false);
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('monenta_enable_holidays', enableHolidays);
    await prefs.setBool('monenta_enable_time_buckets', enableTimeBuckets);
    await prefs.setString('monenta_time_buckets', json.encode(timeBuckets));

    await prefs.setString('monenta_def_timer_mode', defaultTimerMode);
    await prefs.setInt('monenta_def_countdown_mins', defaultCountdownMinutes);
    await prefs.setInt('monenta_def_prep_mins', defaultPrepMinutes);
    await prefs.setBool('monenta_def_allow_pause', defaultAllowPause);
    await prefs.setInt('monenta_def_pause_limit_mins', defaultPauseLimitMinutes);

    await prefs.setString('monenta_chains', json.encode(myChains.map((e) => e.toJson()).toList()));
    await prefs.setString('monenta_lists', json.encode(myLists.map((e) => e.toJson()).toList()));
    await prefs.setString('monenta_tags', json.encode(myTags));
    await prefs.setString('monenta_tasks', json.encode(_tasks.map((e) => e.toJson()).toList()));
    await prefs.setString('monenta_focus_records', json.encode(focusRecords.map((e) => e.toJson()).toList()));
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    saveData();
  }

  void updateDefaultFocusSettings({
    String? mode,
    int? countdownMins,
    int? prepMins,
    bool? allowPause,
    int? pauseLimitMins,
  }) {
    if (mode != null) defaultTimerMode = mode;
    if (countdownMins != null) defaultCountdownMinutes = countdownMins;
    if (prepMins != null) defaultPrepMinutes = prepMins;
    if (allowPause != null) defaultAllowPause = allowPause;
    if (pauseLimitMins != null) defaultPauseLimitMinutes = pauseLimitMins;
    notifyListeners();
  }

  TaskChain? getChain(String? id) {
    if (id == null) return null;
    try {
      return myChains.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  TaskChain addChain(String name) {
    final existing = myChains.where((c) => c.name == name.trim()).toList();
    if (existing.isNotEmpty) return existing.first;
    final newChain = TaskChain(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      count: 1,
    );
    myChains.add(newChain);
    notifyListeners();
    return newChain;
  }

  void editChain(String id, String newName) {
    if (newName.trim().isEmpty) return;
    final index = myChains.indexWhere((c) => c.id == id);
    if (index != -1) {
      myChains[index].name = newName.trim();
      notifyListeners();
    }
  }

  void deleteChain(String id) {
    myChains.removeWhere((c) => c.id == id);
    for (final t in _tasks) {
      if (t.chainId == id) {
        t.chainId = null;
        t.chainNumber = null;
      }
    }
    notifyListeners();
  }

  void addFocusRecord(int seconds, {String? taskId}) {
    if (seconds <= 0) return;
    String? listName;
    if (taskId != null) {
      final idx = _tasks.indexWhere((t) => t.id == taskId);
      if (idx != -1) {
        listName = _tasks[idx].listName;
        _tasks[idx].focusDurationSeconds += seconds;
      }
    }

    focusRecords.add(FocusRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      seconds: seconds,
      listName: listName,
      taskId: taskId,
    ));
    notifyListeners();
  }

  Future<void> toggleTimeBuckets(bool enable) async {
    if (enableTimeBuckets == enable) return;
    enableTimeBuckets = enable;
    notifyListeners();
  }

  void addTimeBucket(String name) {
    if (name.trim().isEmpty || timeBuckets.contains(name.trim())) return;
    timeBuckets.add(name.trim());
    notifyListeners();
  }

  void editTimeBucket(String oldName, String newName) {
    if (newName.trim().isEmpty) return;
    final index = timeBuckets.indexOf(oldName);
    if (index != -1) {
      timeBuckets[index] = newName.trim();
      for (final t in _tasks) {
        if (t.timeBucket == oldName) {
          t.timeBucket = newName.trim();
        }
      }
      notifyListeners();
    }
  }

  void deleteTimeBucket(String name) {
    timeBuckets.remove(name);
    for (final t in _tasks) {
      if (t.timeBucket == name) {
        t.timeBucket = null;
      }
    }
    notifyListeners();
  }

  void reorderTimeBuckets(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = timeBuckets.removeAt(oldIndex);
    timeBuckets.insert(newIndex, item);
    notifyListeners();
  }

  void updateTaskBucket(String taskId, String? bucket) {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) return;
    final task = _tasks[taskIndex];
    if (task.isReadOnly) return;
    task.timeBucket = bucket;
    notifyListeners();
  }

  Future<void> toggleHolidays(bool enable) async {
    if (enableHolidays == enable) return;
    enableHolidays = enable;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('monenta_enable_holidays', enableHolidays);

    if (enableHolidays) {
      await _syncHolidays(notify: true);
    } else {
      _removeHolidaysFromTasks(notify: true);
    }
  }

  Future<void> _syncHolidays({bool notify = true}) async {
    final currentYear = DateTime.now().year;
    final years = [currentYear - 1, currentYear, currentYear + 1];

    bool changed = false;
    for (final year in years) {
      final holidays = await HolidayService.fetchHolidaysForYear(year);
      final existingIds = _tasks.where((t) => t.id.startsWith('holiday_')).map((t) => t.id).toSet();

      for (final h in holidays) {
        if (!existingIds.contains(h.id)) {
          _tasks.add(h);
          changed = true;
        }
      }
    }

    if (changed || notify) {
      notifyListeners();
    }
  }

  Future<void> ensureHolidaysForYear(int year) async {
    if (!enableHolidays) return;
    final holidays = await HolidayService.fetchHolidaysForYear(year);
    final existingIds = _tasks.where((t) => t.id.startsWith('holiday_')).map((t) => t.id).toSet();

    bool changed = false;
    for (final h in holidays) {
      if (!existingIds.contains(h.id)) {
        _tasks.add(h);
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _removeHolidaysFromTasks({bool notify = true}) {
    _tasks.removeWhere((t) => t.id.startsWith('holiday_') || t.isReadOnly);
    if (notify) notifyListeners();
  }

  void setHomeMode(String mode, {String? param}) {
    currentHomeMode = mode;
    currentHomeParam = param;
    notifyListeners();
  }

  void setFocusTask(Task? task) {
    currentFocusTask = task;
    notifyListeners();
  }

  List<Task> get allTasks => _tasks.toList();

  List<Task> get unfinishedTasks => _tasks.where((t) => !t.isDone && !t.isEvent).toList();

  void addList(String name, Color color) {
    if (!myLists.any((l) => l.name == name)) {
      myLists.add(TaskList(name: name, color: color));
      notifyListeners();
    }
  }

  void addTag(String name) {
    if (!myTags.contains(name)) {
      myTags.add(name);
      notifyListeners();
    }
  }

  void editList(String oldName, String newName, Color newColor) {
    final index = myLists.indexWhere((l) => l.name == oldName);
    if (index != -1) {
      myLists[index].name = newName;
      myLists[index].color = newColor;

      for (final t in _tasks) {
        if (t.listName == oldName) {
          t.listName = newName;
        }
      }

      if (currentHomeMode == 'list' && currentHomeParam == oldName) {
        currentHomeParam = newName;
      }
      notifyListeners();
    }
  }

  void deleteList(String name) {
    myLists.removeWhere((l) => l.name == name);
    for (final t in _tasks) {
      if (t.listName == name) {
        t.listName = null;
      }
    }
    if (currentHomeMode == 'list' && currentHomeParam == name) {
      setHomeMode('todo');
    }
    notifyListeners();
  }

  void editTag(String oldName, String newName) {
    final index = myTags.indexOf(oldName);
    if (index != -1) {
      myTags[index] = newName;
      for (final t in _tasks) {
        if (t.tags.contains(oldName)) {
          t.tags.remove(oldName);
          if (!t.tags.contains(newName)) {
            t.tags.add(newName);
          }
        }
      }
      if (currentHomeMode == 'tag' && currentHomeParam == oldName) {
        currentHomeParam = newName;
      }
      notifyListeners();
    }
  }

  void deleteTag(String name) {
    myTags.remove(name);
    for (final t in _tasks) {
      t.tags.remove(name);
    }
    if (currentHomeMode == 'tag' && currentHomeParam == name) {
      setHomeMode('todo');
    }
    notifyListeners();
  }

  Color getListColor(String listName) {
    final list = myLists.where((l) => l.name == listName).toList();
    return list.isNotEmpty ? list.first.color : Colors.grey;
  }

  List<Task> getTasksByDate(DateTime date) {
    return _tasks.where((t) =>
        t.date != null &&
        t.date!.year == date.year &&
        t.date!.month == date.month &&
        t.date!.day == date.day).toList();
  }

  List<Task> get inboxTasks => _tasks.where((t) => t.date == null).toList();

  void addTask(Task baseTask, {RepeatConfig? repeat}) {
    if (repeat == null) {
      _tasks.add(baseTask);
    } else {
      DateTime startDate = baseTask.date ?? DateTime.now();
      String unitText = {
            'day': '天',
            'week': '周',
            'month': '月',
            'year': '年',
          }[repeat.unit] ??
          '天';

      baseTask.repeatGroupId = repeat.groupId;
      baseTask.repeatRuleText = '每 ${repeat.interval} $unitText';

      DateTime startDay = DateTime(startDate.year, startDate.month, startDate.day);
      DateTime? pureEndDay;
      if (repeat.endDate != null) {
        pureEndDay = DateTime(repeat.endDate!.year, repeat.endDate!.month, repeat.endDate!.day);
      }

      int count = 0;
      int maxLimit = pureEndDay != null ? 10000 : 1000;

      while (count < maxLimit) {
        DateTime targetDay;
        if (repeat.unit == 'day') {
          targetDay = DateTime(startDay.year, startDay.month, startDay.day + count * repeat.interval);
        } else if (repeat.unit == 'week') {
          targetDay = DateTime(startDay.year, startDay.month, startDay.day + count * 7 * repeat.interval);
        } else if (repeat.unit == 'month') {
          targetDay = DateTime(startDay.year, startDay.month + count * repeat.interval, startDay.day);
        } else if (repeat.unit == 'year') {
          targetDay = DateTime(startDay.year + count * repeat.interval, startDay.month, startDay.day);
        } else {
          targetDay = DateTime(startDay.year, startDay.month, startDay.day + count);
        }

        DateTime pureTargetDay = DateTime(targetDay.year, targetDay.month, targetDay.day);
        if (pureEndDay != null && pureTargetDay.isAfter(pureEndDay)) break;

        DateTime finalDateTime = DateTime(
          targetDay.year,
          targetDay.month,
          targetDay.day,
          startDate.hour,
          startDate.minute,
        );

        final newTask = baseTask.copyWith(
          id: DateTime.now().microsecondsSinceEpoch.toString() + count.toString(),
          date: finalDateTime,
        );

        _tasks.add(newTask);
        count++;
      }
    }
    notifyListeners();
  }

  bool _checkIsOverdue(Task task, DateTime? newDate) {
    if (task.isEvent || task.isDone || task.isReadOnly || task.date == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final oldDay = DateTime(task.date!.year, task.date!.month, task.date!.day);

    if (newDate == null) return true;
    final targetDay = DateTime(newDate.year, newDate.month, newDate.day);
    if (oldDay.isAtSameMomentAs(today) && targetDay.isAfter(today)) return true;
    if (oldDay.isBefore(today) && !targetDay.isBefore(today)) return true;

    return false;
  }

  void updateTaskDate(String id, DateTime? newDate, {bool skipOverdueCount = false}) {
    final taskIndex = _tasks.indexWhere((t) => t.id == id);
    if (taskIndex == -1) return;
    final task = _tasks[taskIndex];
    if (task.isReadOnly) return;

    if (!skipOverdueCount && _checkIsOverdue(task, newDate)) {
      task.overdueCount += 1;
    }

    task.date = newDate;
    notifyListeners();
  }

  void editTaskFull(
    String id,
    String newTitle,
    String newDesc,
    DateTime? newDate,
    TimeOfDay? newTime,
    bool newAddToCalendar,
    String? newList,
    List<String> newTags, {
    bool updateFuture = false,
    bool? newIsEvent,
    bool skipOverdueCount = false,
    String? newTimeBucket,
    bool clearTimeBucket = false,
    String? newChainId,
    bool clearChainId = false,
    String? newTimerMode,
    int? newCountdownMinutes,
    int? newPrepMinutes,
    bool? newAllowPause,
    int? newPauseLimitMinutes,
  }) {
    final taskIndex = _tasks.indexWhere((t) => t.id == id);
    if (taskIndex == -1) return;
    final task = _tasks[taskIndex];
    if (task.isReadOnly) return;

    if (!skipOverdueCount && _checkIsOverdue(task, newDate)) {
      task.overdueCount += 1;
    }

    if (updateFuture && task.repeatGroupId != null) {
      final relatedTasks = _tasks.where(
        (t) => t.repeatGroupId == task.repeatGroupId && t.date != null && !t.date!.isBefore(task.date!),
      ).toList();

      for (final r in relatedTasks) {
        r.title = newTitle;
        r.description = newDesc;
        r.time = newTime;
        r.addToCalendar = newAddToCalendar;
        r.listName = newList;
        r.tags = List.from(newTags);
        if (clearTimeBucket) {
          r.timeBucket = null;
        } else if (newTimeBucket != null) {
          r.timeBucket = newTimeBucket;
        }

        if (clearChainId) {
          r.chainId = null;
          r.chainNumber = null;
        } else if (newChainId != null) {
          r.chainId = newChainId;
        }

        if (newTimerMode != null) r.timerMode = newTimerMode;
        if (newCountdownMinutes != null) r.countdownMinutes = newCountdownMinutes;
        if (newPrepMinutes != null) r.prepMinutes = newPrepMinutes;
        if (newAllowPause != null) r.allowPause = newAllowPause;
        if (newPauseLimitMinutes != null) r.pauseLimitMinutes = newPauseLimitMinutes;

        if (newIsEvent != null) {
          r.isEvent = newIsEvent;
          if (r.isEvent) {
            r.isDone = false;
            r.doneDate = null;
          }
        }
      }
    } else {
      if (task.repeatGroupId != null && !updateFuture) {
        task.repeatGroupId = null;
        task.repeatRuleText = null;
      }

      task.title = newTitle;
      task.description = newDesc;
      task.date = newDate;
      task.time = newTime;
      task.addToCalendar = newAddToCalendar;
      task.listName = newList;
      task.tags = List.from(newTags);
      if (clearTimeBucket) {
        task.timeBucket = null;
      } else if (newTimeBucket != null) {
        task.timeBucket = newTimeBucket;
      }

      if (clearChainId) {
        task.chainId = null;
        task.chainNumber = null;
      } else if (newChainId != null) {
        task.chainId = newChainId;
      }

      if (newTimerMode != null) task.timerMode = newTimerMode;
      if (newCountdownMinutes != null) task.countdownMinutes = newCountdownMinutes;
      if (newPrepMinutes != null) task.prepMinutes = newPrepMinutes;
      if (newAllowPause != null) task.allowPause = newAllowPause;
      if (newPauseLimitMinutes != null) task.pauseLimitMinutes = newPauseLimitMinutes;

      if (newIsEvent != null) {
        task.isEvent = newIsEvent;
        if (task.isEvent) {
          task.isDone = false;
          task.doneDate = null;
        }
      }
    }
    notifyListeners();
  }

  void deleteTask(String id, {bool deleteAllFuture = false}) {
    final taskIndex = _tasks.indexWhere((t) => t.id == id);
    if (taskIndex == -1) return;
    final task = _tasks[taskIndex];
    if (task.isReadOnly) return;

    if (deleteAllFuture && task.repeatGroupId != null) {
      _tasks.removeWhere(
        (t) => t.repeatGroupId == task.repeatGroupId && t.date != null && !t.date!.isBefore(task.date!),
      );
    } else {
      _tasks.remove(task);
    }
    notifyListeners();
  }

  void pinTaskGlobally(Task task, bool toTop, {bool pinAllFuture = false}) {
    if (task.isReadOnly) return;

    if (pinAllFuture && task.repeatGroupId != null) {
      final related = _tasks.where(
        (t) => t.repeatGroupId == task.repeatGroupId && t.date != null && !t.date!.isBefore(task.date!),
      ).toList();

      for (final r in related) {
        _moveTaskToEdge(r, toTop);
      }
    } else {
      _moveTaskToEdge(task, toTop);
    }
    notifyListeners();
  }

  void _moveTaskToEdge(Task task, bool toTop) {
    _tasks.remove(task);

    if (toTop) {
      int firstIdx = _tasks.indexWhere(
        (t) => t.date?.year == task.date?.year && t.date?.month == task.date?.month && t.date?.day == task.date?.day,
      );
      if (firstIdx != -1) {
        _tasks.insert(firstIdx, task);
      } else {
        _tasks.add(task);
      }
    } else {
      int lastIdx = _tasks.lastIndexWhere(
        (t) => t.date?.year == task.date?.year && t.date?.month == task.date?.month && t.date?.day == task.date?.day,
      );
      if (lastIdx != -1) {
        _tasks.insert(lastIdx + 1, task);
      } else {
        _tasks.add(task);
      }
    }
  }

  void toggleTaskDone(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    if (task.isEvent || task.isReadOnly) return;

    task.isFailed = false;
    task.isDone = !task.isDone;

    if (task.isDone) {
      task.doneDate = DateTime.now();
      if (currentFocusTask?.id == id) {
        currentFocusTask = null;
      }

      if (task.chainId != null) {
        final chain = getChain(task.chainId);
        if (chain != null) {
          task.chainNumber = chain.count;
          chain.count += 1;
        }
      }
    } else {
      task.doneDate = null;
      if (task.chainId != null) {
        final chain = getChain(task.chainId);
        if (chain != null && task.chainNumber != null) {
          if (chain.count > 1 && task.chainNumber == chain.count - 1) {
            chain.count -= 1;
          }
        }
        task.chainNumber = null;
      }
    }
    notifyListeners();
  }

  void markTaskIncomplete(String id, String remark) {
    final task = _tasks.firstWhere((t) => t.id == id);
    if (task.isEvent || task.isReadOnly) return;

    task.isDone = false;
    task.doneDate = null;
    task.isFailed = true;
    task.failRemark = remark;
    task.chainNumber = null;

    if (task.chainId != null) {
      final chain = getChain(task.chainId);
      if (chain != null) {
        chain.count = 1;
      }
    }
    notifyListeners();
  }

  void clearTaskFailure(String id) {
    final task = _tasks.firstWhere((t) => t.id == id);
    task.isFailed = false;
    task.failRemark = null;
    notifyListeners();
  }

  void updateTaskList(String id, String? newList) {
    final task = _tasks.firstWhere((t) => t.id == id);
    if (task.isReadOnly) return;
    task.listName = newList;
    notifyListeners();
  }

  void reorderInboxTasks(int oldIndex, int newIndex) {
    final inboxList = inboxTasks;
    if (oldIndex < newIndex) newIndex -= 1;
    final task = inboxList[oldIndex];
    _tasks.remove(task);

    if (newIndex >= inboxList.length - 1) {
      _tasks.add(task);
    } else {
      _tasks.insert(_tasks.indexOf(inboxList[newIndex]), task);
    }
    notifyListeners();
  }

  void reorderDailyTasks(DateTime date, int oldIndex, int newIndex) {
    final dailyList = getTasksByDate(date);
    if (oldIndex < newIndex) newIndex -= 1;
    final task = dailyList[oldIndex];
    _tasks.remove(task);

    final updatedDailyList = getTasksByDate(date);
    if (newIndex >= updatedDailyList.length) {
      _tasks.add(task);
    } else {
      final targetTask = updatedDailyList[newIndex];
      final insertIndex = _tasks.indexOf(targetTask);
      _tasks.insert(insertIndex, task);
    }
    notifyListeners();
  }

  void reorderBucketTasks(DateTime date, Task movedTask, String? targetBucket, Task? anchorTask, bool insertAfter) {
    if (movedTask.isReadOnly) return;
    movedTask.timeBucket = targetBucket;
    _tasks.remove(movedTask);

    if (anchorTask != null) {
      int anchorIndex = _tasks.indexOf(anchorTask);
      if (anchorIndex != -1) {
        _tasks.insert(insertAfter ? anchorIndex + 1 : anchorIndex, movedTask);
      } else {
        _tasks.add(movedTask);
      }
    } else {
      int lastDayIdx = _tasks.lastIndexWhere((t) =>
          t.date != null && t.date!.year == date.year && t.date!.month == date.month && t.date!.day == date.day);
      if (lastDayIdx != -1) {
        _tasks.insert(lastDayIdx + 1, movedTask);
      } else {
        _tasks.add(movedTask);
      }
    }
    notifyListeners();
  }

  void moveTaskGlobally(Task task, DateTime? newDate, Task? anchorTask, bool insertAfter) {
    if (task.isReadOnly) return;

    if (_checkIsOverdue(task, newDate)) {
      task.overdueCount += 1;
    }

    task.date = newDate;
    _tasks.remove(task);

    if (anchorTask != null) {
      int index = _tasks.indexOf(anchorTask);
      if (index != -1) {
        _tasks.insert(insertAfter ? index + 1 : index, task);
      } else {
        _tasks.add(task);
      }
    } else {
      _tasks.add(task);
    }
    notifyListeners();
  }
}

final taskData = TaskData();