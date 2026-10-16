package com.cirengindi.owner;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.webkit.JavascriptInterface;

public final class NativeBridge {
    private final Activity activity;
    private final SecureSessionStore sessionStore;

    NativeBridge(Activity activity, SecureSessionStore sessionStore) {
        this.activity = activity;
        this.sessionStore = sessionStore;
    }

    @JavascriptInterface public String getSession() { return sessionStore.load(); }

    @JavascriptInterface
    public void saveSession(String json) {
        if (json == null || json.length() > 20000) throw new IllegalArgumentException("Invalid session");
        sessionStore.save(json);
    }

    @JavascriptInterface public void clearSession() { sessionStore.clear(); }

    @JavascriptInterface public String appVersion() { return "1.0.0-test"; }

    @JavascriptInterface
    public void openUrl(String url) {
        if (url == null) return;
        Uri uri = Uri.parse(url);
        if (!"https".equalsIgnoreCase(uri.getScheme())) return;
        activity.runOnUiThread(() -> {
            try { activity.startActivity(new Intent(Intent.ACTION_VIEW, uri)); } catch (Exception ignored) {}
        });
    }
}
