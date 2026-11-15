import Flutter
import UIKit

/// Only the material is native. Flutter retains tool actions and accessibility.
final class ArtToolGlassFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    ArtToolGlass(frame: frame, id: viewId, messenger: messenger,
                 configuration: args as? [String: Any] ?? [:])
  }
}

private final class ArtToolGlass: NSObject, FlutterPlatformView {
  private let effectView = UIVisualEffectView()
  private let channel: FlutterMethodChannel
  private var configuration: [String: Any]
  private var observers: [NSObjectProtocol] = []

  init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger,
       configuration: [String: Any]) {
    self.configuration = configuration
    channel = FlutterMethodChannel(name: "com.meiyuji.art/tool_glass/\(id)",
                                   binaryMessenger: messenger)
    super.init()
    effectView.frame = frame
    // The app uses light surfaces. Do not let a system dark appearance obscure
    // Flutter's dark icons, which are drawn by the sibling foreground layer.
    effectView.overrideUserInterfaceStyle = .light
    effectView.isUserInteractionEnabled = false
    effectView.accessibilityElementsHidden = true
    effectView.layer.cornerCurve = .continuous
    effectView.clipsToBounds = true
    apply(animated: false)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      guard call.method == "configure", let next = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      let engagedChanged = (self.configuration["engaged"] as? Bool) != (next["engaged"] as? Bool)
      self.configuration = next
      self.apply(animated: engagedChanged)
      result(nil)
    }
    for name in [UIAccessibility.reduceTransparencyStatusDidChangeNotification,
                 UIAccessibility.reduceMotionStatusDidChangeNotification,
                 UIAccessibility.darkerSystemColorsStatusDidChangeNotification] {
      observers.append(NotificationCenter.default.addObserver(
        forName: name, object: nil, queue: .main
      ) { [weak self] _ in self?.apply(animated: false) })
    }
  }

  func view() -> UIView { effectView }

  private func apply(animated: Bool) {
    effectView.layer.cornerRadius = CGFloat(configuration["radius"] as? Double ?? 16)
    let opaque = UIAccessibility.isReduceTransparencyEnabled ||
      UIAccessibility.isDarkerSystemColorsEnabled || (configuration["opaque"] as? Bool ?? false)
    let reduceMotion = UIAccessibility.isReduceMotionEnabled ||
      (configuration["reduceMotion"] as? Bool ?? false)
    let engaged = configuration["engaged"] as? Bool ?? false
    let update = {
      self.effectView.backgroundColor = opaque ? .white : .clear
      if opaque {
        self.effectView.effect = nil
        return
      }
      // Compiler guard keeps older Xcode SDKs buildable. Availability alone
      // cannot hide a symbol from an SDK that predates iOS 26.
      #if compiler(>=6.2)
      if #available(iOS 26.0, *) {
        let glass = UIGlassEffect(style: .regular)
        glass.isInteractive = true
        glass.tintColor = engaged ? UIColor.white.withAlphaComponent(0.24) : nil
        self.effectView.effect = glass
        return
      }
      #endif
      self.effectView.effect = UIBlurEffect(style: .systemUltraThinMaterialLight)
    }
    // Flutter forwards press/release/cancel because the background must never
    // consume Pencil or finger input intended for a tool button or drag handle.
    if animated && !reduceMotion && !opaque {
      UIView.animate(withDuration: 0.18, delay: 0,
                     options: [.beginFromCurrentState, .allowUserInteraction],
                     animations: update)
    } else {
      effectView.layer.removeAllAnimations()
      UIView.performWithoutAnimation(update)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
  }
}
