package com.example.pulse_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register all plugins
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        // Add custom plugins
        flutterEngine.plugins.add(MediaScannerPlugin())
    }
}