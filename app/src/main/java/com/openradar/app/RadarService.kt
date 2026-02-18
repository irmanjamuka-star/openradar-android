package com.openradar.app

import android.app.*
import android.content.*
import android.graphics.PixelFormat
import android.os.*
import android.view.*
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.app.NotificationCompat

class RadarService : Service() {

    private lateinit var windowManager: WindowManager
    private lateinit var webView: WebView
    private var overlayView: View? = null

    override fun onCreate() {
        super.onCreate()
        startForegroundServiceNotification()
        startBackendBinary()
        createOverlay()
    }

    private fun startBackendBinary() {
        try {
            val file = File(filesDir, "openradar")
            assets.open("openradar-android-prod").use { input ->
                file.outputStream().use { output -> input.copyTo(output) }
            }
            file.setExecutable(true)

            Runtime.getRuntime().exec(file.absolutePath)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun createOverlay() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        webView = WebView(this)
        webView.settings.javaScriptEnabled = true
        webView.webViewClient = WebViewClient()
        webView.loadUrl("http://127.0.0.1:5001")

        val params = WindowManager.LayoutParams(
            600,
            600,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.START
        params.x = 100
        params.y = 100

        overlayView = webView
        windowManager.addView(overlayView, params)

        makeDraggable(params)
    }

    private fun makeDraggable(params: WindowManager.LayoutParams) {
        overlayView?.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f

            override fun onTouch(v: View?, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.x = initialX + (event.rawX - initialTouchX).toInt()
                        params.y = initialY + (event.rawY - initialTouchY).toInt()
                        windowManager.updateViewLayout(overlayView, params)
                        return true
                    }
                }
                return false
            }
        })
    }

    private fun startForegroundServiceNotification() {
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

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("OpenRadar Running")
            .setContentText("Radar overlay aktif")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .build()

        startForeground(1, notification)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        overlayView?.let { windowManager.removeView(it) }
        super.onDestroy()
    }
}
