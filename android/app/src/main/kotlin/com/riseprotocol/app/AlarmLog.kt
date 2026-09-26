package com.riseprotocol.app

import android.content.Context
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * A small persistent event log for the alarm pipeline (scheduled → fired →
 * service started → screen opened → dismissed/snoozed). Alarms fail in ways
 * that are invisible without a debugger — the OS silently blocks something —
 * so every step writes a line here and the in-app "Alarm diagnostics" screen
 * shows them, letting a tester paste the log instead of attaching adb.
 */
object AlarmLog {
    private const val PREFS = "riseprotocol_alarm_log"
    private const val KEY = "lines"
    private const val MAX_LINES = 100

    @Synchronized
    fun add(context: Context, message: String) {
        Log.i("RiseAlarm", message)
        try {
            val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val stamp = SimpleDateFormat("MM-dd HH:mm:ss", Locale.US).format(Date())
            val lines = (prefs.getString(KEY, "") ?: "")
                .split("\n")
                .filter { it.isNotBlank() }
                .toMutableList()
            lines.add("$stamp  $message")
            while (lines.size > MAX_LINES) lines.removeAt(0)
            prefs.edit().putString(KEY, lines.joinToString("\n")).apply()
        } catch (_: Exception) {
            // Logging must never break the alarm.
        }
    }

    @Synchronized
    fun read(context: Context): List<String> {
        val raw = context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, "") ?: ""
        return raw.split("\n").filter { it.isNotBlank() }
    }

    @Synchronized
    fun clear(context: Context) {
        context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove(KEY).apply()
    }
}
