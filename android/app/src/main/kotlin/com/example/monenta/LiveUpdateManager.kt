package com.example.monenta

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat

object LiveUpdateManager {
    const val NOTIFICATION_ID = 2026
    const val CHANNEL_ID = "monenta_live_updates_v7"
    const val CHANNEL_NAME = "Monenta 实时活动"

    const val ACTION_RESERVATION_EXPIRED = "com.example.monenta.ACTION_RESERVATION_EXPIRED"
    const val ACTION_TASK_OVERTIME = "com.example.monenta.ACTION_TASK_OVERTIME"

    private val mainHandler = Handler(Looper.getMainLooper())
    private var tickRunnable: Runnable? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private var channelCreated = false
    private var cachedPendingIntent: PendingIntent? = null
    private var lastPostedShortText: String? = null

    fun ensureChannel(context: Context) {
        if (channelCreated) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_DEFAULT // 使用 DEFAULT + 静音，避免高优先级横幅重绘闪烁
                ).apply {
                    description = "展示专注倒计时与状态栏胶囊实时活动"
                    setShowBadge(false)
                    setSound(null, null)
                    enableVibration(false)
                }
                manager.createNotificationChannel(channel)
            }
            channelCreated = true
        }
    }

    private fun getLaunchPendingIntent(context: Context): PendingIntent? {
        if (cachedPendingIntent == null) {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            if (launchIntent != null) {
                cachedPendingIntent = PendingIntent.getActivity(
                    context.applicationContext,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            }
        }
        return cachedPendingIntent
    }

    fun formatDuration(seconds: Long): String {
        val safe = if (seconds < 0) 0L else seconds
        val h = safe / 3600
        val m = (safe % 3600) / 60
        val s = safe % 60
        return if (h > 0) {
            String.format("%02d:%02d:%02d", h, m, s)
        } else {
            String.format("%02d:%02d", m, s)
        }
    }

    /**
     * 启动预约或暂停的原生秒级胶囊实时倒计时（仅轻量更新 notify，不重复启动服务）
     */
    fun startCapsuleCountdown(
        context: Context,
        title: String,
        baseText: String,
        deadlineEpoch: Long,
        isReservation: Boolean,
        durationSeconds: Int,
        isTaskCountdown: Boolean
    ) {
        val appCtx = context.applicationContext
        stopNativeTicker()
        acquireWakeLock(appCtx)
        lastPostedShortText = null

        if (isReservation && deadlineEpoch > System.currentTimeMillis()) {
            scheduleReservationExpiredAlarm(
                context = appCtx,
                deadlineEpoch = deadlineEpoch,
                taskTitle = title,
                durationSeconds = durationSeconds,
                isTaskCountdown = isTaskCountdown
            )
        } else {
            cancelAlarms(appCtx)
        }

        val runnable = object : Runnable {
            override fun run() {
                val now = System.currentTimeMillis()
                val diffMs = deadlineEpoch - now

                if (diffMs <= 0L) {
                    stopNativeTicker()
                    if (isReservation) {
                        val formalWhen = if (isTaskCountdown) {
                            deadlineEpoch + (durationSeconds * 1000L)
                        } else {
                            deadlineEpoch
                        }
                        postNotification(
                            context = appCtx,
                            title = title,
                            text = if (isTaskCountdown) "正式专注倒计时中" else "正计时专注中",
                            shortText = "计时中",
                            whenTime = formalWhen,
                            useChronometer = true,
                            isCountdown = isTaskCountdown,
                            category = "stopwatch"
                        )
                        if (isTaskCountdown && durationSeconds > 0) {
                            scheduleOvertimeAlarm(appCtx, formalWhen, title)
                        }
                    } else {
                        postNotification(
                            context = appCtx,
                            title = title,
                            text = "暂停时间已耗尽",
                            shortText = "00:00",
                            whenTime = 0L,
                            useChronometer = false,
                            isCountdown = false,
                            category = "stopwatch"
                        )
                    }
                    return
                }

                val remainSec = (diffMs + 999L) / 1000L
                val timeStr = formatDuration(remainSec)

                // 仅在秒数文本真正变化时更新，避免同一秒内重复刷新引起闪烁
                if (timeStr != lastPostedShortText) {
                    lastPostedShortText = timeStr

                    // 关键：每秒更新胶囊文字时，将 useChronometer 设为 false，防止系统每秒重置计时器视图导致全部数字闪烁
                    val notification = buildNotification(
                        context = appCtx,
                        title = title,
                        text = "$baseText · $timeStr",
                        shortText = timeStr,
                        whenTime = 0L,
                        useChronometer = false,
                        isCountdown = false,
                        category = "stopwatch"
                    )

                    ensureServiceStartedOnce(appCtx, notification)
                    val manager = appCtx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    manager.notify(NOTIFICATION_ID, notification)
                }

                // 对齐到下一个整秒边界触发，消除定时器漂移
                val nextDelay = (diffMs % 1000L).let { if (it <= 25L) it + 1000L else it }
                mainHandler.postDelayed(this, nextDelay)
            }
        }

        tickRunnable = runnable
        mainHandler.post(runnable)
    }

    fun stopNativeTicker() {
        tickRunnable?.let { mainHandler.removeCallbacks(it) }
        tickRunnable = null
        lastPostedShortText = null
        releaseWakeLock()
    }

    private fun ensureServiceStartedOnce(context: Context, notification: Notification) {
        LiveUpdateService.lastNotification = notification
        if (!LiveUpdateService.isRunning) {
            try {
                val serviceIntent = Intent(context, LiveUpdateService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } catch (_: Exception) {}
        }
    }

    private fun acquireWakeLock(context: Context) {
        try {
            if (wakeLock == null) {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Monenta:LiveUpdateTimerLock").apply {
                    setReferenceCounted(false)
                }
            }
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire(2 * 60 * 60 * 1000L)
            }
        } catch (_: Exception) {}
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
    }

    fun buildNotification(
        context: Context,
        title: String,
        text: String,
        shortText: String?,
        whenTime: Long,
        useChronometer: Boolean,
        isCountdown: Boolean,
        category: String = "stopwatch"
    ): Notification {
        ensureChannel(context)

        val pendingIntent = getLaunchPendingIntent(context)

        val bigTextStyle = NotificationCompat.BigTextStyle()
            .bigText(text)
            .setBigContentTitle(title)

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(bigTextStyle)
            .setOngoing(true)
            .setGroupSummary(false)
            .setColorized(false)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setCategory(
                if (category == "alarm") NotificationCompat.CATEGORY_ALARM
                else NotificationCompat.CATEGORY_STOPWATCH
            )

        pendingIntent?.let { builder.setContentIntent(it) }

        if (useChronometer && whenTime > 0L) {
            builder.setUsesChronometer(true)
            builder.setChronometerCountDown(isCountdown)
            builder.setWhen(whenTime)
            builder.setShowWhen(true)
        } else {
            builder.setUsesChronometer(false)
            builder.setShowWhen(false)
            builder.setWhen(0L) // 固定为 0，防止 Builder 默认注入当前时间戳触发状态栏重排
        }

        val extras = Bundle().apply {
            putBoolean("android.requestPromotedOngoing", true)
            if (!shortText.isNullOrEmpty()) {
                putCharSequence("android.shortCriticalText", shortText)
            }
        }
        builder.addExtras(extras)

        return builder.build()
    }

    fun postNotification(
        context: Context,
        title: String,
        text: String,
        shortText: String?,
        whenTime: Long,
        useChronometer: Boolean,
        isCountdown: Boolean,
        category: String = "stopwatch"
    ) {
        val appCtx = context.applicationContext
        val notification = buildNotification(
            context = appCtx,
            title = title,
            text = text,
            shortText = shortText,
            whenTime = whenTime,
            useChronometer = useChronometer,
            isCountdown = isCountdown,
            category = category
        )

        ensureServiceStartedOnce(appCtx, notification)

        val manager = appCtx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    fun cancelNotification(context: Context) {
        val appCtx = context.applicationContext
        stopNativeTicker()
        cancelAlarms(appCtx)
        try {
            appCtx.stopService(Intent(appCtx, LiveUpdateService::class.java))
        } catch (_: Exception) {}
        LiveUpdateService.isRunning = false
        val manager = appCtx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }

    fun scheduleReservationExpiredAlarm(
        context: Context,
        deadlineEpoch: Long,
        taskTitle: String,
        durationSeconds: Int,
        isTaskCountdown: Boolean
    ) {
        cancelAlarms(context)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, LiveUpdateAlarmReceiver::class.java).apply {
            action = ACTION_RESERVATION_EXPIRED
            putExtra("taskTitle", taskTitle)
            putExtra("deadlineEpoch", deadlineEpoch)
            putExtra("durationSeconds", durationSeconds)
            putExtra("isTaskCountdown", isTaskCountdown)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            201,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, deadlineEpoch, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, deadlineEpoch, pendingIntent)
        }
    }

    fun scheduleOvertimeAlarm(
        context: Context,
        plannedEndEpoch: Long,
        taskTitle: String
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, LiveUpdateAlarmReceiver::class.java).apply {
            action = ACTION_TASK_OVERTIME
            putExtra("taskTitle", taskTitle)
            putExtra("plannedEndEpoch", plannedEndEpoch)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            202,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, plannedEndEpoch, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, plannedEndEpoch, pendingIntent)
        }
    }

    fun cancelAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent1 = Intent(context, LiveUpdateAlarmReceiver::class.java).apply {
            action = ACTION_RESERVATION_EXPIRED
        }
        val p1 = PendingIntent.getBroadcast(context, 201, intent1, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        if (p1 != null) alarmManager.cancel(p1)

        val intent2 = Intent(context, LiveUpdateAlarmReceiver::class.java).apply {
            action = ACTION_TASK_OVERTIME
        }
        val p2 = PendingIntent.getBroadcast(context, 202, intent2, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        if (p2 != null) alarmManager.cancel(p2)
    }
}

class LiveUpdateService : Service() {
    companion object {
        var lastNotification: Notification? = null
        var isRunning: Boolean = false
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = lastNotification ?: LiveUpdateManager.buildNotification(
            context = applicationContext,
            title = "Monenta",
            text = "专注运行中",
            shortText = "计时中",
            whenTime = 0L,
            useChronometer = false,
            isCountdown = false
        )

        if (!isRunning) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        LiveUpdateManager.NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                    )
                } else {
                    startForeground(LiveUpdateManager.NOTIFICATION_ID, notification)
                }
                isRunning = true
            } catch (_: Exception) {}
        }

        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}