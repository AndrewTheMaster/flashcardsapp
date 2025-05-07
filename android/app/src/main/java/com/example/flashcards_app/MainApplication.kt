package com.example.flashcards_app

import android.app.Application
import android.util.Log
import androidx.multidex.MultiDexApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class MainApplication : MultiDexApplication() {
    companion object {
        private const val TAG = "MainApplication"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Application starting")

        try {
            // Load TensorFlow Lite explicitly to avoid dynamic loading issues
            System.loadLibrary("tensorflowlite_c")
            Log.d(TAG, "TensorFlow Lite library loaded successfully")
        } catch (e: UnsatisfiedLinkError) {
            // This is expected and handled by the Flutter side
            Log.e(TAG, "Failed to load TensorFlow Lite library: ${e.message}")
        }
    }
} 