package com.example.monenta // 请确认包名与项目一致

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class LiveUpdateAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            LiveUpdateManager.ACTION_RESERVATION_EXPIRED -> {
                val taskTitle = intent.getStringExtra("taskTitle") ?: "待办任务"
                val deadlineEpoch = intent.getLongExtra("deadlineEpoch", System.currentTimeMillis())
                val durationSeconds = intent.getIntExtra("durationSeconds", 0)
                val isTaskCountdown = intent.getBooleanExtra("isTaskCountdown", true)

                val whenEpoch = if (isTaskCountdown) {
                    deadlineEpoch + (durationSeconds * 1000L)
                } else {
                    deadlineEpoch
                }

                // 预约到期后转入正式计时：胶囊显示“计时中”
                LiveUpdateManager.postNotification(
                    context = context,
                    title = taskTitle,
                    text = if (isTaskCountdown) "正式专注倒计时中" else "正计时进行中",
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
                val taskTitle = intent.getStringExtra("taskTitle") ?: "待办任务"
                val plannedEndEpoch = intent.getLongExtra("plannedEndEpoch", System.currentTimeMillis())

                // 超时后胶囊依然显示“计时中”
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