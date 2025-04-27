package com.example.flashcardsapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun getCachedEngineId(): String? {
        return FlashcardsApplication.ENGINE_ID
    }
}
