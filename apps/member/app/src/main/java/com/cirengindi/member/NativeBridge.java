package com.cirengindi.member;

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
    @JavascriptInterface public void saveSession(String json) {
        if (json == null || json.length() > 20000) throw new IllegalArgumentException("Invalid session");
        sessionStore.save(json);
    }
    @JavascriptInterface public void clearSession() { sessionStore.clear(); }
    @JavascriptInterface public String appVersion() { return "2.1.0"; }
    @JavascriptInterface public boolean supportsCustomerLocation() { return activity instanceof MainActivity; }
    @JavascriptInterface public void requestCustomerLocation() {
        activity.runOnUiThread(() -> {
            if (activity instanceof MainActivity) ((MainActivity) activity).requestCustomerLocation();
        });
    }
    @JavascriptInterface public void shareText(String text) {
        if (text == null || text.trim().isEmpty()) return;
        activity.runOnUiThread(() -> {
            Intent send = new Intent(Intent.ACTION_SEND);
            send.setType("text/plain");
            send.putExtra(Intent.EXTRA_TEXT, text);
            activity.startActivity(Intent.createChooser(send, "Bagikan"));
        });
    }
    @JavascriptInterface public void openUrl(String url) {
        if (url == null) return;
        Uri uri = Uri.parse(url);
        String scheme = uri.getScheme();
        if (!"https".equalsIgnoreCase(scheme) && !"http".equalsIgnoreCase(scheme)) return;
        activity.runOnUiThread(() -> {
            String host = uri.getHost() == null ? "" : uri.getHost().toLowerCase(java.util.Locale.ROOT);
            String path = uri.getPath() == null ? "" : uri.getPath();
            boolean isMaps = host.equals("share.google") || host.equals("maps.google.com") ||
                    (host.equals("www.google.com") && path.startsWith("/maps"));
            if (isMaps) {
                try {
                    Intent maps = new Intent(Intent.ACTION_VIEW, uri);
                    maps.setPackage("com.google.android.apps.maps");
                    activity.startActivity(maps);
                    return;
                } catch (Exception ignored) {
                    // Google Maps is optional. Its normal HTTPS link still works in a browser.
                }
            }
            try { activity.startActivity(new Intent(Intent.ACTION_VIEW, uri)); }
            catch (Exception ignored) { /* No handler installed */ }
        });
    }
}
