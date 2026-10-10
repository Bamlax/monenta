import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../models/task_data.dart';

enum FocusPhase {
  idle,
  prep,
  formal,
  overtime,
}

enum FocusTimerMode {
  countdown,
  countup,
}

enum FocusTimerStatus {
  idle,
  running,
  paused,
}

class FocusTimerService extends ChangeNotifier {
  static final FocusTimerService instance = FocusTimerService._internal();
  FocusTimerService._internal();

  FocusPhase _phase = FocusPhase.idle;
  FocusTimerMode _mode = FocusTimerMode.countdown;
  FocusTimerStatus _status = FocusTimerStatus.idle;

  String? _taskId;
  String _taskTitle = '';

  int _prepSeconds = 0;
  int _formalSeconds = 25 * 60;
  int _targetMinutes = 25;
  int _overtimeSeconds = 0;
  int _totalFocusedSeconds = 0;

  bool _allowPause = false;
  int _pauseLimitMinutes = 5;
  int _pauseRemainingSeconds = 5 * 60; // 暂停可用剩余秒数

  Timer? _ticker;
  DateTime? _lastTimestamp;
  bool _initialized = false;

  FocusPhase get phase => _phase;
  FocusTimerMode get mode => _mode;
  FocusTimerStatus get status => _status;
  bool get isRunning => _status == FocusTimerStatus.running;
  bool get isPaused => _status == FocusTimerStatus.paused;
  bool get isIdle => _status == FocusTimerStatus.idle;

  String? get taskId => _taskId;
  String get taskTitle => _taskTitle;
  int get targetMinutes => _targetMinutes;
  int get overtimeSeconds => _overtimeSeconds;
  int get formalSeconds => _formalSeconds;
  int get prepSeconds => _prepSeconds;
  bool get allowPause => _allowPause;
  int get pauseLimitMinutes => _pauseLimitMinutes;
  int get pauseRemainingSeconds => _pauseRemainingSeconds;

