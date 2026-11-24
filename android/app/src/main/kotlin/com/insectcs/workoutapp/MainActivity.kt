package com.insectcs.workoutapp

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOWNLOADS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveDownload") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val name = call.argument<String>("name")
            val bytes = call.argument<ByteArray>("bytes")
            val mime = call.argument<String>("mime")
            if (name.isNullOrEmpty() || bytes == null) {
                result.error("INVALID_ARGUMENT", "Missing export name or bytes", null)
                return@setMethodCallHandler
            }

            result.success(saveToDownloads(name, bytes, mime ?: "application/octet-stream"))
        }
    }

    /**
     * Writes the exported CSV/PDF into the public Downloads collection using
     * MediaStore. No storage permission is required for files the app creates
     * itself on Android 10+, and the file is visible from any file manager.
     * Returns a display path for the UI, or null to let Dart use its fallback.
     */
    private fun saveToDownloads(name: String, bytes: ByteArray, mime: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: return null

        return try {
            contentResolver.openOutputStream(uri, "w")?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IllegalStateException("Could not open Downloads output stream")

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            "Downloads/$name"
        } catch (e: Exception) {
            // Remove the half-written placeholder so it does not show up in
            // Downloads. The Dart caller falls back to app-private storage.
            try {
                contentResolver.delete(uri, null, null)
            } catch (_: Exception) {
            }
            null
        }
    }

    companion object {
        private const val DOWNLOADS_CHANNEL = "com.insectcs.workoutapp/downloads"
    }
}
