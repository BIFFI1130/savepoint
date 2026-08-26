package com.biffi.savepoint

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 週間記録ストリークの週数のみを大きく表示するシンプルなホーム画面ウィジェット。
 * データ（表示用の数字と補足ラベル）はFlutter側（BacklogWidgetService）が
 * SharedPreferencesに保存する。
 */
class StreakWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val count = widgetData.getString("streak_widget_count", null)
        val label = widgetData.getString("streak_widget_label", null)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
                setTextViewText(R.id.streak_widget_count, count ?: "0")
                setTextViewText(
                    R.id.streak_widget_label,
                    label ?: "週間記録ストリーク",
                )

                val uri = Uri.parse("savepoint://home")
                val pendingIntent =
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
                setOnClickPendingIntent(R.id.streak_widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
