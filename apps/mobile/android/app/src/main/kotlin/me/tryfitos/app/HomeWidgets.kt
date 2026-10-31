package me.tryfitos.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

/**
 * Beta 5.0 (owner): FITOS's four home-screen widgets. The app writes a
 * snapshot (lib/features/home_widgets, already worded) to its shared
 * preferences and asks for a redraw; each widget picks today's part of it.
 * After midnight they show the new day from the snapshot's week and targets
 * without the app (an alarm just past midnight redraws them).
 *
 * A tap opens FITOS on the screen it names (`fitos://widget/<target>`);
 * nothing starts without a tap there.
 */
object HomeWidgets {
    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY = "flutter.widgets.snapshot"

    private val providers = listOf(
        FoodWidget::class.java,
        TrainingWidget::class.java,
        StreakWidget::class.java,
        ActionsWidget::class.java,
    )

    /** Redraw every FITOS widget on the home screen. */
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (cls in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, cls))
            if (ids.isEmpty()) continue
            context.sendBroadcast(
                Intent(context, cls)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
            )
        }
    }

    fun snapshot(context: Context): JSONObject? = try {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null)
            ?.let { JSONObject(it) }
    } catch (e: Exception) {
        null
    }

    fun today(): String = LocalDate.now().toString()

    /** Opens FITOS on [target]; [code] keeps each tap's intent apart. */
    fun open(context: Context, target: String, code: Int): PendingIntent =
        PendingIntent.getActivity(
            context,
            code,
            Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_VIEW)
                .setData(Uri.parse("fitos://widget/$target"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    /** A redraw just past the next midnight (inexact: no special permission). */
    fun scheduleMidnight(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val at = LocalDate.now().plusDays(1).atStartOfDay().plusMinutes(1)
            .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        alarms.set(
            AlarmManager.RTC,
            at,
            PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, HomeWidgetsRefresh::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            ),
        )
    }

    /** "1:20 pm" from an ISO time, in the phone's zone. */
    fun clock(iso: String?): String? = try {
        iso?.let {
            java.time.OffsetDateTime.parse(it)
                .atZoneSameInstant(ZoneId.systemDefault())
                .format(DateTimeFormatter.ofPattern("h:mm a", Locale.ENGLISH))
                .lowercase(Locale.ENGLISH)
        }
    } catch (e: Exception) {
        null
    }

    fun grouped(n: Int): String = String.format(Locale.ENGLISH, "%,d", n)

    fun dp(context: Context, v: Float): Float = v * context.resources.displayMetrics.density

    /** The calorie ring: eaten against the target, past it in amber. */
    fun ring(context: Context, share: Double, over: Boolean): Bitmap {
        val size = dp(context, 64f).toInt()
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val w = dp(context, 7f)
        val r = RectF(w / 2, w / 2, size - w / 2, size - w / 2)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = w
            strokeCap = Paint.Cap.ROUND
        }
        paint.color = context.getColor(R.color.widget_rule)
        c.drawArc(r, 0f, 360f, false, paint)
        paint.color = context.getColor(if (over) R.color.widget_over else R.color.widget_accent)
        val sweep = (360.0 * share.coerceIn(0.0, 1.0)).toFloat()
        if (sweep > 0f) c.drawArc(r, -90f, sweep, false, paint)
        return bmp
    }

    /**
     * This week, Monday first, coloured like Streak & rewards: blue trained,
     * green rest, grey skipped, an outline missed; today outlined in blue
     * until it counts; days to come blank.
     */
    fun week(context: Context, days: JSONArray?, today: LocalDate): Bitmap {
        val cell = dp(context, 22f)
        val gap = dp(context, 6f)
        val label = dp(context, 13f)
        val width = (cell * 7 + gap * 6).toInt()
        val bmp = Bitmap.createBitmap(width, (cell + label + dp(context, 3f)).toInt(), Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val status = HashMap<String, String>()
        if (days != null) {
            for (i in 0 until days.length()) {
                val d = days.optJSONObject(i) ?: continue
                status[d.optString("date")] = d.optString("status")
            }
        }
        val monday = today.minusDays((today.dayOfWeek.value - 1).toLong())
        val fill = Paint(Paint.ANTI_ALIAS_FLAG)
        val edge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(context, 1.5f)
        }
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = dp(context, 10f)
            textAlign = Paint.Align.CENTER
            color = context.getColor(R.color.widget_ink60)
        }
        val letters = "MTWTFSS"
        for (i in 0 until 7) {
            val date = monday.plusDays(i.toLong())
            val x = i * (cell + gap)
            val box = RectF(x + 1, 1f, x + cell - 1, cell - 1)
            val radius = dp(context, 6f)
            val s = status[date.toString()]
            when {
                date.isAfter(today) -> {}
                s == "logged" -> {
                    fill.color = context.getColor(R.color.widget_accent)
                    c.drawRoundRect(box, radius, radius, fill)
                }
                s == "rest" -> {
                    fill.color = context.getColor(R.color.widget_rest)
                    c.drawRoundRect(box, radius, radius, fill)
                }
                s == "skipped" -> {
                    fill.color = context.getColor(R.color.widget_rule)
                    c.drawRoundRect(box, radius, radius, fill)
                }
                date == today -> {
                    edge.color = context.getColor(R.color.widget_accent)
                    c.drawRoundRect(box, radius, radius, edge)
                }
                else -> {
                    edge.color = context.getColor(R.color.widget_ink60)
                    c.drawRoundRect(box, radius, radius, edge)
                }
            }
            c.drawText(letters[i].toString(), x + cell / 2, cell + label - dp(context, 1f), text)
        }
        return bmp
    }
}

