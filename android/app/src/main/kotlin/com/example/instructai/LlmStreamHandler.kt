package com.example.instructai

import android.content.Context
import io.flutter.plugin.common.EventChannel

class LlmStreamHandler(private val context: Context) : EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events

        val args = arguments as? Map<*, *> ?: return
        val prompt = args["prompt"] as? String ?: return

        GenAILLMHelper.runTopicInferenceStreaming(
            prompt = prompt,
            onPartial = { chunk -> eventSink?.success(chunk) },
            onComplete = { eventSink?.endOfStream() },
            onError = { error -> eventSink?.error("STREAM_ERROR", error, null) }
        )
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
