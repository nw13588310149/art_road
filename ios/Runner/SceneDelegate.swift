import Flutter
import UIKit

/// 使用 AppDelegate 中已 run 的显式 FlutterEngine 挂载 RootFlutterViewController。
/// 见 flutter/flutter#183900（ProMotion iPad VSyncClient SIGSEGV）。
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  private var noteCanvasZoomCoordinator: NoteCanvasZoomCoordinator?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    self.window = window
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
          let engine = appDelegate.flutterEngine else {
      window.rootViewController = LaunchFailureViewController()
      window.makeKeyAndVisible()
      return
    }

    let flutterViewController = RootFlutterViewController(
      engine: engine,
      nibName: nil,
      bundle: nil
    )
    flutterViewController.view.backgroundColor = .white

    GeneratedPluginRegistrant.register(with: flutterViewController)
    AppAudioSessionCoordinator.shared.register(
      messenger: flutterViewController.binaryMessenger
    )
    noteCanvasZoomCoordinator = NoteCanvasZoomCoordinator(
      messenger: flutterViewController.binaryMessenger,
      rootView: flutterViewController.view
    )

    window.rootViewController = flutterViewController
    window.makeKeyAndVisible()
  }
}

private final class LaunchFailureViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard presentedViewController == nil else { return }

    #if DEBUG
    let message = "请通过 Flutter 或 Xcode 启动调试，或重新安装 Release 版。"
    #else
    let message = "请重新打开应用。如果仍无法启动，请联系支持。"
    #endif
    let alert = UIAlertController(
      title: "应用无法启动",
      message: message,
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "知道了", style: .default))
    present(alert, animated: true)
  }
}
