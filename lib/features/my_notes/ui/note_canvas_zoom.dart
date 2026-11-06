import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iPad PencilKit owns its own native scroll view, so its drawing content must
/// be zoomed through the native canvas rather than a Flutter-only transform.
abstract final class NoteCanvasZoom {
  static const MethodChannel _channel = MethodChannel(
    'the_road_of_music_flutter/note_canvas_zoom',
  );

  static Future<void> setZoom(double zoom) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setZoom', <String, double>{
        'zoom': zoom,
      });
    } on MissingPluginException {
      // Non-iPad development builds can omit the iOS bridge.
    }
  }
}
