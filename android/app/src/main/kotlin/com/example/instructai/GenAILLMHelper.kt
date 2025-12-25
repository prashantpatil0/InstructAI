package com.example.instructai

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.mediapipe.tasks.genai.llminference.*

object GenAILLMHelper {
    private var llmInference: LlmInference? = null
    private var session: LlmInferenceSession? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var isGenerating = false

    @Volatile
    private var cancelled = false

    fun loadModel(context: Context, modelPath: String, maxTokens: Int = 4000): Boolean {
        return try {
            val options = LlmInference.LlmInferenceOptions.builder()
                .setModelPath(modelPath)
                .setMaxTokens(maxTokens)
                .build()

            unloadModel() // Ensure clean load
            llmInference = LlmInference.createFromOptions(context, options)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun unloadModel() {
        try {
            session?.close()
            llmInference?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            session = null
            llmInference = null
        }
    }

    fun resetSession() {
        try {
            session?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            session = null
        }
    }

    fun cancelGeneration() {
        cancelled = true
        try {
            session?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            session = null
            isGenerating = false
        }
    }

    fun runTopicInferenceStreaming(
        prompt: String,
        onPartial: (String) -> Unit,
        onComplete: () -> Unit,
        onError: (String) -> Unit
    ) {
        // Cancel any ongoing generation before starting
        cancelGeneration()

        val inference = llmInference ?: run {
            onError("❌ Model not loaded.")
            return
        }

        cancelled = false
        isGenerating = true

        try {
            session?.close()
        } catch (_: Exception) {}

        try {
            session = LlmInferenceSession.createFromOptions(
                inference,
                LlmInferenceSession.LlmInferenceSessionOptions.builder()
                    .setTopK(40)
                    .setTopP(0.95f)
                    .setTemperature(0.7f)
                    .build()
            )
        } catch (e: Exception) {
            isGenerating = false
            onError("❌ Failed to create session: ${e.localizedMessage}")
            return
        }

        try {
            session?.addQueryChunk(prompt)

            session?.generateResponseAsync { partialText, done ->
                if (cancelled) return@generateResponseAsync

                mainHandler.post {
                    onPartial(partialText)
                    if (done == true) {
                        isGenerating = false
                        onComplete()
                    }
                }
            }
        } catch (e: Exception) {
            isGenerating = false
            mainHandler.post {
                onError("❌ Inference error: ${e.localizedMessage}")
            }
        }
    }
}
