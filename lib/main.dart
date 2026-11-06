import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'core/network/media_url.dart';
import 'core/providers/app_providers.dart';
import 'core/push/push_notification_service.dart';
import 'core/storage/app_storage.dart';
import 'features/music_companion/audio/music_companion_audio_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 120;
  imageCache.maximumSizeBytes = 80 << 20;
  // 与 c3f7d2e（最后已知不闪退版本）等价的启动顺序：
  // main() 同步阶段触发 MediaKit / 音频预热 / 推送初始化，全部 fire-and-forget，
  // 让原生层在 Flutter Engine 渲染管线就绪之前就开始 init，避免和首帧渲染争抢
  // 主线程资源（已验证：把这些挪到 addPostFrameCallback 反而引入 iPad 闪退）。
  try {
    MediaKit.ensureInitialized();
  } catch (error, stack) {
    debugPrint('MediaKit.ensureInitialized failed: $error\n$stack');
  }
  // 7d9da87 不在启动时预热 SoLoud；各功能页独立 init + loadAsset，避免竞态。
  unawaited(warmupMusicCompanionPianoAudio());
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
  // 启动时立即把上次缓存的「文件服务器域名」注入 MediaUrl，让首屏就能正常
  // 解析图片/音频路径，登录后再通过 configList 异步刷新。
  final cachedFileBase = storage.fileBaseUrl;
  if (cachedFileBase.isNotEmpty) {
    MediaUrl.setFileBaseUrl(cachedFileBase);
  }

  // 根容器：把 storage 注入 [appStorageProvider]，并在 runApp 之前预读
  // [pushNotificationServiceProvider] 把 GeTui SDK 的初始化跑起来。原生平台
  // 异步申请通知权限 / 注册 deviceToken 期间不会阻塞 UI，Web 上则走 stub
  // no-op 直接返回。
  final container = ProviderContainer(
    overrides: [appStorageProvider.overrideWithValue(storage)],
  );
  unawaited(container.read(pushNotificationServiceProvider).initialize());

  runApp(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
}
