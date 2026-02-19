package com.openradar.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.*
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.ImageButton
import android.widget.SeekBar
import androidx.core.app.NotificationCompat

class OverlayService : Service() {

    companion object {
        init {
            System.loadLibrary("radar")
        }
    }

    external fun StartRadar()
    external fun StopRadar()

    private lateinit var windowManager: WindowManager
    private lateinit var overlayView: View
    private lateinit var webView: WebView

    override fun onCreate() {
        super.onCreate()

        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }

        startForegroundNotification()
        StartRadar()
        createOverlay()
    }

    // =====================================
    // FOREGROUND SERVICE
    // =====================================
    private fun startForegroundNotification() {

        val channelId = "radar_overlay_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "OpenRadar Overlay Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("OpenRadar Running")
            .setContentText("Radar aktif sebagai floating overlay")
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

    // =====================================
    // CREATE OVERLAY UI
    // =====================================
    private fun createOverlay() {

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        overlayView = inflater.inflate(R.layout.overlay_layout, null)

        webView = overlayView.findViewById(R.id.radarWebView)

        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.webViewClient = WebViewClient()

        // Load radar setelah backend siap
        webView.postDelayed({
            webView.loadUrl("http://127.0.0.1:5001")
        }, 1500)

        setupControls()

        val params = WindowManager.LayoutParams(
            800,
            800,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.START
        params.x = 100
        params.y = 200

        windowManager.addView(overlayView, params)
        makeDraggable(overlayView, params)
    }

    // =====================================
    // DRAG SUPPORT
    // =====================================
    private fun makeDraggable(view: View, params: WindowManager.LayoutParams) {

        view.setOnTouchListener(object : View.OnTouchListener {

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

    // =====================================
    // CONTROLS (Close + Opacity)
    // =====================================
    private fun setupControls() {

        val closeBtn: ImageButton = overlayView.findViewById(R.id.btnClose)
        val opacitySeek: SeekBar = overlayView.findViewById(R.id.seekOpacity)

        closeBtn.setOnClickListener {
            stopSelf()
        }

        opacitySeek.max = 100
        opacitySeek.progress = 100

        opacitySeek.setOnSeekBarChangeListener(object :
            SeekBar.OnSeekBarChangeListener {

            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                overlayView.alpha = progress / 100f
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })
    }

    override fun onDestroy() {
        StopRadar()
        windowManager.removeView(overlayView)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
