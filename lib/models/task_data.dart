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

  static RepeatConfig fromJson(Map<String, dynamic> json) =>
      RepeatConfig(
        groupId: json['groupId'],
        interval: json['interval'],
        unit: json['unit'],
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'])
            : null,
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

  static TaskList fromJson(Map<String, dynamic> json) =>
      TaskList(
        name: json['name'],
        color: Color(json['color']),
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

  // 逾期累计次数
  int overdueCount;

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
  });

  Task copyWith({
    String? id,
    DateTime? date,
    String? repeatGroupId,
    String? repeatRuleText,
    bool? isEvent,
    bool? isReadOnly,
    int? overdueCount,
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
      };

  static Task fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        description: json['description'] ?? '',
        date: json['date'] != null ? DateTime.parse(json['date']) : null,
        time: json['timeHour'] != null
            ? TimeOfDay(
                hour: json['timeHour'],
                minute: json['timeMinute'],
              )
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
      );
}

final ValueNotifier<int> appTabIndex = ValueNotifier<int>(0);

class TaskData extends ChangeNotifier {
  final List<Task> _tasks = [];
  final List<TaskList> myLists = [];
  final List<String> myTags = [];

  Task? currentFocusTask;
  String currentHomeMode = 'todo';
  String? currentHomeParam;

  bool enableHolidays = false;

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    enableHolidays = prefs.getBool('monenta_enable_holidays') ?? false;

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

    if (enableHolidays) {
      _syncHolidays(notify: false);
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('monenta_enable_holidays', enableHolidays);

    await prefs.setString(
      'monenta_lists',
      json.encode(myLists.map((e) => e.toJson()).toList()),
    );

    await prefs.setString(
      'monenta_tags',
      json.encode(myTags),
    );

    await prefs.setString(
      'monenta_tasks',
      json.encode(_tasks.map((e) => e.toJson()).toList()),
    );
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    saveData();
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
      final existingIds =
          _tasks.where((t) => t.id.startsWith('holiday_')).map((t) => t.id).toSet();

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
    final existingIds =
        _tasks.where((t) => t.id.startsWith('holiday_')).map((t) => t.id).toSet();

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

  List<Task> get unfinishedTasks =>
      _tasks.where((t) => !t.isDone && !t.isEvent).toList();

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
        pureEndDay = DateTime(
          repeat.endDate!.year,
          repeat.endDate!.month,
          repeat.endDate!.day,
        );
      }

      int count = 0;
      int maxLimit = pureEndDay != null ? 10000 : 1000;

      while (count < maxLimit) {
        DateTime targetDay;
        if (repeat.unit == 'day') {
          targetDay = DateTime(
            startDay.year,
            startDay.month,
            startDay.day + count * repeat.interval,
          );
        } else if (repeat.unit == 'week') {
          targetDay = DateTime(
            startDay.year,
            startDay.month,
            startDay.day + count * 7 * repeat.interval,
          );
        } else if (repeat.unit == 'month') {
          targetDay = DateTime(
            startDay.year,
            startDay.month + count * repeat.interval,
            startDay.day,
          );
        } else if (repeat.unit == 'year') {
          targetDay = DateTime(
            startDay.year + count * repeat.interval,
            startDay.month,
            startDay.day,
          );
        } else {
          targetDay = DateTime(startDay.year, startDay.month, startDay.day + count);
        }

        DateTime pureTargetDay = DateTime(targetDay.year, targetDay.month, targetDay.day);
        if (pureEndDay != null && pureTargetDay.isAfter(pureEndDay)) {
          break;
        }

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

  // 逾期判定辅助方法
  bool _checkIsOverdue(Task task, DateTime? newDate) {
    if (task.isEvent || task.isDone || task.isReadOnly || task.date == null || newDate == null) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final oldDay = DateTime(task.date!.year, task.date!.month, task.date!.day);
    final targetDay = DateTime(newDate.year, newDate.month, newDate.day);

    // 原日期早于今天，且新日期与原日期不同
    return oldDay.isBefore(today) && !targetDay.isAtSameMomentAs(oldDay);
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
        (t) =>
            t.repeatGroupId == task.repeatGroupId &&
            t.date != null &&
            !t.date!.isBefore(task.date!),
      ).toList();

      for (final r in relatedTasks) {
        r.title = newTitle;
        r.description = newDesc;
        r.time = newTime;
        r.addToCalendar = newAddToCalendar;
        r.listName = newList;
        r.tags = List.from(newTags);

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
        (t) =>
            t.repeatGroupId == task.repeatGroupId &&
            t.date != null &&
            !t.date!.isBefore(task.date!),
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
        (t) =>
            t.repeatGroupId == task.repeatGroupId &&
            t.date != null &&
            !t.date!.isBefore(task.date!),
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
        (t) =>
            t.date?.year == task.date?.year &&
            t.date?.month == task.date?.month &&
            t.date?.day == task.date?.day,
      );

      if (firstIdx != -1) {
        _tasks.insert(firstIdx, task);
      } else {
        _tasks.add(task);
      }
    } else {
      int lastIdx = _tasks.lastIndexWhere(
        (t) =>
            t.date?.year == task.date?.year &&
            t.date?.month == task.date?.month &&
            t.date?.day == task.date?.day,
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

    task.isDone = !task.isDone;
    if (task.isDone) {
      task.doneDate = DateTime.now();
      if (currentFocusTask?.id == id) {
        currentFocusTask = null;
      }
    } else {
      task.doneDate = null;
    }
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
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
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
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
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

  void moveTaskGlobally(Task task, DateTime? newDate, Task? anchorTask, bool insertAfter) {
    if (task.isReadOnly) return;

    // 拖拽至新日期时触发逾期判定
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