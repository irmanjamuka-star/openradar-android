package com.openradar.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.*
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.SeekBar
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream

class OverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private lateinit var overlayView: View
    private lateinit var webView: WebView
    private var backendProcess: Process? = null

    override fun onCreate() {
        super.onCreate()

        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }

        startForegroundNotification()
        startBackend()
        createOverlay()
    }

    // ================================
    // FOREGROUND NOTIFICATION
    // ================================
    private fun startForegroundNotification() {
        val channelId = "radar_overlay_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "OpenRadar Background",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("OpenRadar Running")
            .setContentText("Radar aktif sebagai overlay")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()

        startForeground(1, notification)
    }

    // ================================
    // BACKEND START
    // ================================
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

            backendProcess = ProcessBuilder(outFile.absolutePath)
                .redirectErrorStream(true)
                .start()

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun restartBackend() {
        backendProcess?.destroy()
        startBackend()
        webView.postDelayed({
            webView.reload()
        }, 1500)
    }

    // ================================
    // CREATE OVERLAY UI
    // ================================
    private fun createOverlay() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
        overlayView = inflater.inflate(R.layout.overlay_layout, null)

        webView = overlayView.findViewById(R.id.radarWebView)

        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.webViewClient = WebViewClient()

        // Auto retry until backend ready
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

    // ================================
    // DRAG MOVEMENT
    // ================================
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

    // ================================
    // BUTTONS & OPACITY
    // ================================
    private fun setupControls() {

        val closeBtn: ImageButton = overlayView.findViewById(R.id.btnClose)
        val restartBtn: ImageButton = overlayView.findViewById(R.id.btnRestart)
        val opacitySeek: SeekBar = overlayView.findViewById(R.id.seekOpacity)

        closeBtn.setOnClickListener {
            stopSelf()
        }

        restartBtn.setOnClickListener {
            restartBackend()
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
        super.onDestroy()
        backendProcess?.destroy()
        windowManager.removeView(overlayView)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
