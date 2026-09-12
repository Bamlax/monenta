import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/task_data.dart';
import '../services/focus_timer_service.dart';

class FocusPage extends StatefulWidget {
  final Task? task;

  const FocusPage({super.key, this.task});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  final FocusTimerService _timerService = FocusTimerService.instance;

  @override
  void initState() {
    super.initState();
    _timerService.addListener(_onTimerChanged);
    taskData.addListener(_onTaskDataChanged);

    final initialTask = widget.task ?? taskData.currentFocusTask;
    if (initialTask != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _timerService.setTask(
          taskId: initialTask.id,
          title: initialTask.title,
        );
      });
    }
  }

  void _onTaskDataChanged() {
    final current = taskData.currentFocusTask;
    if (current != null && !_timerService.isRunning) {
      _timerService.setTask(taskId: current.id, title: current.title);
    }
  }

  @override
  void dispose() {
    taskData.removeListener(_onTaskDataChanged);
    _timerService.removeListener(_onTimerChanged);
    super.dispose();
  }

  void _onTimerChanged() {
    if (mounted) setState(() {});
  }

  FocusTimerState get timerState => _timerService.state;
  bool get isPomodoro => timerState.mode == FocusTimerMode.pomodoro;
  bool get isRunning => timerState.status == FocusTimerStatus.running;
  bool get isPaused => timerState.status == FocusTimerStatus.paused;
  int get seconds => timerState.seconds;
  int get pomodoroMinutes => timerState.pomodoroDuration ~/ 60;
  int get stopwatchMinutes => timerState.seconds ~/ 60;

  Future<void> _toggleMode(bool pomodoro) async {
    if (isRunning) return;
    await _timerService.setMode(
      pomodoro ? FocusTimerMode.pomodoro : FocusTimerMode.stopwatch,
    );
  }

  Future<void> _startTimer() => _timerService.start();
  Future<void> _pauseTimer() => _timerService.pause();
  Future<void> _stopTimer() => _timerService.stop();

  Future<void> _handleComplete() async {
    final taskName = timerState.taskTitle;
    await _timerService.completeTaskAndFinishFocus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已记录专注时长，并已完成任务：$taskName'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showTaskSelector() async {
    DateTime filterDate = DateTime.now();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final tasks = taskData
                .getTasksByDate(filterDate)
                .where((t) => !t.isDone && !t.isEvent)
                .toList();

            return FractionallySizedBox(
              heightFactor: 0.6,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '选择专注待办',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.lightBlue),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 18, color: Colors.lightBlue),
                          label: Text('${filterDate.month}月${filterDate.day}日', style: const TextStyle(color: Colors.lightBlue)),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: filterDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (d != null) {
                              setSheetState(() => filterDate = d);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.circle_outlined, color: Colors.grey),
                    title: const Text('自由专注（不绑定任务）', style: TextStyle(color: Colors.grey)),
                    onTap: () async {
                      await _timerService.setTask(taskId: null, title: '自由专注');
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  Expanded(
                    child: tasks.isEmpty
                        ? const Center(child: Text('这天没有未完成的待办~', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return ListTile(
                                leading: const Icon(Icons.check_circle_outline, color: Colors.lightBlue),
                                title: Text(task.title),
                                onTap: () async {
                                  await _timerService.setTask(taskId: task.id, title: task.title);
                                  if (context.mounted) Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showTimePicker() async {
    if (isRunning) return;

    final customCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isPomodoro ? '设置番茄钟时长' : '指定正计时时长',
            style: const TextStyle(color: Colors.lightBlue),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [5, 10, 15, 25, 30, 45, 60].map((minutes) {
                  final isSelected = isPomodoro
                      ? pomodoroMinutes == minutes
                      : stopwatchMinutes == minutes;

                  return ActionChip(
                    label: Text('$minutes 分钟'),
                    backgroundColor: isSelected ? Colors.lightBlue.shade100 : Colors.grey.shade100,
                    side: BorderSide.none,
                    onPressed: () async {
                      if (isPomodoro) {
                        await _timerService.setPomodoroMinutes(minutes);
                      } else {
                        await _timerService.setStopwatchMinutes(minutes);
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: customCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '自定义分钟数',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, elevation: 0),
                    onPressed: () async {
                      final val = int.tryParse(customCtrl.text.trim());
                      if (val != null && val >= 0) {
                        if (isPomodoro) {
                          await _timerService.setPomodoroMinutes(val);
                        } else {
                          await _timerService.setStopwatchMinutes(val);
                        }
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: const Text('确定', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String get timeString => FocusTimerService.formatSeconds(seconds);

  @override
  Widget build(BuildContext context) {
    final taskTitle = timerState.taskTitle.isEmpty ? '自由专注' : timerState.taskTitle;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('专注', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _showTaskSelector,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          taskTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text('点击切换待办任务', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _toggleMode(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPomodoro ? Colors.lightBlue : Colors.grey.shade100,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                  ),
                  child: Text(
                    '番茄钟',
                    style: TextStyle(
                      color: isPomodoro ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _toggleMode(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: !isPomodoro ? Colors.lightBlue : Colors.grey.shade100,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                  ),
                  child: Text(
                    '正计时',
                    style: TextStyle(
                      color: !isPomodoro ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isRunning) const SizedBox(width: 48),
              GestureDetector(
                onTap: !isRunning ? _showTimePicker : null,
                child: Text(
                  timeString,
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w200,
                    color: Colors.lightBlue,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (!isRunning)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey, size: 24),
                  onPressed: _showTimePicker,
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            isRunning ? '专注运行中' : (isPaused ? '专注已暂停' : '准备开始专注'),
            style: TextStyle(fontSize: 12, color: isPaused ? Colors.orange : Colors.grey),
          ),
          const SizedBox(height: 36),

          // 操作控制栏
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 停止/重置按钮
              if (isRunning || isPaused || seconds > 0)
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.stop_circle_outlined, color: Colors.grey),
                  tooltip: '停止并重置',
                  onPressed: _stopTimer,
                )
              else
                const SizedBox(width: 48),

              const SizedBox(width: 16),

              // 开始/暂停按钮
              GestureDetector(
                onTap: isRunning ? _pauseTimer : _startTimer,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRunning ? Icons.pause : Icons.play_arrow,
                    size: 38,
                    color: Colors.lightBlue,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // 🔴 完成按钮：仅在暂停状态 (isPaused) 下显示
              if (isPaused)
                IconButton(
                  iconSize: 34,
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: '完成并结单',
                  onPressed: _handleComplete,
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }
}