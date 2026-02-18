package com.openradar.app;

import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import androidx.appcompat.app.AppCompatActivity;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

public class MainActivity extends AppCompatActivity {

    private Process radarProcess;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        WebView webView = new WebView(this);
        setContentView(webView);

        webView.getSettings().setJavaScriptEnabled(true);
        webView.setWebViewClient(new WebViewClient());

        startRadarBinary();

        webView.postDelayed(() -> {
            webView.loadUrl("http://127.0.0.1:5001");
        }, 2000);
    }

    private void startRadarBinary() {
        try {
            File file = new File(getFilesDir(), "openradar-android");

            if (!file.exists()) {
                InputStream inputStream = getAssets().open("openradar-android");
                FileOutputStream outputStream = new FileOutputStream(file);

                byte[] buffer = new byte[4096];
                int length;
                while ((length = inputStream.read(buffer)) > 0) {
                    outputStream.write(buffer, 0, length);
                }

                outputStream.flush();
                outputStream.close();
                inputStream.close();
            }

            file.setExecutable(true);

            radarProcess = Runtime.getRuntime().exec(file.getAbsolutePath());

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (radarProcess != null) {
            radarProcess.destroy();
        }
    }
}
