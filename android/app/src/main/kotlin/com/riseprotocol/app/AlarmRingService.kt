package com.riseprotocol.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat

/**
 * Foreground service that owns everything about a firing alarm from the
 * moment [AlarmReceiver] fires until the user dismisses or snoozes:
 *
 *  1. Wake lock so the CPU/screen actually wake up.
 *  2. **Audio + vibration**, played here natively (USAGE_ALARM) so the alarm
 *     rings even when the app is killed and Android blocks the ringing
 *     Activity from launching. Falls back to the system alarm ringtone if
 *     the bundled tone can't be loaded.
 *  3. A full-screen-intent notification (the OS-sanctioned way to auto-open
 *     an Activity over a locked/idle screen) with Snooze / Dismiss actions
 *     so the alarm is controllable even if the full-screen UI never appears.
 *  4. A best-effort direct `startActivity` for OEMs that still allow it.
 */
class AlarmRingService : Service() {

    companion object {
        const val ACTION_START_RINGING = "action_start_ringing"
        const val ACTION_STOP_RINGING = "action_stop_ringing"
        const val ACTION_DISMISS = "action_dismiss"
        const val ACTION_SNOOZE = "action_snooze"

        /** Broadcast the ringing Activity listens for, so it closes when the
         *  alarm is dismissed/snoozed from the notification. */
        const val ACTION_FINISH_RINGING_UI = "com.riseprotocol.app.FINISH_RINGING_UI"

        private const val CHANNEL_ID = "rise_protocol_alarm_v2"
        private const val LEGACY_CHANNEL_ID = "rise_protocol_alarm_channel"
        private const val NOTIFICATION_ID = 4200
        private const val SNOOZE_MINUTES = 5

        fun stop(context: Context) {
            val intent = Intent(context, AlarmRingService::class.java).apply {
                action = ACTION_STOP_RINGING
            }
            context.startService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var player: MediaPlayer? = null
    private var toneFd: AssetFileDescriptor? = null
    private var vibrator: Vibrator? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_RINGING, ACTION_DISMISS -> {
                stopSelfCleanly()
                return START_NOT_STICKY
            }
            ACTION_SNOOZE -> {
                val id = intent?.getIntExtra(AlarmReceiver.EXTRA_ID, -1) ?: -1
                if (id != -1) {
                    AlarmScheduler.schedule(
                        this,
                        AlarmScheduler.Trigger(
                            id,
                            System.currentTimeMillis() + SNOOZE_MINUTES * 60_000L,
                            intent?.getStringExtra(AlarmReceiver.EXTRA_LABEL) ?: "",
                            intent?.getStringExtra(AlarmReceiver.EXTRA_MISSION) ?: "none",
                        ),
                    )
                }
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
        startForeground(NOTIFICATION_ID, buildNotification(id, label, mission))
        startAudio()
        startVibration()

        try {
            startActivity(ringingActivityIntent(id, label, mission))
        } catch (_: Exception) {
            // Expected on stock Android 10+ when unlocked — the full-screen
            // intent notification is the guaranteed path.
        }
    }

    private fun startAudio() {
        try {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            player = MediaPlayer().apply {
                setAudioAttributes(attrs)
                isLooping = true
                var sourceSet = false
                try {
                    val fd = assets.openFd("flutter_assets/assets/sounds/default_alarm.wav")
                    toneFd = fd
                    setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
                    sourceSet = true
                } catch (_: Exception) {
                }
                if (!sourceSet) {
                    val fallback = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                    if (fallback != null) setDataSource(this@AlarmRingService, fallback)
                }
                setOnPreparedListener {
                    it.setVolume(0.35f, 0.35f)
                    it.start()
                }
                setOnErrorListener { _, _, _ -> true }
                prepareAsync()
            }
        } catch (_: Exception) {
            // No audio — vibration + the notification still carry the alarm.
            player?.release()
            player = null
        }

        // ~5-second ramp from a gentle start to full volume.
        var vol = 0.35f
        val ramp = object : Runnable {
            override fun run() {
                vol = (vol + 0.16f).coerceAtMost(1f)
                try {
                    player?.setVolume(vol, vol)
                } catch (_: Exception) {
                }
                if (vol < 1f) handler.postDelayed(this, 1200)
            }
        }
        handler.postDelayed(ramp, 2500)
    }

    private fun startVibration() {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0L, 600L, 900L)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    }

    private fun buildNotification(id: Int, label: String, mission: String): Notification {
        val open = ringingActivityPendingIntent(id, label, mission)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(if (label.isNotEmpty()) label else "Alarm")
            .setContentText("Tap to open — or snooze / dismiss below")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(open, true)
            .setContentIntent(open)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(0, "Snooze", servicePendingIntent(ACTION_SNOOZE, id, label, mission))
            .addAction(0, "Dismiss", servicePendingIntent(ACTION_DISMISS, id, label, mission))
            .build()
    }

    private fun servicePendingIntent(
        action: String,
        id: Int,
        label: String,
        mission: String,
    ): PendingIntent {
        val intent = Intent(this, AlarmRingService::class.java).apply {
            this.action = action
            putExtra(AlarmReceiver.EXTRA_ID, id)
            putExtra(AlarmReceiver.EXTRA_LABEL, label)
            putExtra(AlarmReceiver.EXTRA_MISSION, mission)
        }
        val req = id * 10 + if (action == ACTION_SNOOZE) 1 else 2
        return PendingIntent.getService(
            this,
            req,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ringingActivityIntent(id: Int, label: String, mission: String): Intent {
        return Intent(this, AlarmRingingActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_NO_USER_ACTION or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            putExtra(AlarmReceiver.EXTRA_ID, id)
            putExtra(AlarmReceiver.EXTRA_LABEL, label)
            putExtra(AlarmReceiver.EXTRA_MISSION, mission)
        }
    }

    private fun ringingActivityPendingIntent(id: Int, label: String, mission: String): PendingIntent {
        return PendingIntent.getActivity(
            this,
            id,
            ringingActivityIntent(id, label, mission),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        @Suppress("DEPRECATION")
        wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
            "RiseProtocol:AlarmWakeLock",
        )
        wakeLock?.acquire(10 * 60 * 1000L)
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // The v1 channel carried its own sound + vibration, which now double
        // up with what this service plays. Drop it.
        manager.deleteNotificationChannel(LEGACY_CHANNEL_ID)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Alarms",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "A firing alarm"
            setBypassDnd(true)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    private fun teardown() {
        handler.removeCallbacksAndMessages(null)
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        player?.release()
        player = null
        try {
            toneFd?.close()
        } catch (_: Exception) {
        }
        toneFd = null
        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        }
        vibrator = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun stopSelfCleanly() {
        teardown()
        sendBroadcast(Intent(ACTION_FINISH_RINGING_UI).setPackage(packageName))
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        teardown()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
