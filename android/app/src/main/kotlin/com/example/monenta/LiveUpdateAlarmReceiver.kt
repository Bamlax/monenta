package com.example.monenta

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class LiveUpdateAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            LiveUpdateManager.ACTION_RESERVATION_EXPIRED -> {
                LiveUpdateManager.stopNativeTicker()
                val taskTitle = intent.getStringExtra("taskTitle") ?: "待办任务"
                val deadlineEpoch = intent.getLongExtra("deadlineEpoch", System.currentTimeMillis())
                val durationSeconds = intent.getIntExtra("durationSeconds", 0)
                val isTaskCountdown = intent.getBooleanExtra("isTaskCountdown", true)

                val whenEpoch = if (isTaskCountdown) {
                    deadlineEpoch + (durationSeconds * 1000L)
                } else {
                    deadlineEpoch
                }

                LiveUpdateManager.postNotification(
                    context = context,
                    title = taskTitle,
                    text = if (isTaskCountdown) "正式专注倒计时中" else "正计时专注中",
                    shortText = "计时中",
                    whenTime = whenEpoch,
                    useChronometer = true,
                    isCountdown = isTaskCountdown,
                    category = "stopwatch"
                )

                if (isTaskCountdown && durationSeconds > 0) {
                    LiveUpdateManager.scheduleOvertimeAlarm(
                        context = context,
                        plannedEndEpoch = whenEpoch,
                        taskTitle = taskTitle
                    )
                }
            }
            LiveUpdateManager.ACTION_TASK_OVERTIME -> {
                LiveUpdateManager.stopNativeTicker()
                val taskTitle = intent.getStringExtra("taskTitle") ?: "待办任务"
                val plannedEndEpoch = intent.getLongExtra("plannedEndEpoch", System.currentTimeMillis())

                LiveUpdateManager.postNotification(
                    context = context,
                    title = "超时: $taskTitle",
                    text = "已超时 · 正在记录额外投入",
                    shortText = "计时中",
                    whenTime = plannedEndEpoch,
                    useChronometer = true,
                    isCountdown = false,
                    category = "stopwatch"
                )
            }
        }
    }
}