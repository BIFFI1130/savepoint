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
import org.json.JSONArray

/**
 * 「遊びたい」の中で本日発売の作品を、カバー画像付きで最大4件一覧表示する
 * ホーム画面ウィジェット。データ（JSON配列）はFlutter側（BacklogWidgetService）が
 * SharedPreferencesに保存する。画像はHomeWidget.saveImageで事前にファイル保存
 * 済みのものをBitmapFactoryで読み込むだけで、ネットワーク取得は行わない。
 */
class TodayReleasesWidgetProvider : HomeWidgetProvider() {

    private val slotImageIds =
        intArrayOf(
            R.id.today_release_image_0,
            R.id.today_release_image_1,
            R.id.today_release_image_2,
            R.id.today_release_image_3,
        )
    private val slotTitleIds =
        intArrayOf(
            R.id.today_release_title_0,
            R.id.today_release_title_1,
            R.id.today_release_title_2,
            R.id.today_release_title_3,
        )
    private val slotContainerIds =
        intArrayOf(
            R.id.today_release_slot_0,
            R.id.today_release_slot_1,
            R.id.today_release_slot_2,
            R.id.today_release_slot_3,
        )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val items = parseItems(widgetData.getString("today_releases_json", null))

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.today_releases_widget).apply {
                setViewVisibility(
                    R.id.today_releases_widget_empty,
                    if (items.isEmpty()) View.VISIBLE else View.GONE,
                )

                slotContainerIds.indices.forEach { i ->
                    val item = items.getOrNull(i)
                    if (item == null) {
                        setViewVisibility(slotContainerIds[i], View.GONE)
                        return@forEach
                    }
                    setViewVisibility(slotContainerIds[i], View.VISIBLE)
                    setTextViewText(slotTitleIds[i], item.title)

                    val bitmap = item.imagePath?.let { BitmapFactory.decodeFile(it) }
                    if (bitmap != null) {
                        setImageViewBitmap(slotImageIds[i], bitmap)
                    } else {
                        setImageViewResource(slotImageIds[i], android.R.color.transparent)
                    }

                    val uri = Uri.parse("savepoint://game/${item.gameId}")
                    val pendingIntent =
                        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
                    setOnClickPendingIntent(slotContainerIds[i], pendingIntent)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private data class ReleaseItem(val gameId: String, val title: String, val imagePath: String?)

    private fun parseItems(json: String?): List<ReleaseItem> {
        if (json.isNullOrEmpty()) return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).map { i ->
                val obj = array.getJSONObject(i)
                ReleaseItem(
                    gameId = obj.getString("id"),
                    title = obj.getString("title"),
                    imagePath = if (obj.isNull("image")) null else obj.getString("image"),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }
}
