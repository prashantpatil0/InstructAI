package com.example.instructai

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val methodChannel = "genai/method"
    private val eventChannel = "genai/stream"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 🔧 Set up method channel for one-time function calls (loadModel, unloadModel)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val modelPath = call.argument<String>("modelPath") ?: ""
                    val success = GenAILLMHelper.loadModel(this, modelPath)
                    result.success(success)
                }

                "unloadModel" -> {
                    GenAILLMHelper.unloadModel()
                    result.success(true)
                }

                "resetSession" -> {
                    GenAILLMHelper.resetSession()
                    result.success(true)
                }

                "cancelGeneration" -> {
                    GenAILLMHelper.cancelGeneration()
                    result.success(null)
                }


                else -> result.notImplemented()
            }
        }

        // 🔁 Set up event channel for real-time generation
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannel).setStreamHandler(
            LlmStreamHandler(this)
        )
    }
}
