package com.example.monenta

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val LIVE_UPDATES_CHANNEL = "com.monenta.app/live_updates"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_UPDATES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showLiveUpdate" -> {
                        val title = call.argument<String>("title") ?: ""
                        val text = call.argument<String>("text") ?: ""
                        val shortText = call.argument<String>("shortText")
                        val whenTime = (call.argument<Number>("whenTime")?.toLong()) ?: 0L
                        val useChronometer = call.argument<Boolean>("useChronometer") ?: false
                        val isCountdown = call.argument<Boolean>("isCountdown") ?: false
                        val category = call.argument<String>("category") ?: "stopwatch"

                        val isReservation = call.argument<Boolean>("isReservation") ?: false
                        val tickInCapsule = call.argument<Boolean>("tickInCapsule") ?: false
                        val durationSeconds = call.argument<Int>("durationSeconds") ?: 0
                        val isTaskCountdown = call.argument<Boolean>("isTaskCountdown") ?: true

                        if (tickInCapsule && whenTime > System.currentTimeMillis()) {
                            // 预约与暂停阶段：由原生后台服务每秒实时刷新胶囊剩余时间
                            LiveUpdateManager.startCapsuleCountdown(
                                context = applicationContext,
                                title = title,
                                baseText = text,
                                deadlineEpoch = whenTime,
                                isReservation = isReservation,
                                durationSeconds = durationSeconds,
                                isTaskCountdown = isTaskCountdown
                            )
                        } else {
                            // 正式专注与超时阶段：停止秒级刷新器，胶囊显示“计时中”
                            LiveUpdateManager.stopNativeTicker()
                            LiveUpdateManager.cancelAlarms(applicationContext)
                            LiveUpdateManager.postNotification(
                                context = applicationContext,
                                title = title,
                                text = text,
                                shortText = shortText,
                                whenTime = whenTime,
                                useChronometer = useChronometer,
                                isCountdown = isCountdown,
                                category = category
                            )
                            if (isCountdown && whenTime > System.currentTimeMillis()) {
                                LiveUpdateManager.scheduleOvertimeAlarm(
                                    context = applicationContext,
                                    plannedEndEpoch = whenTime,
                                    taskTitle = title
                                )
                            }
                        }

                        result.success(true)
                    }
                    "dismissLiveUpdate" -> {
                        LiveUpdateManager.cancelNotification(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}