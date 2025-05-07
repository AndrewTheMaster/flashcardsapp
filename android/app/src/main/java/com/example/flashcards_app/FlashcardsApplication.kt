package com.example.flashcards_app

import android.util.Log
import androidx.multidex.MultiDexApplication
import io.flutter.app.FlutterApplication

class FlashcardsApplication : MultiDexApplication() {
    companion object {
        private const val TAG = "FlashcardsApplication"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Application starting")

        try {
            // Explicitly exclude loading the problematic TensorFlow Lite library
            // We'll handle this in the Dart code instead
            Log.d(TAG, "Setting up TensorFlow Lite handling")
        } catch (e: Exception) {
            Log.e(TAG, "Error in application setup: ${e.message}")
        }
    }
} 