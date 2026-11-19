package com.riseprotocol.app

import android.content.Context

/**
 * Counts snoozes per alarm so the ringing screen can show "2 snoozes left"
 * and hide Snooze once the alarm's limit is reached.
 *
 * Written to the same SharedPreferences file the Flutter
 * `shared_preferences` plugin uses ("FlutterSharedPreferences", keys
 * prefixed "flutter.", ints stored as Long), so Dart reads it with a plain
 * `SharedPreferences.getInstance()` — see lib/core/wake_stats.dart, which
 * also resets the count when a mission is cleared.
 *
 * The time of the last snooze is stored too: Dart ignores counts older than
 * a few hours, so a ring that was never properly dismissed can't eat into
 * tomorrow's snoozes.
 */
object SnoozeCounter {
    private const val PREFS = "FlutterSharedPreferences"

    @Synchronized
    fun increment(context: Context, alarmId: Int) {
        try {
            val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val countKey = "flutter.snooze_count_$alarmId"
            val atKey = "flutter.snooze_at_$alarmId"
            val last = prefs.getLong(atKey, 0L)
            val fresh = now - last > STALE_AFTER_MILLIS
            val count = if (fresh) 0L else prefs.getLong(countKey, 0L)
            prefs.edit()
                .putLong(countKey, count + 1)
                .putLong(atKey, now)
                .apply()
        } catch (_: Exception) {
            // Counting must never break snoozing.
        }
    }

    /** Matches `WakeStats.snoozeStaleAfter` on the Dart side. */
    private const val STALE_AFTER_MILLIS = 3 * 60 * 60 * 1000L
}
