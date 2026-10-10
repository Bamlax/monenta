import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/task_data.dart';
import 'live_update_channel.dart';

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
  int _pauseRemainingSeconds = 5 * 60;

  Timer? _ticker;
  DateTime? _lastTimestamp;

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
    notifyListeners();
  }

  // 同步原生流体云/实时活动：胶囊明确显示“预约中”、“计时中”、“暂停中”
  void _syncLiveUpdateToSystem() {
    if (_status == FocusTimerStatus.idle || _taskId == null) {
      LiveUpdateChannel.dismiss();
      return;
    }

    final nowEpoch = DateTime.now().millisecondsSinceEpoch;

    // 1. 暂停状态：胶囊显示“暂停中”，卡片保持倒计可用时间
    if (_status == FocusTimerStatus.paused) {
      final pauseDeadlineEpoch = nowEpoch + (_pauseRemainingSeconds * 1000);
      LiveUpdateChannel.show(
        title: _taskTitle,
        text: '暂停中 · 剩余可用暂停: ${formatSeconds(_pauseRemainingSeconds)}',
        shortText: '暂停中',
        whenTime: pauseDeadlineEpoch,
        useChronometer: true,
        isCountdown: true,
      );
      return;
    }

    // 2. 预约阶段：胶囊显示“预约中”，展开卡片保持预约倒计时走表
    if (_phase == FocusPhase.prep) {
      final deadlineEpoch = nowEpoch + (_prepSeconds * 1000);
      LiveUpdateChannel.show(
        title: _taskTitle,
        text: '预约准备中 · 倒计时结束后开启专注',
        shortText: '预约中',
        whenTime: deadlineEpoch,
        useChronometer: true,
        isCountdown: true,
        isReservation: true,
        durationSeconds: _mode == FocusTimerMode.countdown ? _targetMinutes * 60 : 0,
        isTaskCountdown: _mode == FocusTimerMode.countdown,
      );
      return;
    }

    // 3. 超时阶段：胶囊显示“计时中”
    if (_phase == FocusPhase.overtime) {
      final plannedEndEpoch = nowEpoch - (_overtimeSeconds * 1000);
      LiveUpdateChannel.show(
        title: '超时: $_taskTitle',
        text: '已超时 · 正在记录额外投入',
        shortText: '计时中',
        whenTime: plannedEndEpoch,
        useChronometer: true,
        isCountdown: false,
      );
      return;
    }

    // 4. 正式专注阶段（倒计时与正计时）：胶囊均显示“计时中”
    if (_mode == FocusTimerMode.countdown) {
      final deadlineEpoch = nowEpoch + (_formalSeconds * 1000);
      LiveUpdateChannel.show(
        title: _taskTitle,
        text: '正式专注倒计时中',
        shortText: '计时中',
        whenTime: deadlineEpoch,
        useChronometer: true,
        isCountdown: true,
      );
    } else {
      final startEpoch = nowEpoch - (_formalSeconds * 1000);
      LiveUpdateChannel.show(
        title: _taskTitle,
        text: '正计时专注中',
        shortText: '计时中',
        whenTime: startEpoch,
        useChronometer: true,
        isCountdown: false,
      );
    }
  }

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

    _syncLiveUpdateToSystem();
  }

  void start() {
    if (_taskId == null || isRunning) return;

    if (_phase == FocusPhase.idle) {
      _phase = FocusPhase.formal;
      _formalSeconds = _mode == FocusTimerMode.countdown ? _targetMinutes * 60 : 0;
    }
    _status = FocusTimerStatus.running;
    _lastTimestamp = DateTime.now();
    _startTicker();
    notifyListeners();

    _syncLiveUpdateToSystem();
  }

  void pause() {
    if (!isRunning || _phase == FocusPhase.prep || !_allowPause) return;

    _tick();
    _lastTimestamp = DateTime.now();
    _status = FocusTimerStatus.paused;
    notifyListeners();

    _syncLiveUpdateToSystem();
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

    LiveUpdateChannel.dismiss();
  }

  void skipPrep() {
    if (_phase != FocusPhase.prep) return;
    _phase = FocusPhase.formal;
    _prepSeconds = 0;
    _formalSeconds = _mode == FocusTimerMode.countdown ? _targetMinutes * 60 : 0;
    _lastTimestamp = DateTime.now();
    notifyListeners();

    _syncLiveUpdateToSystem();
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

    LiveUpdateChannel.dismiss();
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

    if (_status == FocusTimerStatus.paused) {
      if (_allowPause && _pauseRemainingSeconds > 0) {
        _pauseRemainingSeconds -= elapsed;
        if (_pauseRemainingSeconds < 0) _pauseRemainingSeconds = 0;
      }
      notifyListeners();
      return;
    }

    if (_status != FocusTimerStatus.running) return;

    if (_phase == FocusPhase.prep) {
      _prepSeconds -= elapsed;
      if (_prepSeconds <= 0) {
        // 预约归零，无缝切入正式专注，胶囊从“预约中”切换为“计时中”
        _phase = FocusPhase.formal;
        _prepSeconds = 0;
        _formalSeconds = _mode == FocusTimerMode.countdown ? _targetMinutes * 60 : 0;
        _syncLiveUpdateToSystem();
      }
    } else if (_phase == FocusPhase.formal) {
      _totalFocusedSeconds += elapsed;
      if (_mode == FocusTimerMode.countdown) {
        _formalSeconds -= elapsed;
        if (_formalSeconds <= 0) {
          _phase = FocusPhase.overtime;
          _formalSeconds = 0;
          _overtimeSeconds = 0;
          _syncLiveUpdateToSystem();
        }
      } else {
        _formalSeconds += elapsed;
      }
    } else if (_phase == FocusPhase.overtime) {
      _totalFocusedSeconds += elapsed;
      _overtimeSeconds += elapsed;
    }

    notifyListeners();
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