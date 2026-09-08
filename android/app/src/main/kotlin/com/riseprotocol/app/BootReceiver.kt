package com.riseprotocol.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-arms every persisted alarm after a reboot (or after the app is
 * reinstalled/updated, via MY_PACKAGE_REPLACED) — this is what makes alarms
 * survive a phone restart *without* waiting for the user to reopen the app,
 * and without needing Dart/Flutter to spin up at boot.
 *
 * Known limitation (fine for this phase, called out in the README): this
 * only has the *next single* trigger time that was persisted at schedule
 * time, not the full repeat-day rule. If the device was off long enough
 * that a repeating alarm's stored trigger is now in the past, this skips
 * it rather than guessing the next occurrence — the app recomputes and
 * re-syncs correctly the next time it's opened (see AlarmScheduler.resyncAll
 * in lib/core/alarm_scheduler.dart). A production build should persist the
 * repeat rule too so BootReceiver can roll it forward correctly.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        val now = System.currentTimeMillis()
        val triggers = AlarmScheduler.readAll(context)
        for (trigger in triggers) {
            if (trigger.triggerAtMillis > now) {
                AlarmScheduler.schedule(context, trigger)
            }
        }
    }
}
