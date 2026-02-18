package com.openradar.app

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.*
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import kotlin.math.abs

class OverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private lateinit var overlayView: FrameLayout
    private lateinit var webView: WebView
    private lateinit var params: WindowManager.LayoutParams

    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f

    override fun onCreate() {
        super.onCreate()

        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        createOverlay()
    }

    private fun createOverlay() {

        overlayView = FrameLayout(this)

        webView = WebView(this)

        val webSettings: WebSettings = webView.settings
        webSettings.javaScriptEnabled = true
        webSettings.domStorageEnabled = true
        webSettings.allowFileAccess = true
        webSettings.allowContentAccess = true
        webSettings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW

        webView.setBackgroundColor(0x00000000) // transparent
        webView.webViewClient = WebViewClient()

        webView.loadUrl("http://127.0.0.1:5001")

        overlayView.addView(
            webView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        val layoutFlag =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE

        params = WindowManager.LayoutParams(
            900, // width
            900, // height
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.START
        params.x = 100
        params.y = 100
        params.alpha = 0.95f // opacity default

        windowManager.addView(overlayView, params)

        setupDrag()
    }

    private fun setupDrag() {
        overlayView.setOnTouchListener { _, event ->

            when (event.action) {

                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    return@setOnTouchListener true
                }

                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager.updateViewLayout(overlayView, params)
                    return@setOnTouchListener true
                }

                MotionEvent.ACTION_UP -> {
                    val dx = abs(event.rawX - initialTouchX)
                    val dy = abs(event.rawY - initialTouchY)
                    if (dx < 10 && dy < 10) {
                        // Tap event bisa dipakai nanti untuk toggle UI
                    }
                    return@setOnTouchListener true
                }
            }

            false
        }
    }

    // OPTIONAL: bisa dipanggil nanti untuk ubah opacity
    fun setOpacity(value: Float) {
        params.alpha = value
        windowManager.updateViewLayout(overlayView, params)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::overlayView.isInitialized) {
            windowManager.removeView(overlayView)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
