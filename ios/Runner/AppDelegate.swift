import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// 显式 FlutterEngine：避免 implicit engine + Storyboard 在 ProMotion iPad
  /// （iOS 18+）冷启动时 viewDidLoad 早于 engine 就绪，触发 VSyncClient 空指针闪退。
  lazy var flutterEngine = FlutterEngine(name: "music_road_engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 仅启动 engine；插件须在 SceneDelegate 中绑定到 FlutterViewController 再注册。
    // 对 engine 直接 register 会导致 Swift 插件（如 camera）在启动期空指针崩溃。
    flutterEngine.run()
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