/** Redraws the widgets just past midnight, and when the clock or zone changes. */
class HomeWidgetsRefresh : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        HomeWidgets.updateAll(context)
    }
}

/** One FITOS widget: draws itself from the snapshot. */
abstract class FitWidget : AppWidgetProvider() {
    abstract fun render(context: Context, snap: JSONObject?, today: String): RemoteViews

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val snap = HomeWidgets.snapshot(context)
        val today = HomeWidgets.today()
        for (id in ids) {
            manager.updateAppWidget(id, render(context, snap, today))
        }
        HomeWidgets.scheduleMidnight(context)
    }

    /** Signed out, or no snapshot yet: one line, and a tap opens FITOS. */
    protected fun empty(context: Context, message: String, target: String, code: Int): RemoteViews =
        RemoteViews(context.packageName, R.layout.widget_message).apply {
            setTextViewText(R.id.widget_message, message)
            setOnClickPendingIntent(R.id.widget_root, HomeWidgets.open(context, target, code))
        }

    protected fun signedIn(snap: JSONObject?) = snap?.optBoolean("signedIn", false) == true
}

/** Food left today: the ring, calories and protein left. */
class FoodWidget : FitWidget() {
    override fun render(context: Context, snap: JSONObject?, today: String): RemoteViews {
        if (!signedIn(snap)) return empty(context, "Open FITOS to sign in", "food", 10)
        val food = snap!!.optJSONObject("food")
        val views = RemoteViews(context.packageName, R.layout.widget_food)
        val current = food != null && food.optString("date") == today
        if (current) {
            views.setTextViewText(R.id.food_value, food!!.optString("leftValue"))
            views.setTextViewText(R.id.food_caption, food.optString("leftCaption"))
            setProtein(views, food.optString("protein", ""))
            views.setImageViewBitmap(
                R.id.food_ring,
                HomeWidgets.ring(context, food.optDouble("eatenShare", 0.0), food.optBoolean("over")),
            )
            val at = HomeWidgets.clock(food.optString("loggedAt", "").ifEmpty { null })
            views.setTextViewText(R.id.food_label, if (at == null) "FOOD LEFT" else "FOOD LEFT · $at")
        } else {
            // A new day: the whole target is left.
            val kcal = food?.optInt("kcalTarget", 0) ?: 0
            val protein = food?.optInt("proteinTarget", 0) ?: 0
            views.setTextViewText(R.id.food_label, "FOOD LEFT")
            views.setTextViewText(R.id.food_value, if (kcal > 0) HomeWidgets.grouped(kcal) else "–")
            views.setTextViewText(
                R.id.food_caption,
                if (kcal > 0) "kcal left of ${HomeWidgets.grouped(kcal)}" else "Open FITOS",
            )
            setProtein(views, if (protein > 0) "Protein $protein g left" else "")
            views.setImageViewBitmap(R.id.food_ring, HomeWidgets.ring(context, 0.0, false))
        }
        views.setOnClickPendingIntent(R.id.widget_root, HomeWidgets.open(context, "food", 11))
        return views
    }

