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

    if (widget.task != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _timerService.startTaskTimer(widget.task!);
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

  Future<void> _handleComplete() async {
    final taskName = _timerService.taskTitle;
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

  @override
  Widget build(BuildContext context) {
    final hasTask = _timerService.taskId != null;
    final taskTitle = hasTask ? _timerService.taskTitle : '';
    final timeStr = FocusTimerService.formatSeconds(_timerService.displaySeconds);

    final isPrep = _timerService.phase == FocusPhase.prep;
    final canPauseThisTask = hasTask && _timerService.allowPause && !isPrep;

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
          // 待办标题展示（无下拉图标、无提示小字）
          if (taskTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
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
          const SizedBox(height: 36),

          // 大字时钟
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 76,
              fontWeight: FontWeight.w200,
              color: _timerService.phase == FocusPhase.overtime
                  ? const Color(0xFF0284C7)
                  : (_timerService.phase == FocusPhase.prep ? Colors.lightBlue.shade700 : Colors.lightBlue),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),

          // 时间下方：跳过预约（仅保留按钮和“跳过预约”四个字）
          if (isPrep) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.lightBlue,
                side: const BorderSide(color: Colors.lightBlue, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              ),
              onPressed: _timerService.skipPrep,
              child: const Text(
                '跳过预约',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],

          // 暂停时显示剩余可用暂停时间
          if (_timerService.isPaused && _timerService.allowPause) ...[
            const SizedBox(height: 14),
            Text(
              '剩余可用暂停时间: ${FocusTimerService.formatSeconds(_timerService.pauseRemainingSeconds)}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.lightBlue.shade800),
            ),
          ],

          const SizedBox(height: 48),

          // 控制按钮栏
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 停止/重置按钮
              if (_timerService.isRunning || _timerService.isPaused || _timerService.displaySeconds > 0)
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.stop_circle_outlined, color: Colors.grey),
                  tooltip: '停止并重置',
                  onPressed: _timerService.stop,
                )
              else
                const SizedBox(width: 48),

              const SizedBox(width: 16),

              // 主操作按键
              if (_timerService.isRunning && !canPauseThisTask)
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_clock, size: 36, color: Colors.grey),
                )
              else
                GestureDetector(
                  onTap: () {
                    if (!hasTask) return;
                    if (_timerService.isRunning) {
                      _timerService.pause();
                    } else {
                      _timerService.start();
                    }
                  },
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.lightBlue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _timerService.isRunning ? Icons.pause : Icons.play_arrow,
                      size: 38,
                      color: Colors.lightBlue,
                    ),
                  ),
                ),

              const SizedBox(width: 16),

              // 完成按钮：暂停后才显示
              if (_timerService.isPaused)
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