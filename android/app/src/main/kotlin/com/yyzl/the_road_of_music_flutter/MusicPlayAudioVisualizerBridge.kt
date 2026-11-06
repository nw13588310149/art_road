package com.yyzl.the_road_of_music_flutter

import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sqrt

class MusicPlayAudioVisualizerBridge(
    private val methodChannel: MethodChannel,
    private val eventChannel: EventChannel,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var visualizer: Visualizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var attachedUrl: String? = null
    private var pendingSessionId: Int? = null

    fun register() {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        releaseVisualizer()
        attachedUrl = null
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "attach" -> {
                attachedUrl = call.argument<String>("url")
                val session = call.argument<Int>("androidAudioSessionId")
                attachVisualizer(session ?: 0)
                result.success(null)
            }
            "updateAndroidSession" -> {
                val session = call.argument<Int>("androidAudioSessionId") ?: 0
                if (attachedUrl != null) {
                    attachVisualizer(session)
                }
                result.success(null)
            }
            "syncTransport" -> {
                // Android Visualizer 跟随系统输出，无需额外同步。
                result.success(null)
            }
            "detach" -> {
                attachedUrl = null
                releaseVisualizer()
                emitIdle()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun attachVisualizer(sessionId: Int) {
        releaseVisualizer()
        if (sessionId < 0) {
            emitIdle()
            return
        }
        try {
            val targetSession = if (sessionId == 0) 0 else sessionId
            val v = Visualizer(targetSession)
            val range = Visualizer.getCaptureSizeRange()
            val captureSize = range[1]
            v.captureSize = captureSize
            v.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(
                        visualizer: Visualizer?,
                        waveform: ByteArray?,
                        samplingRate: Int,
                    ) {
                    }

                    override fun onFftDataCapture(
                        visualizer: Visualizer?,
                        fft: ByteArray?,
                        samplingRate: Int,
                    ) {
                        if (fft == null) return
                        val bands = fftToBands(fft, samplingRate)
                        mainHandler.post {
                            eventSink?.success(bands)
                        }
                    }
                },
                Visualizer.getMaxCaptureRate() / 2,
                false,
                true,
            )
            v.enabled = true
            visualizer = v
        } catch (_: Throwable) {
            emitIdle()
        }
    }

    private fun releaseVisualizer() {
        try {
            visualizer?.enabled = false
            visualizer?.release()
        } catch (_: Throwable) {
        }
        visualizer = null
    }

    private fun emitIdle() {
        mainHandler.post {
            eventSink?.success(emptyList<Double>())
        }
    }

    private fun fftToBands(fft: ByteArray, samplingRate: Int): List<Double> {
        val bands = 46
        val result = DoubleArray(bands)
        val n = fft.size / 2
        if (n <= 1) return result.toList()
        val nyquist = samplingRate / 2.0
        val minHz = 50.0
        val maxHz = 14000.0
        val minMel = hzToMel(minHz)
        val maxMel = hzToMel(maxHz)
        for (i in 0 until bands) {
            val melLow = minMel + (maxMel - minMel) * i / bands
            val melHigh = minMel + (maxMel - minMel) * (i + 1) / bands
            val hzLow = melToHz(melLow)
            val hzHigh = melToHz(melHigh)
            val from = (hzLow / nyquist * (n - 1)).toInt().coerceIn(1, n - 1)
            val to = (hzHigh / nyquist * (n - 1)).toInt().coerceAtLeast(from + 1).coerceAtMost(n)
            var sum = 0.0
            for (j in from until to) {
                val real = fft[2 * j].toInt()
                val imag = fft[2 * j + 1].toInt()
                val mag = sqrt((real * real + imag * imag).toDouble())
                sum += mag
            }
            result[i] = sum / (to - from) / 128.0
        }
        return result.toList()
    }

    private fun hzToMel(hz: Double): Double =
        2595.0 * kotlin.math.log10(1.0 + hz / 700.0)

    private fun melToHz(mel: Double): Double =
        700.0 * (kotlin.math.pow(10.0, mel / 2595.0) - 1.0)
}
