package com.mrkedow.ironetch

import android.app.AlarmManager
import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.os.Build
import android.os.Environment
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipInputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.mrkedow.ironetch/epub"
    private val hapticsChannelName = "com.mrkedow.ironetch/haptics"
    private val remindersChannelName = "com.mrkedow.ironetch/reminders"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hapticsChannelName)
            .setMethodCallHandler { call, result ->
                try {
                    if (vibrateHaptic(call.method)) {
                        result.success(true)
                    } else {
                        result.notImplemented()
                    }
                } catch (error: Exception) {
                    Log.e("IronHaptics", "failed kind=${call.method}", error)
                    result.error("haptic_failed", error.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, remindersChannelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "schedule" -> {
                            val time = call.argument<String>("time") ?: "20:00"
                            result.success(ReminderScheduler.schedule(this, time))
                        }

                        "cancel" -> {
                            ReminderScheduler.cancel(this)
                            result.success(true)
                        }

                        "canScheduleExact" -> {
                            val alarm = getSystemService(
                                Context.ALARM_SERVICE,
                            ) as AlarmManager
                            result.success(
                                Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                                    alarm.canScheduleExactAlarms(),
                            )
                        }

                        "requestExact" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                try {
                                    startActivity(
                                        Intent(
                                            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                            Uri.parse("package:$packageName"),
                                        ),
                                    )
                                    result.success(true)
                                } catch (_: Exception) {
                                    result.success(false)
                                }
                            } else {
                                result.success(true)
                            }
                        }

                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("reminder_failed", error.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "extractAsset" -> {
                        val assetPath = call.argument<String>("assetPath")
                        val target = call.argument<String>("target")
                        if (assetPath == null || target == null) {
                            result.error("bad_args", "assetPath and target are required", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                assets.open(assetPath).use { input ->
                                    extractZip(ZipInputStream(BufferedInputStream(input)), target)
                                }
                                runOnUiThread { result.success(true) }
                            } catch (error: Exception) {
                                runOnUiThread {
                                    result.error("extract_asset_failed", error.message, null)
                                }
                            }
                        }.start()
                    }

                    "extractFile" -> {
                        val filePath = call.argument<String>("filePath")
                        val target = call.argument<String>("target")
                        if (filePath == null || target == null) {
                            result.error("bad_args", "filePath and target are required", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                File(filePath).inputStream().use { input ->
                                    extractZip(ZipInputStream(BufferedInputStream(input)), target)
                                }
                                runOnUiThread { result.success(true) }
                            } catch (error: Exception) {
                                runOnUiThread {
                                    result.error("extract_file_failed", error.message, null)
                                }
                            }
                        }.start()
                    }

                    "enqueueDownload" -> {
                        val url = call.argument<String>("url")
                        val fileName = call.argument<String>("fileName") ?: "download.bin"
                        val title = call.argument<String>("title") ?: "下载内置书"
                        val description =
                            call.argument<String>("description") ?: "正在下载《北科·健身全书》，可切到后台继续"
                        if (url == null) {
                            result.error("bad_args", "url is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(enqueueDownload(url, fileName, title, description))
                        } catch (error: Exception) {
                            result.error("download_failed", error.message, null)
                        }
                    }

                    "downloadStatus" -> {
                        val id = call.argument<Number>("downloadId")?.toLong()
                        if (id == null) {
                            result.error("bad_args", "downloadId is required", null)
                            return@setMethodCallHandler
                        }
                        result.success(downloadStatus(id))
                    }

                    "externalDownloadPath" -> {
                        val fileName = call.argument<String>("fileName") ?: "download.bin"
                        result.success(externalDownloadFile(fileName).absolutePath)
                    }

                    "deleteExternalDownload" -> {
                        val fileName = call.argument<String>("fileName") ?: "download.bin"
                        try {
                            externalDownloadFile(fileName).delete()
                        } catch (_: Exception) {
                        }
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun vibrateHaptic(kind: String): Boolean {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val effect = when (kind) {
                "select" ->
                    VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK)
                "light" ->
                    VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK)
                "medium" -> VibrationEffect.createOneShot(35L, 190)
                "heavy" -> VibrationEffect.createOneShot(55L, 255)
                else -> return false
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                vibrator.vibrate(
                    effect,
                    VibrationAttributes.createForUsage(
                        VibrationAttributes.USAGE_HARDWARE_FEEDBACK,
                    ),
                )
            } else {
                vibrator.vibrate(effect)
            }
            return true
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = when (kind) {
                "select" -> VibrationEffect.createOneShot(14L, 120)
                "light" -> VibrationEffect.createOneShot(22L, 150)
                "medium" -> VibrationEffect.createOneShot(35L, 190)
                "heavy" -> VibrationEffect.createOneShot(55L, 255)
                else -> return false
            }
            vibrator.vibrate(effect)
            return true
        }
        @Suppress("DEPRECATION")
        val duration = when (kind) {
            "select" -> 14L
            "light" -> 22L
            "medium" -> 35L
            "heavy" -> 55L
            else -> return false
        }
        @Suppress("DEPRECATION")
        vibrator.vibrate(duration)
        return true
    }

    private fun externalDownloadFile(fileName: String): File {
        val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: File(cacheDir, "downloads")
        if (!dir.exists()) dir.mkdirs()
        return File(dir, fileName)
    }

    private fun enqueueDownload(
        url: String,
        fileName: String,
        title: String,
        description: String,
    ): Map<String, Any> {
        val target = externalDownloadFile(fileName)
        if (target.exists()) target.delete()
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle(title)
            .setDescription(description)
            .setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
            )
            .setDestinationInExternalFilesDir(
                this,
                Environment.DIRECTORY_DOWNLOADS,
                fileName,
            )
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
            ?: return emptyMap()
        val id = manager.enqueue(request)
        return mapOf("id" to id, "path" to target.absolutePath)
    }

    private fun downloadStatus(id: Long): Map<String, Any> {
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val cursor = manager.query(DownloadManager.Query().setFilterById(id))
        if (cursor == null) {
            return mapOf("status" to -1, "downloaded" to 0L, "total" to 0L)
        }
        try {
            if (cursor.moveToFirst()) {
                val status = cursor.getInt(
                    cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS),
                )
                val downloaded = cursor.getLong(
                    cursor.getColumnIndexOrThrow(
                        DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR,
                    ),
                )
                val total = cursor.getLong(
                    cursor.getColumnIndexOrThrow(
                        DownloadManager.COLUMN_TOTAL_SIZE_BYTES,
                    ),
                )
                return mapOf(
                    "status" to status,
                    "downloaded" to downloaded,
                    "total" to total,
                )
            }
        } finally {
            cursor.close()
        }
        return mapOf("status" to -1, "downloaded" to 0L, "total" to 0L)
    }

    private fun extractZip(zip: ZipInputStream, targetPath: String) {
        val root = File(targetPath)
        if (root.exists()) root.deleteRecursively()
        if (!root.mkdirs() && !root.isDirectory) {
            throw IllegalStateException("无法创建目录: ${root.absolutePath}")
        }
        val rootPrefix = root.canonicalPath + File.separator
        var entry = zip.nextEntry
        while (entry != null) {
            val output = File(root, entry.name)
            if (!output.canonicalPath.startsWith(rootPrefix)) {
                throw SecurityException("非法压缩包路径: ${entry.name}")
            }
            if (entry.isDirectory) {
                output.mkdirs()
            } else {
                output.parentFile?.mkdirs()
                FileOutputStream(output).use { out -> zip.copyTo(out) }
            }
            zip.closeEntry()
            entry = zip.nextEntry
        }
        File(root, ".ft_extracted").writeText("ok")
    }
}
