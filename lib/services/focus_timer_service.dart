import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

enum FocusTimerMode { pomodoro, stopwatch }
enum FocusTimerStatus { idle, running, paused }

class FocusTimerState {
  final FocusTimerMode mode;
  final FocusTimerStatus status;
  final int pomodoroDuration;
  final int seconds;
  final String? taskId;
  final String taskTitle;

  const FocusTimerState({
    required this.mode,
    required this.status,
    required this.pomodoroDuration,
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
    int? seconds,
    String? taskId,
    bool clearTaskId = false,
    String? taskTitle,
  }) {
    return FocusTimerState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      pomodoroDuration: pomodoroDuration ?? this.pomodoroDuration,
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
    seconds: 25 * 60,
    taskTitle: '自由专注',
  );

  Timer? _timer;
  DateTime? _runStartedAt;
  bool _initialized = false;

  FocusTimerState get state => _state;
  bool get isRunning => _state.isRunning;
  bool get isPaused => _state.isPaused;
  bool get isPomodoro => _state.mode == FocusTimerMode.pomodoro;
  bool get isStopwatch => _state.mode == FocusTimerMode.stopwatch;
  int get seconds => _state.seconds;
  int get pomodoroMinutes => _state.pomodoroDuration ~/ 60;

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
      final type = map['type'];

      if (type == 'tick') {
        final seconds = map['seconds'];
        if (seconds is int) {
          _state = _state.copyWith(seconds: seconds);
          notifyListeners();
        }
      } else if (type == 'finished') {
        _stopLocalTimer();
        _runStartedAt = null;
        _state = _state.copyWith(
          status: FocusTimerStatus.idle,
          seconds: isPomodoro ? _state.pomodoroDuration : 0,
        );
        notifyListeners();
      } else if (type == 'service_error') {
        debugPrint('Foreground service error: ${map['message']}');
      }
    } catch (e) {
      debugPrint('Foreground data parse error: $e');
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

    _stopLocalTimer();
    _runStartedAt = null;

    final seconds = mode == FocusTimerMode.pomodoro
        ? _state.pomodoroDuration
        : 0;

    _state = _state.copyWith(
      mode: mode,
      status: FocusTimerStatus.idle,
      seconds: seconds,
    );
    notifyListeners();
  }

  Future<void> setPomodoroMinutes(int minutes) async {
    if (_state.isRunning) return;

    _stopLocalTimer();
    _runStartedAt = null;

    final duration = minutes * 60;
    _state = _state.copyWith(
      mode: FocusTimerMode.pomodoro,
      status: FocusTimerStatus.idle,
      pomodoroDuration: duration,
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
    _runStartedAt = DateTime.now();
    _startLocalTimer();
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

    _syncLocalTimer();
    _stopLocalTimer();
    _runStartedAt = null;

    _state = _state.copyWith(status: FocusTimerStatus.paused);
    notifyListeners();

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'command': 'pause'});
    }
  }

  Future<void> stop() async {
    _syncLocalTimer();
    _stopLocalTimer();
    _runStartedAt = null;

    final resetSeconds = isPomodoro ? _state.pomodoroDuration : 0;
    _state = _state.copyWith(
      status: FocusTimerStatus.idle,
      seconds: resetSeconds,
    );
    notifyListeners();

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'command': 'stop'});
    }
  }

  void _startLocalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) async => await _syncLocalTimer(),
    );
  }

  void _stopLocalTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _syncLocalTimer() async {
    if (!_state.isRunning || _runStartedAt == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_runStartedAt!).inSeconds;
    if (elapsed <= 0) return;

    _runStartedAt = now;

    if (isPomodoro) {
      final newSeconds = _state.seconds - elapsed;

      if (newSeconds <= 0) {
        _state = _state.copyWith(
          seconds: 0,
          status: FocusTimerStatus.idle,
        );
        _stopLocalTimer();
        _runStartedAt = null;
        notifyListeners();

        if (await FlutterForegroundTask.isRunningService) {
          FlutterForegroundTask.sendDataToTask({'command': 'finished'});
        }
        return;
      }

      _state = _state.copyWith(seconds: newSeconds);
    } else {
      _state = _state.copyWith(seconds: _state.seconds + elapsed);
    }

    notifyListeners();

    FlutterForegroundTask.isRunningService.then((running) {
      if (!running) return;

      FlutterForegroundTask.sendDataToTask({
        'command': 'state',
        'seconds': _state.seconds,
        'mode': isPomodoro ? 'pomodoro' : 'stopwatch',
        'taskTitle': _state.taskTitle,
      });
    });
  }

  Future<void> _startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) return;

    final result = await FlutterForegroundTask.startService(
      serviceId: 1001,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'Monenta · 正在专注',
      notificationText:
          '${formatSeconds(_state.seconds)} · ${_state.taskTitle}',
      notificationButtons: const [
        NotificationButton(id: 'pause', text: '暂停'),
        NotificationButton(id: 'stop', text: '停止'),
      ],
      notificationInitialRoute: '/',
      callback: startCallback,
    );

    if (result is! ServiceRequestSuccess) {
      debugPrint('Monenta 前台服务启动失败：$result');
    } else {
      debugPrint('Monenta 前台服务启动成功');
    }
  }

  String get timeString => formatSeconds(_state.seconds);

  static String formatSeconds(int totalSeconds) {
    final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = safeSeconds ~/ 60;
    final seconds = safeSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stopLocalTimer();
    FlutterForegroundTask.removeTaskDataCallback(_onForegroundData);
    super.dispose();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MonentaFocusTaskHandler());
}

