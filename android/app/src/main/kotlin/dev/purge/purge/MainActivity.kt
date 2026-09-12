package dev.purge.purge

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "dev.purge.app/disk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDiskInfo" -> {
                        val path = call.argument<String>("path") ?: filesDir.absolutePath
                        try {
                            val stat = StatFs(path)
                            val total = stat.totalBytes
                            val free = stat.availableBytes
                            result.success(
                                hashMapOf(
                                    "total" to total,
                                    "free" to free,
                                    "used" to (total - free),
                                ),
                            )
                        } catch (e: Exception) {
                            result.error("stat_failed", e.message, null)
                        }
                    }
                    "requestStoragePermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            if (Environment.isExternalStorageManager()) {
                                result.success(true)
                            } else {
                                try {
                                    val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                                    intent.data = Uri.parse("package:$packageName")
                                    startActivity(intent)
                                } catch (_: Exception) {
                                    startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                                }
                                result.success(false)
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
