import Flutter
import UIKit

/// 使用 AppDelegate 中已 run 的显式 FlutterEngine 挂载 RootFlutterViewController。
/// 见 flutter/flutter#183900（ProMotion iPad VSyncClient SIGSEGV）。
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  private var lowLatencyNoteAudio: LowLatencyNoteAudio?
  private var musicPlayPitchAudio: MusicPlayPitchAudio?
  private var musicPlayAudioVisualizer: MusicPlayAudioVisualizer?
  private var noteCanvasZoomCoordinator: NoteCanvasZoomCoordinator?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

    let flutterViewController = RootFlutterViewController(
      engine: appDelegate.flutterEngine,
      nibName: nil,
      bundle: nil
    )
    flutterViewController.view.backgroundColor = .white

    #if DEBUG
    // Debug 包从桌面冷启动时 registrar 为 null，Swift 插件会 SIGSEGV（flutter#69011）。
    // 分发到 TestFlight / 真机请用 Release；此处仅避免崩溃并提示。
    if flutterViewController.registrar(forPlugin: "Runner") == nil {
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = DebugLaunchBlockedViewController()
      window.makeKeyAndVisible()
      self.window = window
      return
    }
    #endif

    GeneratedPluginRegistrant.register(with: flutterViewController)
    AppAudioSessionCoordinator.shared.register(
      messenger: flutterViewController.binaryMessenger
    )
    lowLatencyNoteAudio = LowLatencyNoteAudio(
      messenger: flutterViewController.binaryMessenger
    )
    musicPlayPitchAudio = MusicPlayPitchAudio(
      messenger: flutterViewController.binaryMessenger
    )
    musicPlayAudioVisualizer = MusicPlayAudioVisualizer(
      messenger: flutterViewController.binaryMessenger
    )
    noteCanvasZoomCoordinator = NoteCanvasZoomCoordinator(
      messenger: flutterViewController.binaryMessenger,
      rootView: flutterViewController.view
    )

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = flutterViewController
    window.makeKeyAndVisible()
    self.window = window
  }
}

#if DEBUG
/// Debug 包未通过 flutter run / Xcode 调试启动时的占位页，避免插件注册空指针崩溃。
private final class DebugLaunchBlockedViewController: UIViewController {
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard presentedViewController == nil else { return }

    let alert = UIAlertController(
      title: "Debug 包无法独立启动",
      message: "请改用 Codemagic Release 模式打包后再安装到 iPad，或通过 flutter run 进行调试。",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "知道了", style: .default))
    present(alert, animated: true)
  }
}
#endif
