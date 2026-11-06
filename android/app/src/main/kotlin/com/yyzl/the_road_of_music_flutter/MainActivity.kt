package com.yyzl.the_road_of_music_flutter

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var visualizerBridge: MusicPlayAudioVisualizerBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = MusicPlayAudioVisualizerBridge(
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "com.yyzl.music/music_play_visualizer",
            ),
            EventChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "com.yyzl.music/music_play_visualizer/bands",
            ),
        )
        bridge.register()
        visualizerBridge = bridge
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        visualizerBridge?.dispose()
        visualizerBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
