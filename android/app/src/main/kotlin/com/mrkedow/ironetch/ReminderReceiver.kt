package com.mrkedow.ironetch

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                ReminderScheduler.rescheduleFromPreferences(context)
                return
            }
        }
        showNotification(context)
        ReminderScheduler.rescheduleFromPreferences(context)
    }

    private fun showNotification(context: Context) {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "training_reminders"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "训练提醒",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "每天的训练提醒"
            }
            manager.createNotificationChannel(channel)
        }
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            7302,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("铁镌 · 训练提醒")
            .setContentText("今天也要镌刻进身体里。点击记录今天的训练。")
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setWhen(System.currentTimeMillis())
        manager.notify(7302, builder.build())
    }
}
