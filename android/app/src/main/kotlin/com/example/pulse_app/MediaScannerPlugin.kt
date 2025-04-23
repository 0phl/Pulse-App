package com.example.pulse_app

import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

class MediaScannerPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.pulse.app/media_scanner")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "scanFile" -> {
                val path = call.argument<String>("path")
                if (path != null) {
                    scanFile(path, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Path cannot be null", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun scanFile(path: String, result: Result) {
        val file = File(path)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "File does not exist: $path", null)
            return
        }

        try {
            MediaScannerConnection.scanFile(
                context,
                arrayOf(path),
                null
            ) { _, uri ->
                Log.d("MediaScannerPlugin", "Scanned file: $path, URI: $uri")
                result.success(uri != null)
            }
        } catch (e: Exception) {
            Log.e("MediaScannerPlugin", "Error scanning file: $path", e)
            result.error("SCAN_ERROR", "Error scanning file: ${e.message}", null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
