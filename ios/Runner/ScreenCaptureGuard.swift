import Flutter
import ScreenProtectorKit
import UIKit

/// 解析当前 Flutter 根视图，供 ScreenProtectorKit 挂载 secure layer。
private final class FlutterHostViewResolver: ScreenProtectorRootViewResolving {
  weak var hostView: UIView?

  func resolveRootView() -> UIView? {
    hostView
  }
}

/// iOS 截屏 / 录屏防护（ScreenProtectorKit，与 screen_protector 同源）。
///
/// 必须在 FlutterViewController.view 挂载后调用 `configure`；
/// 不可手动 reparent `UIWindow.layer`（会导致只显示 1/4 屏、截屏后永久黑屏）。
/// 不在切后台时盖黑屏，避免影响多任务切换体验。
final class ScreenCaptureGuard {
  static let shared = ScreenCaptureGuard()

  private var kit: ScreenProtectorKit?
  private let resolver = FlutterHostViewResolver()
  private var isConfigured = false

  private init() {}

  /// 在首帧且 view.window 就绪后调用一次。
  func configure(on window: UIWindow, flutterView: UIView) {
    guard !isConfigured else { return }
    guard flutterView.window != nil else { return }

    isConfigured = true
    resolver.hostView = flutterView

    let protector = ScreenProtectorKit(window: window)
    protector.setRootViewResolver(resolver)
    // 与 screen_protector 一致：initial 必须传入 Flutter 根 view，不能传 window / nil。
    ScreenProtectorKit.initial(with: flutterView)
    protector.enabledPreventScreenshot()
    if #available(iOS 11.0, *) {
      protector.enabledPreventScreenRecording()
    }

    kit = protector
  }
}
