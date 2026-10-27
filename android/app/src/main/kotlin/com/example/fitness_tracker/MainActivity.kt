package com.example.fitness_tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipInputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.MrKedow.FT/epub"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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

                    else -> result.notImplemented()
                }
            }
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
