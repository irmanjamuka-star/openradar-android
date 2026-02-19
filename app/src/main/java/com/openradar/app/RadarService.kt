package com.openradar.app

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class RadarService : Service() {

    companion object {
        init {
            System.loadLibrary("radar")
        }
    }

    external fun StartRadar()
    external fun StopRadar()

    override fun onCreate() {
        super.onCreate()
        startForegroundRadarService()
        StartRadar()
    }

    // ===============================
    // FOREGROUND SERVICE (Android 12+ Safe)
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

    // Restart if user swipes app
    override fun onTaskRemoved(rootIntent: Intent?) {
        val restartIntent = Intent(applicationContext, RadarService::class.java)
        restartIntent.setPackage(packageName)
        startService(restartIntent)
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        StopRadar()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
