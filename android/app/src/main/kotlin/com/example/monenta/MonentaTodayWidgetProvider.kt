package com.example.monenta

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

object MonentaWidgetStore {
    private const val PREF_NAME = "monenta_widget_prefs"
    private const val KEY_PAYLOAD = "today_payload"

    fun savePayload(context: Context, payload: String) {
        context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PAYLOAD, payload)
            .apply()
    }

    fun getPayload(context: Context): String? {
        return context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            .getString(KEY_PAYLOAD, null)
    }

    fun getCurrentDateKey(): String {
        val cal = Calendar.getInstance()
        return "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.MONTH) + 1}-${cal.get(Calendar.DAY_OF_MONTH)}"
    }

    fun getCurrentDateTitle(): String {
        val cal = Calendar.getInstance()
        val weekNames = arrayOf("日", "一", "二", "三", "四", "五", "六")
        val weekStr = weekNames[cal.get(Calendar.DAY_OF_WEEK) - 1]
        return "${cal.get(Calendar.MONTH) + 1}月${cal.get(Calendar.DAY_OF_MONTH)}日 周$weekStr"
    }

    fun notifyWidgetUpdated(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, MonentaTodayWidgetProvider::class.java)
        val ids = appWidgetManager.getAppWidgetIds(component)
        if (ids.isEmpty()) return

        appWidgetManager.notifyAppWidgetViewDataChanged(ids, R.id.widget_task_list)
        val intent = Intent(context, MonentaTodayWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        context.sendBroadcast(intent)
    }
}

class MonentaTodayWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                MonentaWidgetStore.notifyWidgetUpdated(context)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.monenta_today_widget)

            val raw = MonentaWidgetStore.getPayload(context)
            val todayKey = MonentaWidgetStore.getCurrentDateKey()
            var dateTitle = MonentaWidgetStore.getCurrentDateTitle()
            var doneCount = 0
            var totalCount = 0

            if (!raw.isNullOrEmpty()) {
                try {
                    val obj = JSONObject(raw)
                    if (obj.optString("dateKey") == todayKey) {
                        dateTitle = obj.optString("dateTitle", dateTitle)
                        doneCount = obj.optInt("doneCount", 0)
                        totalCount = obj.optInt("totalCount", 0)
                    }
                } catch (_: Exception) {}
            }

            views.setTextViewText(R.id.widget_date_title, dateTitle)
            views.setTextViewText(R.id.widget_count_badge, "$doneCount/$totalCount")

            // 绑定可滚动列表服务
            val serviceIntent = Intent(context, MonentaTodayWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_task_list, serviceIntent)
            views.setEmptyView(R.id.widget_task_list, R.id.widget_empty_view)

            // 点击头部或空白区域打开 App
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val headerPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_header, headerPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_empty_view, headerPendingIntent)

            // 列表项点击模板（显式 Intent 配合 MUTABLE 兼容 Android 12+）
            val templateFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
            val itemTemplatePendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 10000,
                launchIntent,
                templateFlags
            )
            views.setPendingIntentTemplate(R.id.widget_task_list, itemTemplatePendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_task_list)
        }
    }
}

class MonentaTodayWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MonentaTodayViewsFactory(applicationContext)
    }
}

private data class WidgetTaskItem(
    val title: String,
    val isDone: Boolean,
    val isFailed: Boolean,
    val isEvent: Boolean,
    val color: Int,
    val meta: String
)

class MonentaTodayViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val items = mutableListOf<WidgetTaskItem>()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items.clear()
        val raw = MonentaWidgetStore.getPayload(context) ?: return
        val todayKey = MonentaWidgetStore.getCurrentDateKey()
        try {
            val obj = JSONObject(raw)
            if (obj.optString("dateKey") != todayKey) return
            val arr: JSONArray = obj.optJSONArray("items") ?: return
            for (i in 0 until arr.length()) {
                val itemObj = arr.optJSONObject(i) ?: continue
                items.add(
                    WidgetTaskItem(
                        title = itemObj.optString("title", ""),
                        isDone = itemObj.optBoolean("isDone", false),
                        isFailed = itemObj.optBoolean("isFailed", false),
                        isEvent = itemObj.optBoolean("isEvent", false),
                        color = itemObj.optInt("color", Color.parseColor("#03A9F4")),
                        meta = itemObj.optString("meta", "")
                    )
                )
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.monenta_widget_item)
        if (position < 0 || position >= items.size) return views

        val item = items[position]
        views.setTextViewText(R.id.widget_item_title, item.title)

        val dotColor = when {
            item.isFailed -> Color.parseColor("#EF4444")
            item.isDone -> Color.parseColor("#CBD5E1")
            else -> item.color
        }
        views.setInt(R.id.widget_item_dot, "setColorFilter", dotColor)

        val textColor = when {
            item.isFailed -> Color.parseColor("#DC2626")
            item.isDone && !item.isEvent -> Color.parseColor("#94A3B8")
            else -> Color.parseColor("#1E293B")
        }
        views.setTextColor(R.id.widget_item_title, textColor)

        val flags = if (item.isFailed || (item.isDone && !item.isEvent)) {
            Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG
        } else {
            Paint.ANTI_ALIAS_FLAG
        }
        views.setInt(R.id.widget_item_title, "setPaintFlags", flags)

        if (item.meta.isNotEmpty()) {
            views.setViewVisibility(R.id.widget_item_meta, View.VISIBLE)
            views.setTextViewText(R.id.widget_item_meta, item.meta)
        } else {
            views.setViewVisibility(R.id.widget_item_meta, View.GONE)
        }

        views.setOnClickFillInIntent(R.id.widget_item_root, Intent())
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false
}