package com.biffi.savepoint

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 今月「遊んだ」件数・新規に「遊びたい」に追加した件数を表示するホーム画面ウィジェット。
 * データはFlutter側（BacklogWidgetService）がSharedPreferencesに保存する。
 */
class MonthlyStatsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val monthLabel = widgetData.getString("monthly_stats_month_label", null)
        val playedCount = widgetData.getString("monthly_stats_played_count", null)
        val wantToPlayCount = widgetData.getString("monthly_stats_want_to_play_count", null)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.monthly_stats_widget).apply {
                setTextViewText(
                    R.id.monthly_stats_widget_month,
                    monthLabel ?: "今月",
                )
                setTextViewText(
                    R.id.monthly_stats_widget_played,
                    "遊んだ ${playedCount ?: "0"}本",
                )
                setTextViewText(
                    R.id.monthly_stats_widget_want_to_play,
                    "遊びたい追加 ${wantToPlayCount ?: "0"}本",
                )

                val uri = Uri.parse("savepoint://home")
                val pendingIntent =
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
                setOnClickPendingIntent(R.id.monthly_stats_widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
