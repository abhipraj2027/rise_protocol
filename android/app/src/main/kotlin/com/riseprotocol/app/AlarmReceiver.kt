package com.riseprotocol.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Fired by [android.app.AlarmManager] at the exact scheduled instant. This
 * receiver has a very short execution budget (a few seconds, per the OS), so
 * all it does is hand off to a foreground service — it does not itself try
 * to play audio or show UI directly.
 */
class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val EXTRA_ID = "extra_id"
        const val EXTRA_LABEL = "extra_label"
        const val EXTRA_MISSION = "extra_mission"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, -1)
        AlarmLog.add(context, "alarm broadcast received (id=$id)")
        if (id == -1) {
            AlarmLog.add(context, "IGNORED: broadcast had no alarm id")
            return
        }
        val label = intent.getStringExtra(EXTRA_LABEL) ?: ""
        val mission = intent.getStringExtra(EXTRA_MISSION) ?: "none"

        val serviceIntent = Intent(context, AlarmRingService::class.java).apply {
            action = AlarmRingService.ACTION_START_RINGING
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_LABEL, label)
            putExtra(EXTRA_MISSION, mission)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            AlarmLog.add(context, "ring service start requested")
        } catch (e: Exception) {
            AlarmLog.add(context, "FAILED to start ring service: ${e.javaClass.simpleName}: ${e.message}")
        }
    }
}
