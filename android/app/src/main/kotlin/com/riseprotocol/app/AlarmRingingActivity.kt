package com.riseprotocol.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The screen the user actually sees when an alarm fires. Runs its own
 * [FlutterEngine] (Flutter supports multiple engines in one app) so it can
 * be launched directly by [AlarmRingService] with no dependency on
 * MainActivity's task/lifecycle — the whole point is that this works even
 * if the user force-swiped the main app away.
 *
 * `initialRoute` encodes the alarm id/label/mission as query params, parsed
 * by `onGenerateRoute` in lib/main.dart to build the `/ringing` route
 * directly — no MethodChannel round-trip needed to know what to show.
 */
class AlarmRingingActivity : FlutterActivity() {

    private var alarmId: Int = -1

    /** Closes this screen when the alarm is dismissed/snoozed from the
     *  notification (i.e. without going through the Flutter UI). */
    private val finishReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (!isFinishing) finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Must happen before super.onCreate/setContentView so the window is
        // configured before Flutter's SurfaceView attaches.
        showOverLockScreen()
        super.onCreate(savedInstanceState)

        alarmId = intent.getIntExtra(AlarmReceiver.EXTRA_ID, -1)

        val filter = IntentFilter(AlarmRingService.ACTION_FINISH_RINGING_UI)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(finishReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(finishReceiver, filter)
        }
    }

    override fun getInitialRoute(): String {
        val id = intent.getIntExtra(AlarmReceiver.EXTRA_ID, -1)
        val label = intent.getStringExtra(AlarmReceiver.EXTRA_LABEL) ?: ""
        val mission = intent.getStringExtra(AlarmReceiver.EXTRA_MISSION) ?: "none"
        val uri = Uri.Builder()
            .path("/ringing")
            .appendQueryParameter("id", id.toString())
            .appendQueryParameter("label", label)
            .appendQueryParameter("mission", mission)
            .build()
        return uri.toString()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Ringing screen calls back through the same channel name/methods as
        // MainActivity (dismissRinging/snoozeRinging) so RingingScreen's Dart
        // code doesn't need to know which native Activity is hosting it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AlarmMethodChannel.NAME)
            .setMethodCallHandler { call, result ->
                AlarmMethodChannel.handle(this, call, result, onHandledTerminal = { finish() })
            }
    }

    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(finishReceiver)
        } catch (_: Exception) {
        }
        AlarmRingService.stop(this)
        super.onDestroy()
    }
}
