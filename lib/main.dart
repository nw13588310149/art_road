import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/router/app_navigator.dart';
import 'core/demo/demo_accounts.dart';
import 'core/demo/demo_store.dart';
import 'core/demo/fixtures/demo_fixtures.dart';
import 'core/demo/media/demo_media.dart';
import 'core/network/media_url.dart';
import 'core/providers/app_providers.dart';
import 'core/push/push_notification_service.dart';
import 'core/storage/app_storage.dart';
import 'core/widgets/image_viewer_tools.dart';
import 'features/art_toolbox/ui/viewer/art_viewer_toolkit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 120;
  imageCache.maximumSizeBytes = 80 << 20;
  // main() 同步阶段触发 MediaKit / 推送初始化，全部 fire-and-forget，
  // 让原生层在 Flutter Engine 渲染管线就绪之前就开始 init，避免和首帧渲染争抢
  // 主线程资源（已验证：把这些挪到 addPostFrameCallback 反而引入 iPad 闪退）。
  try {
    MediaKit.ensureInitialized();
  } catch (error, stack) {
    debugPrint('MediaKit.ensureInitialized failed: $error\n$stack');
  }
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // 与 iOS Info.plist / Android sensorLandscape 一致；请勿在其他页面恢复 portrait。
  // 沉浸式：隐藏系统状态栏和导航栏。
  // - Android：immersiveSticky 模式下用户从屏幕边缘下拉时系统栏会临时显示，几秒后自动隐藏。
  // - iOS：状态栏由 Info.plist + RootFlutterViewController 控制；这里调用是无副作用的兜底。
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // 截屏 / 录屏防护在原生层启用：iOS ScreenCaptureGuard / Android MainActivity。

  final storage = await AppStorage.create();
  final cid = Uri.base.queryParameters['cid'];
  if (cid != null && cid.isNotEmpty) {
    await storage.savePushId(cid);
  }
  if (storage.isGuestSession ||
      DemoAccounts.isObsoleteDemoToken(storage.token)) {
    await storage.clearToken();
  }
  await DemoStore.init();
  await DemoMedia.start();
  registerDemoFixtures();
  final push = PushNotificationService.forStorage(storage);
  unawaited(push.initialize());
  runApp(AccountApp(storage: storage, push: push));
}

/// 退出账号时清除页面栈、轮询与业务缓存。首次登录保留正在提交的表单。
class AccountApp extends StatefulWidget {
  const AccountApp({super.key, required this.storage, required this.push});
  final AppStorage storage;
  final PushNotificationService push;

  @override
  State<AccountApp> createState() => _AccountAppState();
}

class _AccountAppState extends State<AccountApp> {
  late String _previousToken;
  Key _scopeKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _previousToken = widget.storage.token;
    _restoreMedia();
    widget.storage.sessionToken.addListener(_changeSession);
  }

  void _restoreMedia() {
    final storage = widget.storage;
    MediaUrl.setFileBaseUrl(
      storage.isDemoSession
          ? DemoMedia.fileBaseUrl
          : storage.token.isEmpty
          ? ''
          : storage.fileBaseUrl,
    );
  }

  void _changeSession() {
    final wasSignedIn = _previousToken.isNotEmpty;
    _previousToken = widget.storage.token;
    _restoreMedia();
    if (!wasSignedIn) return;
    final images = PaintingBinding.instance.imageCache;
    images.clear();
    images.clearLiveImages();
    rootNavigatorKey = GlobalKey<NavigatorState>();
    setState(() => _scopeKey = UniqueKey());
  }

  @override
  void dispose() {
    widget.storage.sessionToken.removeListener(_changeSession);
    unawaited(widget.push.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    key: _scopeKey,
    overrides: [
      appStorageProvider.overrideWithValue(widget.storage),
      pushNotificationServiceProvider.overrideWithValue(widget.push),
      imageViewerToolkitProvider.overrideWithValue(
        const ArtImageViewerToolkit(),
      ),
    ],
    child: const MyApp(),
  );
}
