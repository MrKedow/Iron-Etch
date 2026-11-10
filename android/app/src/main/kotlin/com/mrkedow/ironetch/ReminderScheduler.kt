package com.mrkedow.ironetch

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object ReminderScheduler {
    private const val REQUEST_CODE = 7301
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_ENABLED = "flutter.reminder_enabled"
    private const val KEY_TIME = "flutter.reminder_time"

    fun schedule(context: Context, time: String): Boolean {
        val parts = time.split(":")
        val hour = (parts.getOrNull(0)?.toIntOrNull() ?: 20).coerceIn(0, 23)
        val minute = (parts.getOrNull(1)?.toIntOrNull() ?: 0).coerceIn(0, 59)
        val now = Calendar.getInstance()
        val trigger = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (before(now)) add(Calendar.DAY_OF_YEAR, 1)
        }
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(context)
        alarm.cancel(pending)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            alarm.canScheduleExactAlarms()
        ) {
            try {
                alarm.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    trigger.timeInMillis,
                    pending,
                )
                return true
            } catch (_: SecurityException) {
                // Permission can be revoked between the check and the call.
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarm.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                trigger.timeInMillis,
                pending,
            )
        } else {
            @Suppress("DEPRECATION")
            alarm.set(AlarmManager.RTC_WAKEUP, trigger.timeInMillis, pending)
        }
        return true
    }

    fun cancel(context: Context) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarm.cancel(pendingIntent(context))
    }

    fun rescheduleFromPreferences(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) {
            cancel(context)
            return
        }
        schedule(context, prefs.getString(KEY_TIME, "20:00") ?: "20:00")
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
