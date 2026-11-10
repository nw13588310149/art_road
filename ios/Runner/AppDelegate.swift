import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // 只向 SceneDelegate 提供已成功启动的显式引擎。
  private(set) var flutterEngine: FlutterEngine?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine = StartRunnerFlutterEngine()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// 让 App 在 iPad 上以沉浸式 / 全屏方式呈现：
/// - 隐藏顶部状态栏；
/// - 隐藏底部 home 指示条（无 home 键设备）；
/// - 延后系统底部上滑手势，避免误触退出。
@objc(RootFlutterViewController)
class RootFlutterViewController: FlutterViewController {
  private var didEnableScreenCaptureGuard = false

  /// 与 Info.plist 一致，仅横屏；竖握 iPad 时系统不旋转为竖屏 UI。
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return [.landscapeLeft, .landscapeRight]
  }

  override var prefersStatusBarHidden: Bool {
    return true
  }

  override var prefersHomeIndicatorAutoHidden: Bool {
    return true
  }

  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    return [.bottom]
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    installScreenCaptureGuardIfNeeded()
  }

  /// Flutter 首帧渲染完成且 window 挂载后再启用截屏防护，避免启动黑屏。
  private func installScreenCaptureGuardIfNeeded() {
    guard !didEnableScreenCaptureGuard else { return }
    didEnableScreenCaptureGuard = true

    DispatchQueue.main.async { [weak self] in
      guard let self, let window = self.view.window else { return }
      ScreenCaptureGuard.shared.configure(on: window, flutterView: self.view)
    }
  }
}