  int get displaySeconds {
    switch (_phase) {
      case FocusPhase.prep:
        return _prepSeconds;
      case FocusPhase.overtime:
        return _overtimeSeconds;
      case FocusPhase.formal:
      case FocusPhase.idle:
        return _formalSeconds;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    notifyListeners();
  }

  // 必须绑定待办任务启动
  Future<void> startTaskTimer(Task task) async {
    _stopTicker();
    _taskId = task.id;
    _taskTitle = task.title;
    _mode = task.timerMode == 'countup' ? FocusTimerMode.countup : FocusTimerMode.countdown;
    _targetMinutes = task.countdownMinutes;
    _allowPause = task.allowPause;
    _pauseLimitMinutes = task.pauseLimitMinutes;
    _pauseRemainingSeconds = task.pauseLimitMinutes * 60;
    _overtimeSeconds = 0;
    _totalFocusedSeconds = 0;

    final prepMins = task.prepMinutes;
    if (prepMins > 0) {
      _phase = FocusPhase.prep;
      _prepSeconds = prepMins * 60;
      _formalSeconds = _mode == FocusTimerMode.countdown ? _targetMinutes * 60 : 0;
    } else {
      _phase = FocusPhase.formal;
      _prepSeconds = 0;
      _formalSeconds = _mode == FocusTimerMode.countdown ? _targetMinutes * 60 : 0;
    }

    _status = FocusTimerStatus.running;
    _lastTimestamp = DateTime.now();
    _startTicker();
    notifyListeners();

    await _startLiveActivity();
  }

  void start() {
    if (_taskId == null) return;
    if (isRunning) return;

    if (_phase == FocusPhase.idle) {
      _phase = FocusPhase.formal;
      _formalSeconds = _mode == FocusTimerMode.countdown ? _targetMinutes * 60 : 0;
    }
    _status = FocusTimerStatus.running;
    _lastTimestamp = DateTime.now();
    _startTicker();
    notifyListeners();
    _startLiveActivity();
  }

  // 预约阶段禁止暂停；非可暂停待办禁止暂停
  void pause() {
    if (!isRunning) return;
    if (_phase == FocusPhase.prep) return; // 预约开始之后不能暂停
    if (!_allowPause) return; // 不可暂停的待办只能一直计时

    _tick();
    _lastTimestamp = DateTime.now();
    _status = FocusTimerStatus.paused;
    notifyListeners();
    _updateLiveActivityNotification();
  }

  void stop() {
    _tick();
    _saveSession();
    _stopTicker();
    _lastTimestamp = null;
    _phase = FocusPhase.idle;
    _status = FocusTimerStatus.idle;
    _overtimeSeconds = 0;
    _prepSeconds = 0;
    _formalSeconds = _mode == FocusTimerMode.countdown ? _targetMinutes * 60 : 0;
    notifyListeners();
    FlutterForegroundTask.stopService();
  }

  void skipPrep() {
    if (_phase != FocusPhase.prep) return;
    _phase = FocusPhase.formal;
    _prepSeconds = 0;
    _formalSeconds = _mode == FocusTimerMode.countdown ? _targetMinutes * 60 : 0;
    _lastTimestamp = DateTime.now();
    notifyListeners();
    _updateLiveActivityNotification();
  }

  Future<void> completeTaskAndFinishFocus() async {
    _tick();
    _saveSession();

    if (_taskId != null) {
      final match = taskData.allTasks.where((t) => t.id == _taskId).toList();
      if (match.isNotEmpty && !match.first.isDone) {
        taskData.toggleTaskDone(_taskId!);
      }
    }

    _stopTicker();
    _lastTimestamp = null;
    _phase = FocusPhase.idle;
    _status = FocusTimerStatus.idle;
    _taskId = null;
    _taskTitle = '';
    _overtimeSeconds = 0;
    _prepSeconds = 0;
    _formalSeconds = _mode == FocusTimerMode.countdown ? _targetMinutes * 60 : 0;
    notifyListeners();
    FlutterForegroundTask.stopService();
  }

  void _saveSession() {
    if (_totalFocusedSeconds > 0) {
      taskData.addFocusRecord(_totalFocusedSeconds, taskId: _taskId);
      _totalFocusedSeconds = 0;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (_lastTimestamp == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastTimestamp!).inSeconds;
    if (elapsed < 1) return;

    _lastTimestamp = _lastTimestamp!.add(Duration(seconds: elapsed));

    // 暂停状态下：倒计可用暂停剩余时间
    if (_status == FocusTimerStatus.paused) {
      if (_allowPause && _pauseRemainingSeconds > 0) {
        _pauseRemainingSeconds -= elapsed;
        if (_pauseRemainingSeconds < 0) _pauseRemainingSeconds = 0;
      }
      notifyListeners();
      _updateLiveActivityNotification();
      return;
    }

    if (_status != FocusTimerStatus.running) return;

    if (_phase == FocusPhase.prep) {
      _prepSeconds -= elapsed;
      if (_prepSeconds <= 0) {
        _phase = FocusPhase.formal;
        _prepSeconds = 0;
        _formalSeconds = _mode == FocusTimerMode.countdown ? _targetMinutes * 60 : 0;
      }
    } else if (_phase == FocusPhase.formal) {
      _totalFocusedSeconds += elapsed;
      if (_mode == FocusTimerMode.countdown) {
        _formalSeconds -= elapsed;
        if (_formalSeconds <= 0) {
          _phase = FocusPhase.overtime;
          _formalSeconds = 0;
          _overtimeSeconds = 0;
        }
      } else {
        _formalSeconds += elapsed;
      }
    } else if (_phase == FocusPhase.overtime) {
      _totalFocusedSeconds += elapsed;
      _overtimeSeconds += elapsed;
    }

    notifyListeners();
    _updateLiveActivityNotification();
  }

  // 申请实时活动通知权限并启动常驻通知
  Future<void> _startLiveActivity() async {
    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) return;

    String initialTitle = 'Monenta · 实时活动';
    String initialText = _phase == FocusPhase.prep
        ? '预约准备中: ${formatSeconds(_prepSeconds)} · $_taskTitle'
        : '${formatSeconds(displaySeconds)} · $_taskTitle';

    await FlutterForegroundTask.startService(
      serviceId: 1001,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: initialTitle,
      notificationText: initialText,
      notificationButtons: const [], // 纯净实时活动卡片，无常驻按钮
      notificationInitialRoute: '/',
      callback: startCallback,
    );
  }

  void _updateLiveActivityNotification() {
    FlutterForegroundTask.isRunningService.then((running) {
      if (!running) return;

      String title = 'Monenta · 实时活动';
      String text = '';

      if (_status == FocusTimerStatus.paused) {
        title = 'Monenta · 实时活动 (暂停中)';
        text = '剩余暂停时间: ${formatSeconds(_pauseRemainingSeconds)} · $_taskTitle';
      } else if (_phase == FocusPhase.prep) {
        text = '预约准备中: ${formatSeconds(_prepSeconds)} · $_taskTitle';
      } else if (_phase == FocusPhase.overtime) {
        text = '已超时: +${formatSeconds(_overtimeSeconds)} · $_taskTitle';
      } else {
        text = '专注中: ${formatSeconds(_formalSeconds)} · $_taskTitle';
      }

      FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    });
  }

  static String formatSeconds(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final h = safe ~/ 3600;
    final m = (safe % 3600) ~/ 60;
    final s = safe % 60;

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MonentaLiveActivityTaskHandler());
}

class MonentaLiveActivityTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  void onReceiveData(Object data) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}