package com.riseprotocol.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/**
 * Single place that knows how to talk to [AlarmManager] and how to persist
 * "what should be scheduled" so [BootReceiver] can re-arm everything after a
 * reboot without needing Dart/Flutter to be running.
 *
 * The persisted mirror (SharedPreferences, JSON) is intentionally decoupled
 * from the app's real database (SQLite, owned by Dart via sqflite) — this
 * copy only ever needs enough to re-issue an AlarmManager call, and reading
 * it from a BroadcastReceiver at boot has to be cheap and dependency-free.
 */
object AlarmScheduler {
    private const val PREFS_NAME = "riseprotocol_scheduled_alarms"
    private const val KEY_TRIGGERS = "triggers"

    data class Trigger(
        val id: Int,
        val triggerAtMillis: Long,
        val label: String,
        val missionType: String
    )

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
        alarmManager.setAlarmClock(info, pendingIntent)

        persistTrigger(context, trigger)
    }

    fun cancel(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = PendingIntent.getBroadcast(
            context, id, Intent(context, AlarmReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        removeTrigger(context, id)
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

    // ---- Persistence (for BootReceiver) ----

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
            result.add(
                Trigger(
                    id = obj.getInt("id"),
                    triggerAtMillis = obj.getLong("triggerAtMillis"),
                    label = obj.optString("label", ""),
                    missionType = obj.optString("missionType", "none")
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
            array.put(obj)
        }
        prefs(context).edit().putString(KEY_TRIGGERS, array.toString()).apply()
    }
}
