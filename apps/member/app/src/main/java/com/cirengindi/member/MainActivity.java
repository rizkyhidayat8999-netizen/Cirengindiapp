package com.cirengindi.member;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebChromeClient;
import android.webkit.ValueCallback;
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
    private static final int PROOF_PICKER_REQUEST = 4391;
    private ValueCallback<Uri[]> pendingImageSelection;

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
        settings.setAllowContentAccess(true); // Required for user-selected proof-of-transfer photos
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setSupportMultipleWindows(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setSafeBrowsingEnabled(true);
        settings.setUserAgentString(settings.getUserAgentString() + " CirengIndi/1.1");
        webView.addJavascriptInterface(new NativeBridge(this, sessionStore), "Native");
        webView.setWebChromeClient(new WebChromeClient(){
            @Override public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params){
                if (pendingImageSelection != null) pendingImageSelection.onReceiveValue(null);
                pendingImageSelection = callback;
                try {
                    Intent choose = new Intent(Intent.ACTION_GET_CONTENT);
                    choose.addCategory(Intent.CATEGORY_OPENABLE);
                    choose.setType("image/*");
                    startActivityForResult(Intent.createChooser(choose, "Pilih foto bukti transfer"), PROOF_PICKER_REQUEST);
                    return true;
                } catch(Exception ex) {
                    pendingImageSelection = null;
                    callback.onReceiveValue(null);
                    return true;
                }
            }
        });
        webView.setWebViewClient(new WebViewClient() {
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                Uri u = request.getUrl();
                String path = u.getPath();
                if ("app.cirengindi.local".equalsIgnoreCase(u.getHost()) && path != null
                        && path.startsWith("/assets/") && !path.contains("..")) {
                    try {
                        InputStream asset = getAssets().open(path.substring(1));
                        String mime = path.endsWith(".png") ? "image/png" : "image/webp";
                        return new WebResourceResponse(mime, null, asset);
                    } catch (Exception ignored) {}
                }
                return super.shouldInterceptRequest(view, request);
            }
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
        RemoteHtmlUpdater.start(this, readAsset("index.html"), html ->
            webView.loadDataWithBaseURL("https://app.cirengindi.local/", html, "text/html", "UTF-8", null));
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

    @Override protected void onActivityResult(int requestCode,int resultCode, Intent data) {
        super.onActivityResult(requestCode,resultCode,data);
        if (requestCode == PROOF_PICKER_REQUEST && pendingImageSelection != null) {
            Uri[] values = resultCode == RESULT_OK && data != null && data.getData() != null
                ? new Uri[]{data.getData()} : null;
            pendingImageSelection.onReceiveValue(values);
            pendingImageSelection = null;
        }
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