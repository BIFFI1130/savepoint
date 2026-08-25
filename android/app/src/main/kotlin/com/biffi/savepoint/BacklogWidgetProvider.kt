package com.biffi.savepoint

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate

/**
 * 積みゲー（「遊びたい」）の中で発売が一番近い作品を常時表示するホーム画面ウィジェット。
 * データ（タイトル・発売日・ゲームID）はFlutter側（BacklogWidgetService）が
 * SharedPreferencesに保存し、「発売まであと○日」の文字列自体はここ（onUpdate）で
 * 毎回計算し直す。こうすることでアプリを開かない日でも、Android自身の定期更新
 * （backlog_widget_info.xmlのupdatePeriodMillis）だけでカウントダウンが古くならない。
 */
class BacklogWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val title = widgetData.getString("backlog_title", null)
            val releaseDateIso = widgetData.getString("backlog_release_date", null)
            val gameId = widgetData.getString("backlog_game_id", null)
            val coverImagePath = widgetData.getString("backlog_cover_image", null)
            val streak = widgetData.getString("backlog_streak", null)
            val countdown = releaseDateIso?.let { computeCountdownLabel(it) }
            val hasEntry = title != null && countdown != null

            val views = RemoteViews(context.packageName, R.layout.backlog_widget).apply {
                if (hasEntry) {
                    setTextViewText(R.id.backlog_widget_title, title)
                    setTextViewText(R.id.backlog_widget_countdown, countdown)
                } else {
                    setTextViewText(R.id.backlog_widget_title, "もうすぐ発売の遊びたいゲームはありません")
                    setTextViewText(R.id.backlog_widget_countdown, "SavePoint")
                }

                if (!streak.isNullOrEmpty()) {
                    setTextViewText(R.id.backlog_widget_streak, streak)
                    setViewVisibility(R.id.backlog_widget_streak, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.backlog_widget_streak, View.GONE)
                }

                val cover = if (hasEntry) coverImagePath?.let { BitmapFactory.decodeFile(it) } else null
                if (cover != null) {
                    setImageViewBitmap(R.id.backlog_widget_cover, cover)
                    setViewVisibility(R.id.backlog_widget_cover, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.backlog_widget_cover, View.GONE)
                }

                val uri = if (hasEntry && gameId != null) {
                    Uri.parse("savepoint://game/$gameId")
                } else {
                    Uri.parse("savepoint://home")
                }
                val pendingIntent =
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
                setOnClickPendingIntent(R.id.backlog_widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /** [releaseDateIso]（"YYYY-MM-DD"）を元に、時刻・タイムゾーンを無視した日付単位で
     * 「本日発売」「発売まであと○日」を返す。発売済み・解析失敗時はnull。 */
    private fun computeCountdownLabel(releaseDateIso: String): String? {
        return try {
            val todayEpochDay = LocalDate.now().toEpochDay()
            val releaseEpochDay = LocalDate.parse(releaseDateIso).toEpochDay()
            val daysUntil = releaseEpochDay - todayEpochDay
            when {
                daysUntil == 0L -> "本日発売"
                daysUntil > 0L -> "発売まであと${daysUntil}日"
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }
}
