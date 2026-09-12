import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../models/task_data.dart';

enum FocusTimerMode { pomodoro, stopwatch }
enum FocusTimerStatus { idle, running, paused }

class FocusTimerState {
  final FocusTimerMode mode;
  final FocusTimerStatus status;
  final int pomodoroDuration;
  final int stopwatchInitialSeconds;
  final int seconds;
  final String? taskId;
  final String taskTitle;

  const FocusTimerState({
    required this.mode,
    required this.status,
    required this.pomodoroDuration,
    this.stopwatchInitialSeconds = 0,
    required this.seconds,
    this.taskId,
    this.taskTitle = '自由专注',
  });

  bool get isRunning => status == FocusTimerStatus.running;
  bool get isPaused => status == FocusTimerStatus.paused;
  bool get isIdle => status == FocusTimerStatus.idle;

  FocusTimerState copyWith({
    FocusTimerMode? mode,
    FocusTimerStatus? status,
    int? pomodoroDuration,
    int? stopwatchInitialSeconds,
    int? seconds,
    String? taskId,
    bool clearTaskId = false,
    String? taskTitle,
  }) {
    return FocusTimerState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      pomodoroDuration: pomodoroDuration ?? this.pomodoroDuration,
      stopwatchInitialSeconds: stopwatchInitialSeconds ?? this.stopwatchInitialSeconds,
      seconds: seconds ?? this.seconds,
      taskId: clearTaskId ? null : (taskId ?? this.taskId),
      taskTitle: taskTitle ?? this.taskTitle,
    );
  }
}

class FocusTimerService extends ChangeNotifier {
  static final FocusTimerService instance = FocusTimerService._internal();
  FocusTimerService._internal();

  FocusTimerState _state = const FocusTimerState(
    mode: FocusTimerMode.pomodoro,
    status: FocusTimerStatus.idle,
    pomodoroDuration: 25 * 60,
    stopwatchInitialSeconds: 0,
    seconds: 25 * 60,
    taskTitle: '自由专注',
  );

  Timer? _ticker;
  DateTime? _lastTimestamp;
  int _sessionAccumulatedSeconds = 0; // 本轮专注实际流逝的秒数
  bool _initialized = false;