    private fun setProtein(views: RemoteViews, text: String) {
        views.setTextViewText(R.id.food_protein, text)
        views.setViewVisibility(R.id.food_protein, if (text.isEmpty()) View.GONE else View.VISIBLE)
    }
}

/** Today's workout or planned run, or a rest day. */
class TrainingWidget : FitWidget() {
    override fun render(context: Context, snap: JSONObject?, today: String): RemoteViews {
        if (!signedIn(snap)) return empty(context, "Open FITOS to sign in", "training", 20)
        val week = snap!!.optJSONArray("week")
        var day: JSONObject? = null
        if (week != null) {
            for (i in 0 until week.length()) {
                val d = week.optJSONObject(i)
                if (d?.optString("date") == today) day = d
            }
        }
        if (day == null) return empty(context, "Open FITOS to see today's training", "training", 21)
        val views = RemoteViews(context.packageName, R.layout.widget_training)
        val kind = day.optString("kind")
        val done = day.optBoolean("done")
        views.setTextViewText(
            R.id.training_icon,
            when (kind) {
                "run" -> "🏃"
                "workout" -> "🏋️"
                "rest" -> "😴"
                else -> "📋"
            },
        )
        views.setTextViewText(R.id.training_label, if (done) "TODAY · DONE" else "TODAY")
        views.setTextViewText(R.id.training_title, day.optString("title"))
        views.setTextViewText(R.id.training_detail, day.optString("detail"))
        val canStart = (kind == "run" || kind == "workout") && !done
        views.setViewVisibility(R.id.training_start, if (canStart) View.VISIBLE else View.GONE)
        views.setOnClickPendingIntent(R.id.widget_root, HomeWidgets.open(context, "training", 22))
        return views
    }
}

/** The streak and this week's days. */
class StreakWidget : FitWidget() {
    override fun render(context: Context, snap: JSONObject?, today: String): RemoteViews {
        if (!signedIn(snap)) return empty(context, "Open FITOS to sign in", "streak", 30)
        val streak = snap!!.optJSONObject("streak")
            ?: return empty(context, "Open FITOS to see your streak", "streak", 31)
        val views = RemoteViews(context.packageName, R.layout.widget_streak)
        val current = streak.optInt("current", 0)
        val counted = streak.optBoolean("todayCounted") && snap.optString("date") == today
        views.setTextViewText(R.id.streak_value, current.toString())
        views.setTextViewText(R.id.streak_unit, if (current == 1) "day" else "days")
        views.setTextViewText(
            R.id.streak_hint,
            if (counted) "Today counts" else "Log today to keep it",
        )
        views.setImageViewBitmap(
            R.id.streak_week,
            HomeWidgets.week(context, streak.optJSONArray("days"), LocalDate.parse(today)),
        )
        views.setOnClickPendingIntent(R.id.widget_root, HomeWidgets.open(context, "streak", 32))
        return views
    }
}

/** Log food · Start workout · Start run · Log weight. */
class ActionsWidget : FitWidget() {
    override fun render(context: Context, snap: JSONObject?, today: String): RemoteViews =
        RemoteViews(context.packageName, R.layout.widget_actions).apply {
            setOnClickPendingIntent(R.id.action_food, HomeWidgets.open(context, "food", 40))
            setOnClickPendingIntent(R.id.action_workout, HomeWidgets.open(context, "workout", 41))
            setOnClickPendingIntent(R.id.action_run, HomeWidgets.open(context, "run", 42))
            setOnClickPendingIntent(R.id.action_weight, HomeWidgets.open(context, "weight", 43))
        }
}

