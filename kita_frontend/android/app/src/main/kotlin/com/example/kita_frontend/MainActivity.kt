package com.example.kita_frontend

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val hapticsChannelName = "com.example.kita_frontend/haptics"
    private val contentResolverChannelName = "com.example.kita_frontend/content_resolver"

    private var initialUriString: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureIntentData(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureIntentData(intent)
    }

    private fun captureIntentData(intent: Intent?) {
        if (intent?.action == Intent.ACTION_VIEW) {
            val data = intent.dataString
            if (data != null) {
                initialUriString = data
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hapticsChannelName).setMethodCallHandler { call, result ->
            val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator ?: @Suppress("DEPRECATION") (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator)
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            if (!vibrator.hasVibrator()) {
                result.success(null)
                return@setMethodCallHandler
            }

            when (call.method) {
                "tick" -> {
                    // Silky smooth, feather-light tick (piece selection, piece move)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        vibrator.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK))
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(10, 40))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(10)
                    }
                    result.success(null)
                }
                "click" -> {
                    // Crisp tactile click (piece capture)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        vibrator.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK))
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(20, 120))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(20)
                    }
                    result.success(null)
                }
                "heavyClick" -> {
                    // Heavy tactile impact (game over, checkmate, match end)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        vibrator.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK))
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(35, 255))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(35)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Native content resolver & cold-start intent URI channel for .kita file associations
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, contentResolverChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "readContentUri" -> {
                    val uriStr = call.argument<String>("uri")
                    if (uriStr.isNullOrEmpty()) {
                        result.error("INVALID_URI", "URI cannot be null or empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = Uri.parse(uriStr)
                        val content = contentResolver.openInputStream(uri)?.use { inputStream ->
                            inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                                reader.readText()
                            }
                        }
                        result.success(content)
                    } catch (e: Exception) {
                        result.error("READ_FAILED", e.localizedMessage, e.toString())
                    }
                }
                "getInitialUri" -> {
                    val uri = initialUriString
                    initialUriString = null
                    result.success(uri)
                }
                else -> result.notImplemented()
            }
        }
    }
}
