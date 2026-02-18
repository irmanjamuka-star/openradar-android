package com.openradar.app

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import java.io.File
import java.io.FileOutputStream

class RadarService : Service() {

    private var process: Process? = null
    private val binaryName = "openradar-android-prod"

    override fun onCreate() {
        super.onCreate()
        startForegroundRadarService()
        startBackend()
    }

    // ===============================
    // BACKEND START
    // ===============================
    private fun startBackend() {
        try {
            val outFile = File(filesDir, binaryName)

            // Copy binary from assets if not exists
            if (!outFile.exists()) {
                assets.open(binaryName).use { input ->
                    FileOutputStream(outFile).use { output ->
                        input.copyTo(output)
                    }
                }
            }

            // Always ensure executable
            outFile.setExecutable(true)

            process = ProcessBuilder(outFile.absolutePath)
                .redirectErrorStream(true)
                .start()

            // Auto-restart if backend crashes
            Thread {
                try {
                    process?.waitFor()
                    startBackend()
                } catch (_: Exception) {}
            }.start()

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // ===============================
    // FOREGROUND SERVICE (Android 12+ safe)
    // ===============================
    private fun startForegroundRadarService() {
        val channelId = "radar_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "OpenRadar Background Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification = Notification.Builder(this, channelId)
            .setContentTitle("OpenRadar Running")
            .setContentText("Radar backend aktif di background")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                1,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(1, notification)
        }
    }

    // ===============================
    // Prevent kill when swiped from recent
    // ===============================
    override fun onTaskRemoved(rootIntent: Intent?) {
        val restartIntent = Intent(applicationContext, RadarService::class.java)
        restartIntent.setPackage(packageName)
        startService(restartIntent)
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        process?.destroy()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
