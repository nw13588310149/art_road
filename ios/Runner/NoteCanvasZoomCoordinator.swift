import Flutter
import PencilKit
import UIKit

/// Keeps the PencilKit drawing layer in sync with Flutter's note canvas zoom.
///
/// `PKCanvasView` is a native `UIScrollView`. Transforming its Flutter host does
/// not reliably change the drawing content on iPad, so the zoom must be applied
/// to the canvas itself.
final class NoteCanvasZoomCoordinator {
  private let channel: FlutterMethodChannel
  private weak var rootView: UIView?

  init(messenger: FlutterBinaryMessenger, rootView: UIView) {
    self.rootView = rootView
    channel = FlutterMethodChannel(
      name: "the_road_of_music_flutter/note_canvas_zoom",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setZoom",
            let arguments = call.arguments as? [String: Any],
            let zoom = arguments["zoom"] as? Double else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.setZoom(zoom)
      result(nil)
    }
  }

  private func setZoom(_ zoom: Double) {
    let resolvedZoom = CGFloat(min(max(zoom, 0.75), 2.5))
    DispatchQueue.main.async { [weak self] in
      guard let canvas = self?.findCanvasView() else { return }
      canvas.minimumZoomScale = 0.75
      canvas.maximumZoomScale = 2.5
      canvas.setZoomScale(resolvedZoom, animated: false)
    }
  }

  private func findCanvasView() -> PKCanvasView? {
    guard let rootView else { return nil }
    return findCanvasView(in: rootView)
  }

  private func findCanvasView(in view: UIView) -> PKCanvasView? {
    if let canvas = view as? PKCanvasView {
      return canvas
    }
    for subview in view.subviews.reversed() {
      if let canvas = findCanvasView(in: subview) {
        return canvas
      }
    }
    return nil
  }
}
