package com.riseprotocol.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Single place that knows how to talk to [AlarmManager] and how to persist
 * "what should be scheduled" so [AlarmReceiver] and [BootReceiver] can re-arm
 * alarms without Dart/Flutter running.
 *
 * The persisted mirror (SharedPreferences, JSON) is intentionally decoupled
 * from the app's real database (SQLite, owned by Dart via sqflite). Besides
 * the next trigger time it keeps the alarm's repeat *rule* (hour, minute,
 * days), which is what lets a repeating alarm arm its own next occurrence the
 * moment it fires — even if the app is never opened again.
 */
object AlarmScheduler {
    private const val PREFS_NAME = "riseprotocol_scheduled_alarms"
    private const val KEY_TRIGGERS = "triggers"
    private const val KEY_FIRED_ONE_SHOTS = "fired_one_shots"

    data class Trigger(
        val id: Int,
        val triggerAtMillis: Long,
        val label: String,
        val missionType: String,
        /** The alarm's own snooze length, so snoozing from the ringing screen
         *  or the notification honours the editor setting. */
        val snoozeMinutes: Int = 5,
        /** The alarm's wall-clock time and repeat days (ISO weekday, 1 = Mon
         *  … 7 = Sun; same as Dart's DateTime.weekday). hour = -1 means the
         *  rule is unknown (an alarm saved by an older build). */
        val hour: Int = -1,
        val minute: Int = 0,
        val repeatDays: Set<Int> = emptySet()
    )

    fun isRepeating(t: Trigger): Boolean = t.hour >= 0 && t.repeatDays.isNotEmpty()

