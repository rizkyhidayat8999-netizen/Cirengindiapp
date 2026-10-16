package com.cirengindi.member;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.stream.Collectors;

public final class MainActivity extends Activity {
    private WebView webView;
    private String pendingDeepLink;

    @SuppressLint({"SetJavaScriptEnabled", "JavascriptInterface"})
    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        SecureSessionStore sessionStore = new SecureSessionStore(this);
        webView = new WebView(this);
        webView.setBackgroundColor(Color.rgb(255,248,241));
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(false);
        settings.setDatabaseEnabled(false);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setSupportMultipleWindows(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setSafeBrowsingEnabled(true);
        settings.setUserAgentString(settings.getUserAgentString() + " CirengIndi/1.1");
        webView.addJavascriptInterface(new NativeBridge(this, sessionStore), "Native");
        webView.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if ("app.cirengindi.local".equalsIgnoreCase(uri.getHost())) return false;
                String scheme = uri.getScheme();
                if ("https".equalsIgnoreCase(scheme) || "http".equalsIgnoreCase(scheme)) {
                    try { startActivity(new Intent(Intent.ACTION_VIEW, uri)); } catch (Exception ignored) {}
                }
                return true;
            }
            @Override public void onPageFinished(WebView view, String url) { deliverPendingDeepLink(); }
        });
        setContentView(webView);
        handleIntent(getIntent());
        webView.loadDataWithBaseURL("https://app.cirengindi.local/", readAsset("index.html"), "text/html", "UTF-8", null);
    }

    private String readAsset(String name) {
        try (InputStream stream = getAssets().open(name); BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))) {
            return reader.lines().collect(Collectors.joining("\n"));
        } catch (Exception error) {
            return "<html><body><h2>Cireng Indi</h2><p>Gagal memuat aplikasi.</p></body></html>";
        }
    }

    private void handleIntent(Intent intent) {
        if (intent == null || intent.getData() == null) return;
        pendingDeepLink = intent.getData().toString();
        deliverPendingDeepLink();
    }

    private void deliverPendingDeepLink() {
        if (webView == null || pendingDeepLink == null) return;
        String value = pendingDeepLink;
        pendingDeepLink = null;
        webView.evaluateJavascript("window.onNativeDeepLink && window.onNativeDeepLink(" + JSONObject.quote(value) + ");", null);
    }

    @Override protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntent(intent);
    }

    @Override public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack(); else super.onBackPressed();
    }

    @Override protected void onDestroy() {
        if (webView != null) {
            webView.removeJavascriptInterface("Native");
            webView.destroy();
        }
        super.onDestroy();
    }
}
