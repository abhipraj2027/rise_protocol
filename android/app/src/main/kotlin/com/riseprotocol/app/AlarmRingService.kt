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
import android.widget.Toast
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
        const val ACTION_MUTE = "action_mute"
        const val EXTRA_MUTE_SECONDS = "extra_mute_seconds"

        /** Broadcast the ringing Activity listens for, so it closes when the
         *  alarm is dismissed/snoozed from the notification. */
        const val ACTION_FINISH_RINGING_UI = "com.riseprotocol.app.FINISH_RINGING_UI"

        private const val CHANNEL_ID = "rise_protocol_alarm_v2"
        private const val LEGACY_CHANNEL_ID = "rise_protocol_alarm_channel"
        private const val NOTIFICATION_ID = 4200
        private const val SNOOZE_MINUTES = 5

        /** Silences sound + vibration for [seconds] (re-arming resets the
         *  timer). It always comes back on its own, so an abandoned mission
         *  cannot leave the alarm muted forever. */
        fun mute(context: Context, seconds: Int) {
            val intent = Intent(context, AlarmRingService::class.java).apply {
                action = ACTION_MUTE
                putExtra(EXTRA_MUTE_SECONDS, seconds)
            }
            context.startService(intent)
        }

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

    // Mute-while-solving state. The volume ramp checks `muted` so it cannot
    // un-mute the alarm mid-answer.
    @Volatile private var muted = false
    private var rampVolume = 0.35f
    private val unmuteRunnable = Runnable { unmute() }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_RINGING, ACTION_DISMISS -> {
                stopSelfCleanly()
                return START_NOT_STICKY
            }
            ACTION_SNOOZE -> {
                val id = intent?.getIntExtra(AlarmReceiver.EXTRA_ID, -1) ?: -1
                if (id != -1) {
                    val stored = AlarmScheduler.readAll(this).find { it.id == id }
                    val minutes = stored?.snoozeMinutes ?: SNOOZE_MINUTES
                    AlarmScheduler.schedule(
                        this,
                        AlarmScheduler.Trigger(
                            id,
                            System.currentTimeMillis() + minutes * 60_000L,
                            intent?.getStringExtra(AlarmReceiver.EXTRA_LABEL) ?: "",
                            intent?.getStringExtra(AlarmReceiver.EXTRA_MISSION) ?: "none",
                            minutes,
                        ),
                    )
                    AlarmLog.add(this, "snoozed from the notification (id=$id, ${minutes}m)")
                    Toast.makeText(this, "Snoozed - ringing again in $minutes min", Toast.LENGTH_LONG).show()
                }
                stopSelfCleanly()
                return START_NOT_STICKY
            }
            ACTION_MUTE -> {
                if (player == null && vibrator == null) {
                    // Nothing is ringing, so do not leave an idle service behind.
                    stopSelf()
                    return START_NOT_STICKY
                }
                muteFor(intent?.getIntExtra(EXTRA_MUTE_SECONDS, 15) ?: 15)
                return START_STICKY
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
        // Try the direct launch FIRST. Android grants a short background-
        // activity-launch window when an alarm-clock broadcast is delivered;
        // doing the slower setup below (notification, MediaPlayer, vibrator)
        // before this call can burn that window and make it fail.
        AlarmLog.add(this, "ring service started (id=$id, mission=$mission)")
        try {
            startActivity(ringingActivityIntent(id, label, mission))
            AlarmLog.add(this, "direct screen launch: OK")
        } catch (e: Exception) {
            // Expected when the window has lapsed or the OEM blocks it; the
            // full-screen-intent notification below is the guaranteed path.
            AlarmLog.add(this, "direct screen launch blocked: ${e.javaClass.simpleName}")
        }

        acquireWakeLock()
        createChannelIfNeeded()
        startForeground(NOTIFICATION_ID, buildNotification(id, label, mission))
        val fsiOk = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).canUseFullScreenIntent()
        } else {
            true
        }
        AlarmLog.add(this, "notification posted (fullScreenIntentAllowed=$fsiOk)")
        startAudio()
        startVibration()
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
                    val v = if (muted) 0f else 0.35f
                    it.setVolume(v, v)
                    it.start()
                    AlarmLog.add(this@AlarmRingService, "alarm sound playing")
                }
                setOnErrorListener { _, what, extra ->
                    AlarmLog.add(this@AlarmRingService, "AUDIO ERROR what=$what extra=$extra")
                    true
                }
                prepareAsync()
            }
        } catch (_: Exception) {
            // No audio — vibration + the notification still carry the alarm.
            player?.release()
            player = null
        }

        // ~5-second ramp from a gentle start to full volume (skipped while muted).
        rampVolume = 0.35f
        val ramp = object : Runnable {
            override fun run() {
                rampVolume = (rampVolume + 0.16f).coerceAtMost(1f)
                if (!muted) {
                    try {
                        player?.setVolume(rampVolume, rampVolume)
                    } catch (_: Exception) {
                    }
                }
                if (rampVolume < 1f) handler.postDelayed(this, 1200)
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
            .setContentText("Tap to open your alarm")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(open, true)
            .setContentIntent(open)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(0, "Snooze", servicePendingIntent(ACTION_SNOOZE, id, label, mission))
            .addAction(
                0,
                if (mission == "none") "Dismiss" else "Solve to dismiss",
                // A mission alarm must not be dismissable from the shade, or the
                // mission is pointless — that button opens the ringing screen.
                if (mission == "none") servicePendingIntent(ACTION_DISMISS, id, label, mission) else open,
            )
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

    private fun muteFor(seconds: Int) {
        muted = true
        try {
            player?.setVolume(0f, 0f)
        } catch (_: Exception) {
        }
        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        }
        handler.removeCallbacks(unmuteRunnable)
        handler.postDelayed(unmuteRunnable, seconds.coerceIn(3, 120) * 1000L)
    }

    private fun unmute() {
        if (!muted) return
        muted = false
        try {
            player?.setVolume(rampVolume, rampVolume)
        } catch (_: Exception) {
        }
        startVibration()
        AlarmLog.add(this, "no input for a while - alarm resumed")
    }

    private fun teardown() {
        muted = false
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
        AlarmLog.add(this, "ring service stopping")
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
