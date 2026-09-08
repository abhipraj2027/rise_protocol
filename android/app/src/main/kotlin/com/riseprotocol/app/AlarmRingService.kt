package com.riseprotocol.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Foreground service that owns the process's "stay alive" guarantee between
 * the moment [AlarmReceiver] fires and the moment the user dismisses or
 * snoozes. It does not play audio itself — that happens in the ringing
 * screen's Flutter engine (see RingingScreen, just_audio) — its job is to:
 *
 *  1. Hold a short wake lock so the screen/CPU actually wakes up.
 *  2. Post a full-screen-intent notification, which is the OS-sanctioned way
 *     for a locked/idle device to auto-launch an Activity (a plain
 *     `startActivity` call from a background service is blocked on Android
 *     10+ in most states).
 *  3. Also attempt a direct `startActivity` as a best-effort fallback — some
 *     OEM skins honor it when the call happens immediately inside the
 *     window opened by the AlarmManager broadcast, and it's harmless to try.
 */
class AlarmRingService : Service() {

    companion object {
        const val ACTION_START_RINGING = "action_start_ringing"
        const val ACTION_STOP_RINGING = "action_stop_ringing"
        private const val CHANNEL_ID = "rise_protocol_alarm_channel"
        private const val NOTIFICATION_ID = 4200

        /** Lets MainActivity's MethodChannel handler stop the service without
         *  needing to know a running instance's reference. */
        fun stop(context: Context) {
            val intent = Intent(context, AlarmRingService::class.java).apply {
                action = ACTION_STOP_RINGING
            }
            context.startService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_RINGING -> {
                stopSelfCleanly()
                return START_NOT_STICKY
            }
            else -> {
                val id = intent?.getIntExtra(AlarmReceiver.EXTRA_ID, -1) ?: -1
                val label = intent?.getStringExtra(AlarmReceiver.EXTRA_LABEL) ?: ""
                val mission = intent?.getStringExtra(AlarmReceiver.EXTRA_MISSION) ?: "none"
                startRinging(id, label, mission)
                return START_STICKY
            }
        }
    }

    private fun startRinging(id: Int, label: String, mission: String) {
        acquireWakeLock()
        createChannelIfNeeded()

        val fullScreenPendingIntent = ringingActivityPendingIntent(id, label, mission)

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(if (label.isNotEmpty()) label else "Alarm")
            .setContentText("Tap to open your alarm")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        // Best-effort direct launch — see class doc.
        try {
            startActivity(ringingActivityIntent(id, label, mission))
        } catch (_: Exception) {
            // Fine — the full-screen-intent notification above is the
            // guaranteed path; this is only ever a nicer-case shortcut.
        }
    }

    private fun ringingActivityIntent(id: Int, label: String, mission: String): Intent {
        return Intent(this, AlarmRingingActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_NO_USER_ACTION or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra(AlarmReceiver.EXTRA_ID, id)
            putExtra(AlarmReceiver.EXTRA_LABEL, label)
            putExtra(AlarmReceiver.EXTRA_MISSION, mission)
        }
    }

    private fun ringingActivityPendingIntent(id: Int, label: String, mission: String): PendingIntent {
        return PendingIntent.getActivity(
            this, id, ringingActivityIntent(id, label, mission),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
            "RiseProtocol:AlarmWakeLock"
        )
        // 10 minutes is plenty for the ringing UI to take over; the ringing
        // Activity itself keeps the screen on independently once shown.
        wakeLock?.acquire(10 * 60 * 1000L)
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID, "Alarms", NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Alarm ringing notifications"
            setBypassDnd(true)
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    private fun stopSelfCleanly() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
