package com.riseprotocol.app

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Shared handler for the `riseprotocol.app/alarm` channel, registered by
 * both MainActivity (normal app usage — creating/editing/testing alarms)
 * and AlarmRingingActivity (the ringing screen's dismiss/snooze calls).
 * Keeping this in one place means RingingScreen's Dart code works
 * identically no matter which native Activity is hosting it.
 */
object AlarmMethodChannel {
    const val NAME = "riseprotocol.app/alarm"

    fun handle(
        context: Context,
        call: MethodCall,
        result: MethodChannel.Result,
        onHandledTerminal: (() -> Unit)? = null
    ) {
        when (call.method) {
            "scheduleAlarm" -> {
                val id = call.argument<Int>("id") ?: return result.error("bad_args", "missing id", null)
                val triggerAt = (call.argument<Number>("triggerAtMillis"))?.toLong()
                    ?: return result.error("bad_args", "missing triggerAtMillis", null)
                val label = call.argument<String>("label") ?: ""
                val mission = call.argument<String>("missionType") ?: "none"
                AlarmScheduler.schedule(
                    context,
                    AlarmScheduler.Trigger(id, triggerAt, label, mission)
                )
                result.success(null)
            }

            "cancelAlarm" -> {
                val id = call.argument<Int>("id") ?: return result.error("bad_args", "missing id", null)
                AlarmScheduler.cancel(context, id)
                result.success(null)
            }

            "canScheduleExactAlarms" -> {
                result.success(AlarmScheduler.canScheduleExactAlarms(context))
            }

            "openExactAlarmSettings" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                        data = Uri.parse("package:${context.packageName}")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                }
                result.success(null)
            }

            "requestIgnoreBatteryOptimizations" -> {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!powerManager.isIgnoringBatteryOptimizations(context.packageName)) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${context.packageName}")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                }
                result.success(null)
            }

            "isIgnoringBatteryOptimizations" -> {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(powerManager.isIgnoringBatteryOptimizations(context.packageName))
            }

            "stopRingingService" -> {
                AlarmRingService.stop(context)
                result.success(null)
            }

            "dismissRinging" -> {
                AlarmRingService.stop(context)
                onHandledTerminal?.invoke()
                result.success(null)
            }

            "snoozeRinging" -> {
                val id = call.argument<Int>("id") ?: return result.error("bad_args", "missing id", null)
                val snoozeMinutes = call.argument<Int>("snoozeMinutes") ?: 5
                val existing = AlarmScheduler.readAll(context).find { it.id == id }
                val newTrigger = AlarmScheduler.Trigger(
                    id = id,
                    triggerAtMillis = System.currentTimeMillis() + snoozeMinutes * 60_000L,
                    label = existing?.label ?: "",
                    missionType = existing?.missionType ?: "math"
                )
                AlarmScheduler.schedule(context, newTrigger)
                AlarmRingService.stop(context)
                onHandledTerminal?.invoke()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
