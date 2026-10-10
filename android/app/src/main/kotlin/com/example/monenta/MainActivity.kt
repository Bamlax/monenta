package com.example.monenta // 请确认包名

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
                        val durationSeconds = call.argument<Int>("durationSeconds") ?: 0
                        val isTaskCountdown = call.argument<Boolean>("isTaskCountdown") ?: true

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

                        if (isReservation && whenTime > System.currentTimeMillis()) {
                            LiveUpdateManager.scheduleReservationExpiredAlarm(
                                context = applicationContext,
                                deadlineEpoch = whenTime,
                                taskTitle = title,
                                durationSeconds = durationSeconds,
                                isTaskCountdown = isTaskCountdown
                            )
                        } else {
                            LiveUpdateManager.cancelAlarms(applicationContext)
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