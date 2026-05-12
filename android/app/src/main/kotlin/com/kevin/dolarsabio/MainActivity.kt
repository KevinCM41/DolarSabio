package com.kevin.dolarsabio

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.kevin.dolarsabio/downloads",
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveToDownloads") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val filename = call.argument<String>("filename") ?: "export.bin"
                val mimeType =
                    call.argument<String>("mimeType") ?: "application/octet-stream"
                val bytes = call.argument<ByteArray>("bytes") ?: byteArrayOf()
                val pathOrUri = saveToDownloads(filename, mimeType, bytes)
                result.success(pathOrUri)
            } catch (e: Exception) {
                result.error("SAVE_FAILED", e.message, null)
            }
        }
    }

    /**
     * API 29+: [MediaStore.Downloads] con el MIME indicado (Excel, PDF, etc.).
     * API 28 y anteriores: carpeta privada de la app.
     */
    private fun saveToDownloads(filename: String, mimeType: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values =
                ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, filename)
                    put(MediaStore.Downloads.MIME_TYPE, mimeType)
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
            val resolver = contentResolver
            val collection =
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val itemUri =
                resolver.insert(collection, values)
                    ?: throw IllegalStateException("No se pudo crear el archivo en Descargas")
            resolver.openOutputStream(itemUri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("No se pudo escribir en Descargas")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(itemUri, values, null, null)
            return itemUri.toString()
        }
        val baseDir =
            getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                ?: getExternalFilesDir(null)
                ?: throw IllegalStateException("Sin carpeta de almacenamiento")
        if (!baseDir.exists()) baseDir.mkdirs()
        val file = File(baseDir, filename)
        file.writeBytes(bytes)
        return file.absolutePath
    }
}
