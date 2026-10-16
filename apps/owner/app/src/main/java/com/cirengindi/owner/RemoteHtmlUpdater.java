package com.cirengindi.owner;

import android.app.Activity;
import android.content.Context;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Consumer;

/**
 * Cireng Indi HTML OTA (native bootstrap).
 * Fetch trusted public repository HTML over TLS on each cold start.
 * Keep an internally validated offline copy. Only load it under the existing
 * application-local base URL; never expose the Native bridge on GitHub origin.
 * Android binary / launcher changes still need a signed Android update.
 */
final class RemoteHtmlUpdater {
    private static final String REMOTE_URL =
        "https://raw.githubusercontent.com/rizkyhidayat8999-netizen/Cirengindiapp/main/apps/owner/app/src/main/assets/index.html";
    private static final String CACHE_NAME = "cirengindi_owner_ota.html";
    private static final int MAX_HTML_BYTES = 512 * 1024;
    private static final ExecutorService EXECUTOR = Executors.newSingleThreadExecutor();

    static void start(Activity activity, String bundledHtml, Consumer<String> loadOnce) {
        // Never block first paint behind DNS, GitHub, or network timeouts.
        // Start the bundled (or last validated) UI immediately, then refresh
        // the offline OTA cache in the background for the NEXT cold start.
        final String cached = readCache(activity);
        final String firstPaint = cached != null ? cached : bundledHtml;
        if (!activity.isFinishing() && !activity.isDestroyed()) {
            loadOnce.accept(firstPaint);
        }
        EXECUTOR.execute(() -> {
            String fetched = fetchTrusted();
            if (fetched != null && !fetched.equals(cached)) writeCache(activity, fetched);
        });
    }

    private static boolean valid(String html) {
        if (html == null || html.length() < 1500 || html.length() > MAX_HTML_BYTES) return false;
        String lower = html.toLowerCase(java.util.Locale.ROOT);
        return lower.contains("<!doctype html>") &&
            lower.contains("<script>") && lower.contains("</html>") &&
            html.contains("https://tbviryuimoxgapubdjio.supabase.co") &&
            html.contains("Content-Security-Policy") &&
            html.contains("cirengindi-owner-api") &&
            html.contains("logo_cireng_indi.png");
    }

    private static String fetchTrusted() {
        HttpURLConnection connection = null;
        try {
            URL url = new URL(REMOTE_URL);
            if (!"https".equals(url.getProtocol()) ||
                !"raw.githubusercontent.com".equals(url.getHost())) return null;
            connection = (HttpURLConnection) url.openConnection();
            connection.setInstanceFollowRedirects(false);
            connection.setConnectTimeout(1800);
            connection.setReadTimeout(2200);
            connection.setRequestProperty("Accept", "text/plain");
            connection.setRequestProperty("Cache-Control", "no-cache");
            if (connection.getResponseCode() != 200) return null;
            int length = connection.getContentLength();
            if (length > MAX_HTML_BYTES) return null;
            try (InputStream stream = connection.getInputStream();
                 ByteArrayOutputStream output = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[8192];
                int count;
                while ((count = stream.read(buffer)) != -1) {
                    if (output.size() + count > MAX_HTML_BYTES) return null;
                    output.write(buffer, 0, count);
                }
                String html = new String(output.toByteArray(), StandardCharsets.UTF_8);
                return valid(html) ? html : null;
            }
        } catch (Exception ignored) {
            return null; // Offline fallback is intentional.
        } finally {
            if (connection != null) connection.disconnect();
        }
    }

    private static String readCache(Context context) {
        File file = new File(context.getFilesDir(), CACHE_NAME);
        if (!file.isFile() || file.length() > MAX_HTML_BYTES) return null;
        try (FileInputStream stream = new FileInputStream(file);
             ByteArrayOutputStream buffer = new ByteArrayOutputStream()) {
            byte[] chunk = new byte[8192];
            int count;
            while ((count = stream.read(chunk)) != -1) {
                if (buffer.size() + count > MAX_HTML_BYTES) return null;
                buffer.write(chunk, 0, count);
            }
            String html = new String(buffer.toByteArray(), StandardCharsets.UTF_8);
            return valid(html) ? html : null;
        } catch (Exception ignored) { return null; }
    }

    private static void writeCache(Context context, String html) {
        File folder = context.getFilesDir();
        File tmp = new File(folder, CACHE_NAME + ".tmp");
        File dst = new File(folder, CACHE_NAME);
        try (FileOutputStream out = new FileOutputStream(tmp)) {
            out.write(html.getBytes(StandardCharsets.UTF_8));
            out.getFD().sync();
        } catch (Exception ignored) { tmp.delete(); return; }
        if (!tmp.renameTo(dst)) tmp.delete();
    }
}