class MonentaFocusTaskHandler extends TaskHandler {
  FocusTimerMode _mode = FocusTimerMode.pomodoro;
  FocusTimerStatus _status = FocusTimerStatus.idle;
  int _seconds = 25 * 60;
  int _pomodoroDuration = 25 * 60;
  String _taskTitle = '自由专注';
  DateTime? _lastTick;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _lastTick = timestamp;

    FlutterForegroundTask.updateService(
      notificationTitle: 'Monenta · 正在专注',
      notificationText:
          '${FocusTimerService.formatSeconds(_seconds)} · $_taskTitle',
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_status != FocusTimerStatus.running) return;

    final previous = _lastTick ?? timestamp;
    final elapsed = timestamp.difference(previous).inSeconds;
    if (elapsed <= 0) return;

    _lastTick = timestamp;

    if (_mode == FocusTimerMode.pomodoro) {
      _seconds -= elapsed;

      if (_seconds <= 0) {
        _seconds = 0;
        _status = FocusTimerStatus.idle;

        FlutterForegroundTask.updateService(
          notificationTitle: 'Monenta · 专注完成',
          notificationText: '番茄钟已完成 · $_taskTitle',
        );

        FlutterForegroundTask.sendDataToMain({'type': 'finished'});

        Future.delayed(const Duration(seconds: 1), () async {
          if (await FlutterForegroundTask.isRunningService) {
            await FlutterForegroundTask.stopService();
          }
        });
        return;
      }
    } else {
      _seconds += elapsed;
    }

    FlutterForegroundTask.updateService(
      notificationTitle: 'Monenta · 正在专注',
      notificationText:
          '${FocusTimerService.formatSeconds(_seconds)} · $_taskTitle',
    );

    FlutterForegroundTask.sendDataToMain({
      'type': 'tick',
      'seconds': _seconds,
    });
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;

    final command = data['command'];

    switch (command) {
      case 'start':
        _handleStart(data);
        break;
      case 'pause':
        _handlePause();
        break;
      case 'stop':
        _handleStop();
        break;
      case 'set_task':
        _handleSetTask(data);
        break;
      case 'state':
        _handleState(data);
        break;
      case 'finished':
        _status = FocusTimerStatus.idle;
        break;
    }
  }

  void _handleStart(Map data) {
    _mode = data['mode'] == 'stopwatch'
        ? FocusTimerMode.stopwatch
        : FocusTimerMode.pomodoro;

    _seconds = data['seconds'] ?? 0;
    _pomodoroDuration = data['pomodoroDuration'] ?? 25 * 60;
    _taskTitle = data['taskTitle'] ?? '自由专注';
    _status = FocusTimerStatus.running;
    _lastTick = DateTime.now();

    FlutterForegroundTask.updateService(
      notificationTitle: 'Monenta · 正在专注',
      notificationText:
          '${FocusTimerService.formatSeconds(_seconds)} · $_taskTitle',
    );
  }

  void _handlePause() {
    if (_status != FocusTimerStatus.running) return;

    if (_lastTick != null) {
      final elapsed = DateTime.now().difference(_lastTick!).inSeconds;

      if (elapsed > 0) {
        if (_mode == FocusTimerMode.pomodoro) {
          _seconds -= elapsed;
        } else {
          _seconds += elapsed;
        }
      }
    }

    if (_seconds < 0) _seconds = 0;

    _status = FocusTimerStatus.paused;
    _lastTick = null;

    FlutterForegroundTask.updateService(
      notificationTitle: 'Monenta · 专注已暂停',
      notificationText:
          '${FocusTimerService.formatSeconds(_seconds)} · $_taskTitle',
    );

    FlutterForegroundTask.sendDataToMain({
      'type': 'tick',
      'seconds': _seconds,
    });
  }

  Future<void> _handleStop() async {
    _status = FocusTimerStatus.idle;
    _seconds = _mode == FocusTimerMode.pomodoro
        ? _pomodoroDuration
        : 0;
    _lastTick = null;

    FlutterForegroundTask.sendDataToMain({
      'type': 'tick',
      'seconds': _seconds,
    });

    await FlutterForegroundTask.stopService();
  }

  void _handleSetTask(Map data) {
    _taskTitle = data['taskTitle'] ?? '自由专注';

    FlutterForegroundTask.updateService(
      notificationTitle:
          _status == FocusTimerStatus.running
              ? 'Monenta · 正在专注'
              : 'Monenta · 专注',
      notificationText:
          '${FocusTimerService.formatSeconds(_seconds)} · $_taskTitle',
    );
  }

  void _handleState(Map data) {
    final seconds = data['seconds'];
    if (seconds is int) _seconds = seconds;

    if (data['mode'] == 'stopwatch') {
      _mode = FocusTimerMode.stopwatch;
    } else if (data['mode'] == 'pomodoro') {
      _mode = FocusTimerMode.pomodoro;
    }

    if (data['taskTitle'] is String) {
      _taskTitle = data['taskTitle'];
    }

    FlutterForegroundTask.updateService(
      notificationTitle: 'Monenta · 正在专注',
      notificationText:
          '${FocusTimerService.formatSeconds(_seconds)} · $_taskTitle',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _lastTick = null;
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'pause') {
      _handlePause();
    } else if (id == 'stop') {
      _handleStop();
    }
  }
}