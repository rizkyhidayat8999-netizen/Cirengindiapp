package com.cirengindi.owner;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.webkit.WebResourceRequest;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.stream.Collectors;

public final class MainActivity extends Activity {
    private WebView webView;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);

        SecureSessionStore store = new SecureSessionStore(this);
        webView = new WebView(this);
        webView.setBackgroundColor(Color.rgb(255, 248, 241));

        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(false);
        s.setDatabaseEnabled(false);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        s.setJavaScriptCanOpenWindowsAutomatically(false);
        s.setSupportMultipleWindows(false);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        s.setSafeBrowsingEnabled(true);
        s.setUserAgentString(s.getUserAgentString() + " CirengIndiOwner/1.0");

        webView.addJavascriptInterface(new NativeBridge(this, store), "Native");
        // Enable confirmation/password prompts used in owner operations.
        webView.setWebChromeClient(new WebChromeClient());
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return !"app.cirengindi.owner.local".equalsIgnoreCase(request.getUrl().getHost());
            }
        });

        setContentView(webView);
        try (BufferedReader r = new BufferedReader(new InputStreamReader(
                getAssets().open("index.html"), StandardCharsets.UTF_8))) {
            String html = r.lines().collect(Collectors.joining("\n"));
            webView.loadDataWithBaseURL("https://app.cirengindi.owner.local/", html, "text/html", "UTF-8", null);
        } catch (Exception e) {
            webView.loadData("<h2>Cireng Indi Owner</h2><p>Gagal memuat aplikasi.</p>", "text/html", "UTF-8");
        }
    }

    @Override
    protected void onDestroy() {
        if (webView != null) {
            webView.removeJavascriptInterface("Native");
            webView.destroy();
        }
        super.onDestroy();
    }
}