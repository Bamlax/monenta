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
  final FocusTimerService _timerService =
      FocusTimerService.instance;

  @override
  void initState() {
    super.initState();
    _timerService.addListener(_onTimerChanged);

    if (widget.task != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _timerService.setTask(
          taskId: widget.task!.id,
          title: widget.task!.title,
        );
      });
    }
  }

  @override
  void dispose() {
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

  Future<void> _toggleMode(bool pomodoro) async {
    if (isRunning) return;

    await _timerService.setMode(
      pomodoro
          ? FocusTimerMode.pomodoro
          : FocusTimerMode.stopwatch,
    );
  }

  Future<void> _startTimer() => _timerService.start();
  Future<void> _pauseTimer() => _timerService.pause();
  Future<void> _stopTimer() => _timerService.stop();

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '选择专注待办',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.lightBlue,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(
                            Icons.calendar_month,
                            size: 18,
                            color: Colors.lightBlue,
                          ),
                          label: Text(
                            '${filterDate.month}月${filterDate.day}日',
                            style: const TextStyle(
                              color: Colors.lightBlue,
                            ),
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: filterDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );

                            if (d != null) {
                              setSheetState(() {
                                filterDate = d;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.circle_outlined,
                      color: Colors.grey,
                    ),
                    title: const Text(
                      '自由专注（不绑定任务）',
                      style: TextStyle(color: Colors.grey),
                    ),
                    onTap: () async {
                      await _timerService.setTask(
                        taskId: null,
                        title: '自由专注',
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  Expanded(
                    child: tasks.isEmpty
                        ? const Center(
                            child: Text(
                              '这天没有未完成的待办~',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index];

                              return ListTile(
                                leading: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.lightBlue,
                                ),
                                title: Text(task.title),
                                onTap: () async {
                                  await _timerService.setTask(
                                    taskId: task.id,
                                    title: task.title,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
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

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '设置番茄钟时长',
            style: TextStyle(color: Colors.lightBlue),
          ),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [1, 5, 10, 15, 25, 30, 45, 60].map((minutes) {
              return ActionChip(
                label: Text('$minutes 分钟'),
                backgroundColor: pomodoroMinutes == minutes
                    ? Colors.lightBlue.shade100
                    : Colors.grey.shade100,
                side: BorderSide.none,
                onPressed: () async {
                  await _timerService.setPomodoroMinutes(minutes);

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String get timeString =>
      FocusTimerService.formatSeconds(seconds);

  @override
  Widget build(BuildContext context) {
    final taskTitle = timerState.taskTitle.isEmpty
        ? '自由专注'
        : timerState.taskTitle;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '专注',
          style: TextStyle(
            color: Colors.lightBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '点击切换待办任务',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _toggleMode(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isPomodoro
                        ? Colors.lightBlue
                        : Colors.grey.shade100,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    '番茄钟',
                    style: TextStyle(
                      color: isPomodoro
                          ? Colors.white
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _toggleMode(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: !isPomodoro
                        ? Colors.lightBlue
                        : Colors.grey.shade100,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(20),
                    ),
                  ),
                  child: Text(
                    '正计时',
                    style: TextStyle(
                      color: !isPomodoro
                          ? Colors.white
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPomodoro && !isRunning)
                const SizedBox(width: 48),
              GestureDetector(
                onTap: isPomodoro ? _showTimePicker : null,
                child: Text(
                  timeString,
                  style: const TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.w200,
                    color: Colors.lightBlue,
                    fontFeatures: [
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
              if (isPomodoro && !isRunning)
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.grey,
                    size: 24,
                  ),
                  onPressed: _showTimePicker,
                ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            isRunning
                ? '后台专注运行中'
                : isPaused
                    ? '专注已暂停'
                    : '准备开始专注',
            style: TextStyle(
              fontSize: 12,
              color: isPaused ? Colors.orange : Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isRunning || isPaused)
                IconButton(
                  iconSize: 36,
                  icon: const Icon(
                    Icons.stop_circle_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: _stopTimer,
                ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: isRunning ? _pauseTimer : _startTimer,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRunning ? Icons.pause : Icons.play_arrow,
                    size: 40,
                    color: Colors.lightBlue,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              if (isRunning || isPaused)
                const SizedBox(width: 52),
            ],
          ),
        ],
      ),
    );
  }
}