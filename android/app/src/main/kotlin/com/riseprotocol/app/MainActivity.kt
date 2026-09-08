package com.riseprotocol.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AlarmMethodChannel.NAME)
            .setMethodCallHandler { call, result ->
                AlarmMethodChannel.handle(this, call, result)
            }
    }
}
