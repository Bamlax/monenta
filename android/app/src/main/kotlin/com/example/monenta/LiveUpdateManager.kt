package com.example.monenta // 请确认与你的实际包名一致

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat

object LiveUpdateManager {
    const val NOTIFICATION_ID = 2026
    const val CHANNEL_ID = "monenta_live_updates_v5" // 全新渠道 ID，避免旧配置干扰
    const val CHANNEL_NAME = "Monenta 实时活动"

    const val ACTION_RESERVATION_EXPIRED = "com.example.monenta.ACTION_RESERVATION_EXPIRED"
    const val ACTION_TASK_OVERTIME = "com.example.monenta.ACTION_TASK_OVERTIME"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "展示专注倒计时与状态栏胶囊实时活动"
                setShowBadge(true)
                setSound(null, null)
                enableVibration(false)
            }
            manager.createNotificationChannel(channel)
        }
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
        ensureChannel(context)

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

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
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH) // 统一采用 STOPWATCH 以激活系统级流体云胶囊

        pendingIntent?.let { builder.setContentIntent(it) }

        // 绑定系统原生 Chronometer
        if (useChronometer) {
            builder.setUsesChronometer(true)
            builder.setChronometerCountDown(isCountdown)
            builder.setWhen(whenTime)
            builder.setShowWhen(true)
        } else {
            builder.setUsesChronometer(false)
            builder.setShowWhen(false)
        }

        val extras = Bundle().apply {
            putBoolean("android.requestPromotedOngoing", true)
            // 关键：当 shortText 为 null 时，系统胶囊原生呈现 Chronometer 倒计时；非空时才覆盖为指定文本（如“计时中”）
            if (!shortText.isNullOrEmpty()) {
                putCharSequence("android.shortCriticalText", shortText)
            }
        }
        builder.addExtras(extras)

        try {
            val reqMethod = builder.javaClass.getMethod("setRequestPromotedOngoing", Boolean::class.javaPrimitiveType)
            reqMethod.invoke(builder, true)
        } catch (_: Exception) {}

        if (!shortText.isNullOrEmpty()) {
            try {
                val shortMethod = builder.javaClass.getMethod("setShortCriticalText", CharSequence::class.java)
                shortMethod.invoke(builder, shortText)
            } catch (_: Exception) {}
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, builder.build())
    }

    fun cancelNotification(context: Context) {
        cancelAlarms(context)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
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