    /** The next regular occurrence of a repeating alarm strictly after
     *  [fromMillis]. Mirrors Alarm.nextTriggerMillis in Dart. */
    fun nextOccurrence(t: Trigger, fromMillis: Long): Long {
        for (offset in 0..7) {
            val c = Calendar.getInstance().apply {
                timeInMillis = fromMillis
                set(Calendar.HOUR_OF_DAY, t.hour)
                set(Calendar.MINUTE, t.minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.DAY_OF_YEAR, offset)
            }
            // Calendar: Sunday = 1 … Saturday = 7  →  ISO: Monday = 1 … Sunday = 7
            val isoWeekday = ((c.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1
            if (t.repeatDays.contains(isoWeekday) && c.timeInMillis > fromMillis) {
                return c.timeInMillis
            }
        }
        return fromMillis + 7 * 24 * 60 * 60 * 1000L
    }

    fun schedule(context: Context, trigger: Trigger) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = pendingIntentFor(context, trigger)

        // setAlarmClock gives the strongest delivery guarantee available on
        // Android (shows the "next alarm" icon in the status bar too, which
        // is expected UX for an alarm-clock app) and is exempt from Doze
        // deferral in a way setExactAndAllowWhileIdle is not guaranteed to be
        // on every OEM skin.
        val showIntent = PendingIntent.getActivity(
            context, trigger.id, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val info = AlarmManager.AlarmClockInfo(trigger.triggerAtMillis, showIntent)
        try {
            alarmManager.setAlarmClock(info, pendingIntent)
        } catch (e: Exception) {
            AlarmLog.add(context, "FAILED to schedule id=${trigger.id}: ${e.javaClass.simpleName}: ${e.message}")
            throw e
        }

        val inSeconds = (trigger.triggerAtMillis - System.currentTimeMillis()) / 1000
        val at = java.text.SimpleDateFormat("EEE HH:mm:ss", java.util.Locale.US)
            .format(java.util.Date(trigger.triggerAtMillis))
        AlarmLog.add(
            context,
            "scheduled id=${trigger.id} for $at (in ${inSeconds}s), snooze=${trigger.snoozeMinutes}m, " +
                "repeats=${if (isRepeating(trigger)) trigger.repeatDays.sorted().toString() else "no"}, " +
                "exactAllowed=${canScheduleExactAlarms(context)}"
        )

        persistTrigger(context, trigger)
        // Anything with a pending trigger is, by definition, not "already fired".
        unmarkOneShotFired(context, trigger.id)
    }

    fun cancel(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = PendingIntent.getBroadcast(
            context, id, Intent(context, AlarmReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        removeTrigger(context, id)
        unmarkOneShotFired(context, id)
    }

    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    private fun pendingIntentFor(context: Context, trigger: Trigger): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra(AlarmReceiver.EXTRA_ID, trigger.id)
            putExtra(AlarmReceiver.EXTRA_LABEL, trigger.label)
            putExtra(AlarmReceiver.EXTRA_MISSION, trigger.missionType)
        }
        return PendingIntent.getBroadcast(
            context, trigger.id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    // ---- One-shot alarms that have fired -----------------------------------
    // Dart owns the alarm list, so a one-time alarm that has rung can only be
    // switched off in the UI next time the app runs. Native records the ids;
    // Dart collects them with takeFiredOneShots().

    fun markOneShotFired(context: Context, id: Int) {
        val set = HashSet(prefs(context).getStringSet(KEY_FIRED_ONE_SHOTS, emptySet()) ?: emptySet())
        if (set.add(id.toString())) {
            prefs(context).edit().putStringSet(KEY_FIRED_ONE_SHOTS, set).apply()
        }
    }

    private fun unmarkOneShotFired(context: Context, id: Int) {
        val set = HashSet(prefs(context).getStringSet(KEY_FIRED_ONE_SHOTS, emptySet()) ?: emptySet())
        if (set.remove(id.toString())) {
            prefs(context).edit().putStringSet(KEY_FIRED_ONE_SHOTS, set).apply()
        }
    }

    fun takeFiredOneShots(context: Context): List<Int> {
        val set = prefs(context).getStringSet(KEY_FIRED_ONE_SHOTS, emptySet()) ?: emptySet()
        val ids = set.mapNotNull { it.toIntOrNull() }
        if (set.isNotEmpty()) prefs(context).edit().remove(KEY_FIRED_ONE_SHOTS).apply()
        return ids
    }

    // ---- Persistence ---------------------------------------------------------

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun persistTrigger(context: Context, trigger: Trigger) {
        val all = readAll(context).filter { it.id != trigger.id }.toMutableList()
        all.add(trigger)
        writeAll(context, all)
    }

    private fun removeTrigger(context: Context, id: Int) {
        val all = readAll(context).filter { it.id != id }
        writeAll(context, all)
    }

    fun readAll(context: Context): List<Trigger> {
        val raw = prefs(context).getString(KEY_TRIGGERS, "[]") ?: "[]"
        val array = JSONArray(raw)
        val result = mutableListOf<Trigger>()
        for (i in 0 until array.length()) {
            val obj = array.getJSONObject(i)
            val days = mutableSetOf<Int>()
            val daysJson = obj.optJSONArray("repeatDays")
            if (daysJson != null) {
                for (d in 0 until daysJson.length()) days.add(daysJson.getInt(d))
            }
            result.add(
                Trigger(
                    id = obj.getInt("id"),
                    triggerAtMillis = obj.getLong("triggerAtMillis"),
                    label = obj.optString("label", ""),
                    missionType = obj.optString("missionType", "none"),
                    snoozeMinutes = obj.optInt("snoozeMinutes", 5),
                    hour = obj.optInt("hour", -1),
                    minute = obj.optInt("minute", 0),
                    repeatDays = days
                )
            )
        }
        return result
    }

    private fun writeAll(context: Context, triggers: List<Trigger>) {
        val array = JSONArray()
        for (t in triggers) {
            val obj = JSONObject()
            obj.put("id", t.id)
            obj.put("triggerAtMillis", t.triggerAtMillis)
            obj.put("label", t.label)
            obj.put("missionType", t.missionType)
            obj.put("snoozeMinutes", t.snoozeMinutes)
            obj.put("hour", t.hour)
            obj.put("minute", t.minute)
            val days = JSONArray()
            for (d in t.repeatDays.sorted()) days.put(d)
            obj.put("repeatDays", days)
            array.put(obj)
        }
        prefs(context).edit().putString(KEY_TRIGGERS, array.toString()).apply()
    }
}
