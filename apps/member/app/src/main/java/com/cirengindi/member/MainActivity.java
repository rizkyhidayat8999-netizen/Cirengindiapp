package com.cirengindi.member;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.pm.PackageManager;
import android.location.Address;
import android.location.Geocoder;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.os.Build;
import android.view.View;
import android.view.WindowInsets;
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
    private static final int CUSTOMER_LOCATION_REQUEST = 4392;
    private static final long GPS_TIMEOUT_MS = 16000L;
    private final Handler locationHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService geocoderExecutor = Executors.newSingleThreadExecutor();
    private LocationManager customerLocationManager;
    private LocationListener customerLocationListener;
    private Runnable customerLocationTimeout;
    private boolean customerLocationPending;
    private ValueCallback<Uri[]> pendingImageSelection;

    @SuppressLint({"SetJavaScriptEnabled", "JavascriptInterface"})
    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        SecureSessionStore sessionStore = new SecureSessionStore(this);
        webView = new WebView(this);
        webView.setBackgroundColor(Color.rgb(255,248,241));
        // Android 16 edge-to-edge: reserve physical status/navigation bar insets.
        if (Build.VERSION.SDK_INT >= 30) {
            getWindow().getDecorView().setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
            webView.setOnApplyWindowInsetsListener((view, insets) -> {
                android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars());
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom);
                return insets;
            });
        }
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


    /**
     * Location is requested only after pressing "Gunakan Lokasi Saya" in the Member UI.
     * Consent uses the Android runtime permission system; no background monitoring.
     * A reverse-geocoded address and its coordinates are returned only to the trusted
     * app-local WebView. The customer reviews/edits the result before saving it.
     */
    void requestCustomerLocation() {
        if (isFinishing() || isDestroyed() || customerLocationPending) return;
        customerLocationPending = true;
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED
                && checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            }, CUSTOMER_LOCATION_REQUEST);
            return;
        }
        startCustomerGps();
    }

    @Override public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode != CUSTOMER_LOCATION_REQUEST || !customerLocationPending) return;
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                || checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            startCustomerGps();
        } else {
            customerLocationError("PERMISSION_DENIED");
        }
    }

    @SuppressLint("MissingPermission")
    private void startCustomerGps() {
        if (!customerLocationPending) return;
        final boolean fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;
        final boolean coarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;
        if (!fine && !coarse) {
            customerLocationError("PERMISSION_DENIED");
            return;
        }
        customerLocationManager = (LocationManager) getSystemService(LOCATION_SERVICE);
        if (customerLocationManager == null) {
            customerLocationError("LOCATION_UNAVAILABLE");
            return;
        }
        boolean network = false, gps = false;
        try {
            network = customerLocationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER);
            gps = fine && customerLocationManager.isProviderEnabled(LocationManager.GPS_PROVIDER);
        } catch (Exception ignored) {}
        if (!network && !gps) {
            customerLocationError("LOCATION_DISABLED");
            return;
        }
        try {
            // A recent, accurate cached fix avoids making a customer wait unnecessarily.
            Location recent = null;
            for (String provider : new String[]{LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER}) {
                if (LocationManager.GPS_PROVIDER.equals(provider) && !gps) continue;
                if (LocationManager.NETWORK_PROVIDER.equals(provider) && !network) continue;
                Location candidate = customerLocationManager.getLastKnownLocation(provider);
                if (candidate == null) continue;
                long ageMs = (SystemClock.elapsedRealtimeNanos() - candidate.getElapsedRealtimeNanos()) / 1000000L;
                if (ageMs < 0 || ageMs > 90000L || (candidate.hasAccuracy() && candidate.getAccuracy() > 250f)) continue;
                if (recent == null || candidate.getAccuracy() < recent.getAccuracy()) recent = candidate;
            }
            if (recent != null) {
                deliverCustomerFix(recent);
                return;
            }
            customerLocationListener = new LocationListener() {
                @Override public void onLocationChanged(Location location) {
                    if (location != null) deliverCustomerFix(location);
                }
            };
            if (network) customerLocationManager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER, 500L, 0f, customerLocationListener, Looper.getMainLooper());
            if (gps) customerLocationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER, 500L, 0f, customerLocationListener, Looper.getMainLooper());
            customerLocationTimeout = () -> customerLocationError("LOCATION_TIMEOUT");
            locationHandler.postDelayed(customerLocationTimeout, GPS_TIMEOUT_MS);
        } catch (SecurityException error) {
            customerLocationError("PERMISSION_DENIED");
        } catch (Exception error) {
            customerLocationError("LOCATION_UNAVAILABLE");
        }
    }

    private void deliverCustomerFix(Location location) {
        if (!customerLocationPending) return;
        customerLocationPending = false;
        cleanupCustomerGps();
        final double latitude = location.getLatitude();
        final double longitude = location.getLongitude();
        final float accuracy = location.hasAccuracy() ? location.getAccuracy() : 0;
        geocoderExecutor.execute(() -> {
            JSONObject data = new JSONObject();
            try {
                data.put("status", "ok");
                data.put("latitude", latitude);
                data.put("longitude", longitude);
                data.put("accuracy", Math.round(accuracy));
                data.put("address_line", "");
                data.put("city", "");
                data.put("province", "");
                data.put("postal_code", "");
                if (Geocoder.isPresent()) {
                    Geocoder geocoder = new Geocoder(getApplicationContext(), new Locale("id", "ID"));
                    List<Address> addresses = geocoder.getFromLocation(latitude, longitude, 1);
                    if (addresses != null && !addresses.isEmpty()) {
                        Address a = addresses.get(0);
                        data.put("address_line", orEmpty(a.getAddressLine(0)));
                        String city = orEmpty(a.getSubAdminArea());
                        if (city.isEmpty()) city = orEmpty(a.getLocality());
                        data.put("city", city);
                        data.put("province", orEmpty(a.getAdminArea()));
                        data.put("postal_code", orEmpty(a.getPostalCode()));
                    }
                }
            } catch (Exception ignored) {
                // GPS coordinates remain available even if reverse geocoding fails.
            }
            runOnUiThread(() -> dispatchCustomerLocation(data));
        });
    }

    private static String orEmpty(String value) { return value == null ? "" : value; }

    private void customerLocationError(String reason) {
        if (!customerLocationPending) return;
        customerLocationPending = false;
        cleanupCustomerGps();
        JSONObject data = new JSONObject();
        try {
            data.put("status", "error");
            data.put("error", reason);
        } catch (Exception ignored) {}
        dispatchCustomerLocation(data);
    }

    private void cleanupCustomerGps() {
        if (customerLocationTimeout != null) {
            locationHandler.removeCallbacks(customerLocationTimeout);
            customerLocationTimeout = null;
        }
        if (customerLocationListener != null && customerLocationManager != null) {
            try { customerLocationManager.removeUpdates(customerLocationListener); }
            catch (Exception ignored) {}
            customerLocationListener = null;
        }
    }

    private void dispatchCustomerLocation(JSONObject data) {
        if (isFinishing() || isDestroyed() || webView == null) return;
        webView.evaluateJavascript(
            "window.cirengIndiOnLocationResult && window.cirengIndiOnLocationResult("
              + data.toString() + ");", null);
    }

    @Override protected void onDestroy() {
        customerLocationPending = false;
        cleanupCustomerGps();
        geocoderExecutor.shutdownNow();
        if (webView != null) {
            webView.removeJavascriptInterface("Native");
            webView.destroy();
        }
        super.onDestroy();
    }
}