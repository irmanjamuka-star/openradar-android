package com.openradar.app

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import java.io.File
import java.io.FileOutputStream

class RadarService : Service() {

    private var process: Process? = null

    override fun onCreate() {
        super.onCreate()
        startForegroundService()
        startBackend()
    }

    private fun startBackend() {
        try {
            val binaryName = "openradar-android-prod"
            val outFile = File(filesDir, binaryName)

            if (!outFile.exists()) {
                assets.open(binaryName).use { input ->
                    FileOutputStream(outFile).use { output ->
                        input.copyTo(output)
                    }
                }
                outFile.setExecutable(true)
            }

            process = ProcessBuilder(outFile.absolutePath)
                .redirectErrorStream(true)
                .start()

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startForegroundService() {
        val channelId = "radar_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Radar Background Service",
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

        startForeground(1, notification)
    }

    override fun onDestroy() {
        process?.destroy()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