  FocusTimerState get state => _state;
  bool get isRunning => _state.isRunning;
  bool get isPaused => _state.isPaused;
  bool get isPomodoro => _state.mode == FocusTimerMode.pomodoro;
  bool get isStopwatch => _state.mode == FocusTimerMode.stopwatch;
  int get seconds => _state.seconds;
  int get pomodoroMinutes => _state.pomodoroDuration ~/ 60;
  int get stopwatchMinutes => _state.seconds ~/ 60;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    FlutterForegroundTask.addTaskDataCallback(_onForegroundData);
    notifyListeners();
  }

  void _onForegroundData(Object data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      if (map['type'] == 'tick') {
        final secs = map['seconds'];
        if (secs is int && _state.isRunning) {
          _state = _state.copyWith(seconds: secs);
          notifyListeners();
        }
      } else if (map['type'] == 'finished') {
        _saveCurrentSession();
        _stopLocalTicker();
        _state = _state.copyWith(
          status: FocusTimerStatus.idle,
          seconds: isPomodoro ? _state.pomodoroDuration : _state.stopwatchInitialSeconds,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('解析前台服务数据错误: $e');
    }
  }

  void _saveCurrentSession() {
    if (_sessionAccumulatedSeconds > 0) {
      taskData.addFocusRecord(_sessionAccumulatedSeconds, taskId: _state.taskId);
      _sessionAccumulatedSeconds = 0;
    }
  }

  Future<void> setTask({String? taskId, required String title}) async {
    if (_state.isRunning) return;

    _state = _state.copyWith(
      taskId: taskId,
      clearTaskId: taskId == null,
      taskTitle: title,
    );
    notifyListeners();

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({
        'command': 'set_task',
        'taskId': taskId,
        'taskTitle': title,
      });
    }
  }

  Future<void> setMode(FocusTimerMode mode) async {
    if (_state.isRunning) return;

    _stopLocalTicker();
    _lastTimestamp = null;

    final secs = mode == FocusTimerMode.pomodoro
        ? _state.pomodoroDuration
        : _state.stopwatchInitialSeconds;

    _state = _state.copyWith(
      mode: mode,
      status: FocusTimerStatus.idle,
      seconds: secs,
    );
    notifyListeners();
  }

  Future<void> setPomodoroMinutes(int minutes) async {
    if (_state.isRunning) return;

    _stopLocalTicker();
    final duration = minutes * 60;
    _state = _state.copyWith(
      mode: FocusTimerMode.pomodoro,
      status: FocusTimerStatus.idle,
      pomodoroDuration: duration,
      seconds: duration,
    );
    notifyListeners();
  }

  Future<void> setStopwatchMinutes(int minutes) async {
    if (_state.isRunning) return;

    final duration = minutes * 60;
    _state = _state.copyWith(
      mode: FocusTimerMode.stopwatch,
      status: FocusTimerStatus.idle,
      stopwatchInitialSeconds: duration,
      seconds: duration,
    );
    notifyListeners();
  }

  Future<void> start() async {
    if (_state.isRunning) return;

    if (isPomodoro && _state.seconds <= 0) {
      _state = _state.copyWith(seconds: _state.pomodoroDuration);
    }

    _state = _state.copyWith(status: FocusTimerStatus.running);
    _lastTimestamp = DateTime.now();
    _startLocalTicker();
    notifyListeners();

    await _startForegroundService();

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({
        'command': 'start',
        'mode': isPomodoro ? 'pomodoro' : 'stopwatch',
        'seconds': _state.seconds,
        'pomodoroDuration': _state.pomodoroDuration,
        'taskId': _state.taskId,
        'taskTitle': _state.taskTitle,
      });
    }
  }

  Future<void> pause() async {
    if (!_state.isRunning) return;

    _tickNow();
    _stopLocalTicker();
    _lastTimestamp = null;

    _state = _state.copyWith(status: FocusTimerStatus.paused);
    notifyListeners();

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'command': 'pause'});
    }
  }

  Future<void> stop() async {
    _tickNow();
    _saveCurrentSession();
    _stopLocalTicker();
    _lastTimestamp = null;

    final resetSecs = isPomodoro ? _state.pomodoroDuration : _state.stopwatchInitialSeconds;
    _state = _state.copyWith(
      status: FocusTimerStatus.idle,
      seconds: resetSecs,
    );
    notifyListeners();

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'command': 'stop'});
    }
  }

  // 🔴 完成并自动结单
  Future<void> completeTaskAndFinishFocus() async {
    _tickNow();
    _saveCurrentSession();

    if (_state.taskId != null) {
      final task = taskData.allTasks.where((t) => t.id == _state.taskId).toList();
      if (task.isNotEmpty && !task.first.isDone) {
        taskData.toggleTaskDone(_state.taskId!);
      }
    }

    _stopLocalTicker();
    _lastTimestamp = null;
    final resetSecs = isPomodoro ? _state.pomodoroDuration : 0;
    _state = _state.copyWith(
      status: FocusTimerStatus.idle,
      seconds: resetSecs,
      taskId: null,
      clearTaskId: true,
      taskTitle: '自由专注',
    );
    notifyListeners();

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'command': 'stop'});
    }
  }

  void _startLocalTicker() {
    _ticker?.cancel();
    // 采用匀速 1 秒步进器，结合物理时间差严格校准，解决时间不均与跳秒
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tickNow());
  }

  void _stopLocalTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tickNow() {
    if (!_state.isRunning || _lastTimestamp == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastTimestamp!).inSeconds;
    if (elapsed < 1) return;

    _lastTimestamp = _lastTimestamp!.add(Duration(seconds: elapsed));
    _sessionAccumulatedSeconds += elapsed;

    if (isPomodoro) {
      final newSecs = _state.seconds - elapsed;
      if (newSecs <= 0) {
        _state = _state.copyWith(seconds: 0, status: FocusTimerStatus.idle);
        _saveCurrentSession();
        _stopLocalTicker();
        _lastTimestamp = null;
        notifyListeners();
        return;
      }
      _state = _state.copyWith(seconds: newSecs);
    } else {
      // 🔴 正计时匀速累加
      _state = _state.copyWith(seconds: _state.seconds + elapsed);
    }

    notifyListeners();
  }

  Future<void> _startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) return;

    await FlutterForegroundTask.startService(
      serviceId: 1001,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'Monenta · 正在专注',
      notificationText: '${formatSeconds(_state.seconds)} · ${_state.taskTitle}',
      notificationButtons: const [
        NotificationButton(id: 'pause', text: '暂停'),
        NotificationButton(id: 'stop', text: '停止'),
      ],
      notificationInitialRoute: '/',
      callback: startCallback,
    );
  }

  String get timeString => formatSeconds(_state.seconds);

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
    _stopLocalTicker();
    FlutterForegroundTask.removeTaskDataCallback(_onForegroundData);
    super.dispose();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MonentaFocusTaskHandler());
}

class MonentaFocusTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  void onReceiveData(Object data) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}