// 页面预览：把一个页面按身份和尺寸渲染成 PNG，带左导航和顶栏，不需要网页构建。
// 走的是应用自己的路由、外壳、主题、演示后端和本地媒体服务，看到的就是这个身份
// 登录后的页面。每张图约 2 到 4 秒。
//
// 用法（参数都可省略；带逗号的参数在 PowerShell 里要整体加引号）：
//
//   flutter test --no-pub tool/qa/page_preview_test.dart `
//     "--dart-define=SHOTS=today,ebooks" "--dart-define=ROLES=student,teacher" `
//     "--dart-define=SIZES=1180x820,1024x768" "--dart-define=LABEL=before"
//
//   SHOTS   镜头 id，逗号分隔，按前缀匹配（`ebook` 会选中 ebooks、ebook-detail…）。
//           省略时渲染下面清单里的全部镜头。
//   ROUTE   临时看一个不在清单里的路由，例如 `/toolbox?tool=grid`（问号后面是字符串
//           路由参数）。配合 TAPS 可以先点几下：`"--dart-define=TAPS=我的书架+在读"`，
//           多个用加号分隔。默认用学生身份，要换身份加 ROLES。
//   ROLES   身份：student teacher groupLeader headTeacher dormManager admin principal。
//           省略时用镜头自己标注的身份。
//   SIZES   整屏尺寸，默认 1180x820 和 1024x768。想看首屏以下的内容就把高度加大，
//           例如 1180x2400，左导航会跟着拉长，内容区一次显示更多。
//   LABEL   输出子目录，默认 current。改版前后各用一个名字，方便并排比较。
//   SCALE   像素比，默认 2。设成 0.25 得到一张小图，用来只看大关系。
//   CROP    只导出一个区域，写法是「左,上,宽,高」（逻辑像素，以整屏左上角为原点），
//           例如 `"--dart-define=CROP=180,430,560,300" "--dart-define=SCALE=4"`。
//           用来放大看细节：对齐、截断、小字。
//
// 产物：build/qa/preview/<LABEL>/<宽>x<高>/<身份>-<镜头>.png；带 CROP 时文件名后面
// 多一段区域。渲染时出现的版式异常（溢出等）不会中断，记在同名的 .warnings.txt 里，
// 并在结尾汇总；没有这个文件就是没有异常。
//
// 新增页面或想固定看某个状态时，在 `_shots` 里加一行。
//
// 和真机、浏览器的差别：
// - 每次都从初始演示数据开始（相当于刚点过「重置演示数据」）；
// - 时间是运行时的真实时间，和时间有关的内容（今日清单、课表）每次可能不同；
// - pubspec 里没有声明的字体显示成方块（保留的首页上资讯卡的 NEW 角标）；
// - 随页工具栏和小画不在图里；
// - 视频、PDF、相机这类依赖原生插件的内容不显示。
// 需要这些的时候用 tool/qa/web_shot.mjs，见 .cursor/skills/ui-partner/eyes.md。
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/app/router/app_router.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_store.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';
import 'package:the_road_of_art_flutter/core/demo/media/demo_media.dart';
import 'package:the_road_of_art_flutter/core/network/media_url.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/teaching_overview/data/teaching_overview_repository.dart';

// ───────────────────────────── 镜头清单 ─────────────────────────────

const _student = ['student'];
const _everyone = [
  'student',
  'teacher',
  'groupLeader',
  'headTeacher',
  'dormManager',
  'admin',
  'principal',
];

/// 一个镜头：打开 [route]（带 [args]），按 [steps] 点几下，然后截图。
class _Shot {
  const _Shot(
    this.id,
    this.route, {
    this.args,
    this.roles = _student,
    this.steps = const [],
  });

  final String id;
  final String route;

  /// 路由参数，类型按那个页面的约定（多数是 Map，教学报告是 TeachingRequest）。
  final Object? args;
  final List<String> roles;

  /// 依次执行：普通字符串是「点击包含这段文字的第一个控件」；
  /// `tip:返回` 点击提示文字（图标按钮）；`scroll:400` 把内容区向上滚 400；
  /// `wait:800` 多等 800 毫秒。
  final List<String> steps;
}

TeachingRequest _report(TeachingReport report) =>
    (report: report, campus: '', parameter: '');

final _shots = <_Shot>[
  // 今日
  const _Shot('today', '/today', roles: _everyone),

  // 电子书刊
  const _Shot('ebooks', '/ebooks'),
  const _Shot('ebooks-shelf', '/ebooks', steps: ['我的书架']),
  const _Shot('ebook-detail', '/ebooks', steps: ['联考素描静物高分解析']),

  // 素材中心
  const _Shot('gallery', '/gallery'),
  const _Shot('gallery-detail', '/gallery', steps: ['大卫石膏像 · 侧转头像']),
  const _Shot(
    'gallery-compare',
    '/gallery',
    steps: ['大卫石膏像 · 侧转头像', '对比我的原卷'],
  ),

  // 优秀课件
  const _Shot('topics', '/micro-lessons'),
  const _Shot('topic-detail', '/micro-lessons', steps: ['把明暗交界线画进体积里']),
  const _Shot('topic-new', '/micro-lessons', steps: ['新增小课件']),

  // 集市
  const _Shot('market', '/market', roles: ['student', 'principal']),
  const _Shot('market-detail', '/market', steps: ['午后的静物']),
  const _Shot('market-new', '/market', steps: ['发布作品']),
  const _Shot('market-orders', '/market', steps: ['我的订单']),
  const _Shot('market-seller', '/market', steps: ['创作者工作台']),
  const _Shot(
    'market-moderation',
    '/market',
    roles: ['principal'],
    steps: ['集市审核'],
  ),

  // 学情
  const _Shot(
    'study',
    '/study',
    roles: ['student', 'teacher', 'headTeacher', 'principal'],
  ),
  const _Shot('study-report', '/study', steps: ['查看完整报告']),
  const _Shot('study-paper', '/study', steps: ['查看完整报告', '看原卷']),
  const _Shot('study-growth-exam', '/study', steps: ['成长曲线']),
  const _Shot('study-growth-artwork', '/study', steps: ['作品成长']),

  // 教学报告：校长从全校学情点进去，老师和组长从今日点进去。
  const _Shot(
    'report-classes',
    '/study',
    roles: ['principal'],
    steps: ['班级学情'],
  ),
  const _Shot(
    'report-review-chain',
    '/study',
    roles: ['principal'],
    steps: ['作品点评链'],
  ),
  const _Shot(
    'report-teachers',
    '/study',
    roles: ['principal'],
    steps: ['老师履职'],
  ),
  const _Shot(
    'report-attention',
    '/study',
    roles: ['principal'],
    steps: ['需要关注的学生'],
  ),
  _Shot(
    'report-attendance',
    '/teaching-overview',
    args: _report(TeachingReport.attendance),
    roles: const ['principal'],
  ),
  _Shot(
    'report-my-students',
    '/teaching-overview',
    args: _report(TeachingReport.myStudents),
    roles: const ['teacher'],
  ),
  _Shot(
    'report-my-performance',
    '/teaching-overview',
    args: _report(TeachingReport.myPerformance),
    roles: const ['teacher'],
  ),
  _Shot(
    'report-my-attention',
    '/teaching-overview',
    args: _report(TeachingReport.myAttention),
    roles: const ['teacher'],
  ),
  _Shot(
    'report-group-teachers',
    '/teaching-overview',
    args: _report(TeachingReport.groupTeachers),
    roles: const ['groupLeader'],
  ),
  _Shot(
    'report-group-classes',
    '/teaching-overview',
    args: _report(TeachingReport.groupClasses),
    roles: const ['groupLeader'],
  ),

  // 作品
  const _Shot(
    'artworks',
    '/artworks',
    roles: ['student', 'teacher', 'groupLeader', 'principal'],
  ),
  const _Shot('artwork-detail', '/artworks', steps: ['石膏头像结构练习']),
  const _Shot('artwork-upload', '/artworks', steps: ['上传作品']),
  const _Shot(
    'artwork-review',
    '/artworks',
    roles: ['teacher'],
    steps: ['开始点评'],
  ),
  const _Shot(
    'artwork-lead-reviews',
    '/artworks/lead-reviews',
    roles: ['groupLeader'],
  ),
  const _Shot('artwork-excellent', '/artworks/excellent'),

  // 画室工具箱
  const _Shot('toolbox', '/toolbox'),
  const _Shot('toolbox-practice', '/toolbox', steps: ['练习训练']),
  const _Shot('toolbox-exam', '/toolbox', steps: ['备考助手']),
  const _Shot('tool-value', '/toolbox', steps: ['明度检查', '大卫石膏像']),
  const _Shot('tool-color', '/toolbox', steps: ['取色', '花卉静物']),
  const _Shot('tool-grid', '/toolbox', steps: ['构图网格', '秋日风景']),
  const _Shot('tool-sketch', '/toolbox', steps: ['练习训练', '速写计时']),
  const _Shot('tool-figure', '/toolbox', steps: ['练习训练', '人体比例参考']),
  const _Shot('tool-value-order', '/toolbox', steps: ['练习训练', '明度排序训练']),
  const _Shot('tool-countdown', '/toolbox', steps: ['备考助手', '考试倒计时']),
  const _Shot('tool-score', '/toolbox', steps: ['备考助手', '综合分计算器']),
  const _Shot('tool-checklist', '/toolbox', steps: ['备考助手', '考场物品清单']),

  // 保留页面，只作对照，不改
  const _Shot('ref-home', '/', roles: ['student', 'teacher']),
  const _Shot('ref-ai', '/personal-Ai'),

  // 新页面方向稿（临时，方向选定后删除）
  for (final direction in const ['a', 'b', 'c'])
    for (final page in const ['today', 'ebooks'])
      _Shot(
        'draft-$direction-$page',
        '/design-system/directions',
        args: {'d': direction, 'p': page, 'bare': '1'},
      ),
];

// ───────────────────────────── 运行参数 ─────────────────────────────

const _shotsArg = String.fromEnvironment('SHOTS');
const _routeArg = String.fromEnvironment('ROUTE');
const _tapsArg = String.fromEnvironment('TAPS');
const _rolesArg = String.fromEnvironment('ROLES');
const _sizesArg = String.fromEnvironment(
  'SIZES',
  defaultValue: '1180x820,1024x768',
);
const _label = String.fromEnvironment('LABEL', defaultValue: 'current');
const _scaleArg = String.fromEnvironment('SCALE', defaultValue: '2');
const _cropArg = String.fromEnvironment('CROP');

const _accounts = <String, DemoAccount>{
  'student': DemoAccounts.student,
  'teacher': DemoAccounts.teacher,
  'groupLeader': DemoAccounts.groupLeader,
  'headTeacher': DemoAccounts.headTeacher,
  'dormManager': DemoAccounts.dormManager,
  'admin': DemoAccounts.admin,
  'principal': DemoAccounts.principal,
};

List<String> _list(String value, [String separator = ',']) => [
  for (final item in value.split(separator))
    if (item.trim().isNotEmpty) item.trim(),
];

List<_Shot> _selectedShots() {
  if (_routeArg.isNotEmpty) {
    final uri = Uri.parse(_routeArg);
    final name = uri.path
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return [
      _Shot(
        'route-${name.isEmpty ? 'home' : name}',
        uri.path,
        args: uri.hasQuery ? uri.queryParameters : null,
        steps: _list(_tapsArg, '+'),
      ),
    ];
  }
  final wanted = _list(_shotsArg);
  if (wanted.isEmpty) return _shots;
  final unknown = [
    for (final id in wanted)
      if (!_shots.any((shot) => shot.id.startsWith(id))) id,
  ];
  if (unknown.isNotEmpty) {
    throw ArgumentError(
      '没有这些镜头：${unknown.join('、')}。'
      '可用的有：${_shots.map((s) => s.id).join(' ')}',
    );
  }
  return [
    for (final shot in _shots)
      if (wanted.any(shot.id.startsWith)) shot,
  ];
}

List<Size> _selectedSizes() => [
  for (final item in _list(_sizesArg))
    Size(
      double.parse(item.toLowerCase().split('x').first),
      double.parse(item.toLowerCase().split('x').last),
    ),
];

Rect? _selectedCrop() {
  final parts = _list(_cropArg).map(double.parse).toList();
  if (parts.isEmpty) return null;
  if (parts.length != 4) {
    throw ArgumentError('CROP 的写法是「左,上,宽,高」，例如 180,430,560,300');
  }
  return Rect.fromLTWH(parts[0], parts[1], parts[2], parts[3]);
}

// ───────────────────────────── 渲染 ─────────────────────────────

/// 按 pubspec 的字体清单加载全部字体（含图标字体）。测试环境默认只有方块字。
Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      // 清单里的路径做过 URL 编码（文件名带空格的字体）。
      final asset = Uri.decodeFull(font['asset'] as String);
      try {
        final bytes = await rootBundle.load(asset);
        loader.addFont(Future<ByteData>.value(bytes));
      } catch (error) {
        debugPrint('[preview] 字体文件 $asset 读取失败：$error');
      }
    }
    await loader.load();
  }
}

late final Directory _cacheDir;

/// 测试环境里没有原生插件。外壳和页面会用到其中几个（网络状态、缓存目录等），
/// 这里给出替身：已知的通道回一个合理的值，其余插件通道一律回「成功、空结果」，
/// 页面按「没有这项能力」继续渲染，而不是抛出 MissingPluginException。
void _mockPlugins() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  _cacheDir = Directory.systemTemp.createTempSync('art_road_preview_');
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => _cacheDir.path,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (_) async => <String>['wifi'],
  );
  messenger.allMessagesHandler = (channel, handler, message) {
    if (handler != null) return handler(message);
    // 框架自己的通道（资源、文字输入、系统界面等）照常交给引擎。
    if (channel.startsWith('flutter/')) {
      return messenger.delegate.send(channel, message);
    }
    return Future<ByteData?>.value(codec.encodeSuccessEnvelope(null));
  };
}

/// 还在加载：转圈、骨架屏。
final _busy = find.byWidgetPredicate(
  (widget) =>
      widget is CircularProgressIndicator ||
      widget is AppLoadingIndicator ||
      widget is PageInitLoadingShell ||
      widget is AppSkeleton,
);

/// 等页面稳定下来。整个渲染在真实时间里进行（见 [_render]），所以演示接口的
/// 模拟延迟、图片下载和解码、后台线程里的图片处理都按真实速度完成。
/// 至少等 [minMs]；之后连续几帧没有加载指示就结束，最多等 [maxMs]。
Future<bool> _settle(
  WidgetTester tester, {
  int minMs = 900,
  int maxMs = 8000,
}) async {
  final watch = Stopwatch()..start();
  var calm = 0;
  while (watch.elapsedMilliseconds < maxMs) {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 100));
    calm = _busy.evaluate().isEmpty ? calm + 1 : 0;
    if (watch.elapsedMilliseconds >= minMs && calm >= 4) {
      await _loadImages(tester);
      if (_busy.evaluate().isEmpty) return true;
      calm = 0;
    }
  }
  return false;
}

/// 等屏幕上的图片都解码完。加载完一批可能露出下一批，所以多看几轮。
Future<void> _loadImages(WidgetTester tester) async {
  final done = <ImageProvider>{};
  for (var round = 0; round < 4; round++) {
    final pending = [
      for (final element in find.byType(Image).evaluate())
        if (done.add((element.widget as Image).image)) element,
    ];
    if (pending.isEmpty) break;
    await Future.wait([
      for (final element in pending)
        precacheImage(
          (element.widget as Image).image,
          element,
          onError: (_, _) {},
        ).timeout(const Duration(seconds: 6), onTimeout: () {}),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _runStep(WidgetTester tester, String step) async {
  if (step.startsWith('wait:')) {
    await _settle(tester, minMs: int.parse(step.substring(5)));
    return;
  }
  if (step.startsWith('scroll:')) {
    // 内容区中部：两种尺寸下都落在左导航右侧。
    await tester.dragFrom(
      const Offset(640, 460),
      Offset(0, -double.parse(step.substring(7))),
    );
    await _settle(tester, minMs: 400);
    return;
  }
  final finder = step.startsWith('tip:')
      ? find.byTooltip(step.substring(4))
      : find.textContaining(step);
  if (finder.evaluate().isEmpty) {
    throw StateError('找不到要点击的「$step」');
  }
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first, warnIfMissed: false);
  await _settle(tester);
}

Future<void> _export(
  RenderRepaintBoundary boundary,
  double scale,
  Rect? crop,
  String path,
) async {
  var image = await boundary.toImage(pixelRatio: scale);
  if (crop != null) {
    final source = Rect.fromLTWH(
      crop.left * scale,
      crop.top * scale,
      crop.width * scale,
      crop.height * scale,
    ).intersect(
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      source,
      Rect.fromLTWH(0, 0, source.width, source.height),
      Paint(),
    );
    final cropped = await recorder.endRecording().toImage(
      source.width.round(),
      source.height.round(),
    );
    image.dispose();
    image = cropped;
  }
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
}

Future<void> _render(
  WidgetTester tester,
  _Shot shot,
  String role,
  Size size,
  double scale,
  Rect? crop,
  List<String> report,
) async {
  final account = _accounts[role]!;
  final dir =
      'build/qa/preview/$_label/${size.width.round()}x${size.height.round()}';
  final name = crop == null
      ? '$role-${shot.id}'
      : '$role-${shot.id}@${crop.left.round()}-${crop.top.round()}'
            '-${crop.width.round()}x${crop.height.round()}';
  final warnings = <String>[];
  void collect() {
    for (;;) {
      final error = tester.takeException();
      if (error == null) break;
      warnings.add(error.toString().split('\n').take(6).join('\n'));
    }
  }

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(<String, Object>{
    'token': account.token,
    // 首页的新手引导只在第一次进入时弹出，预览里当作已经看过。
    for (final key in _accounts.keys) 'role_guide_seen_v1:$key': true,
  });
  final prefs = await SharedPreferences.getInstance();
  await DemoStore.init();
  await DemoStore.reset();
  DemoArtworkStore.clearCache();

  final container = ProviderContainer(
    overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
  );
  final boundary = GlobalKey();
  final app = RepaintBoundary(
    key: boundary,
    child: UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        title: '美育集',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        // 只生成目标页一条路由；默认做法会先在下面垫一个首页。
        onGenerateInitialRoutes: (_) => [
          AppRouter.onGenerateRoute(
            RouteSettings(name: shot.route, arguments: shot.args),
          ),
        ],
        onGenerateRoute: AppRouter.onGenerateRoute,
        // 与 lib/app/app.dart 相同的全局文字设置，行高和字距才和应用里一致。
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: DefaultTextHeightBehavior(
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );

  // 测试环境把阴影画成实心色块，这里要看真实效果；结束前必须改回去。
  debugDisableShadows = false;
  try {
    // 测试默认用假时钟，真实的网络请求和后台线程任务在里面走不完。
    // 把整个渲染放进 runAsync，页面里的延时、下载、解码都按真实时间进行。
    await tester.runAsync(() async {
      try {
        await tester.pumpWidget(app);
        var settled = await _settle(tester, minMs: 1400);
        collect();
        for (final step in shot.steps) {
          try {
            await _runStep(tester, step);
          } catch (error) {
            warnings.add('步骤「$step」没有执行：$error');
            break;
          }
          collect();
        }
        settled = await _settle(tester, minMs: 300) && settled;
        collect();
        if (!settled) warnings.add('等了 8 秒页面仍在加载，图里可能有转圈或骨架屏');

        await _export(
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary,
          scale,
          crop,
          '$dir/$name.png',
        );
        final note = File('$dir/$name.warnings.txt');
        if (warnings.isEmpty) {
          if (note.existsSync()) note.deleteSync();
        } else {
          await note.writeAsString(warnings.join('\n\n'));
        }
        report.add(
          warnings.isEmpty
              ? 'ok    $dir/$name.png'
              : 'warn  $dir/$name.png（${warnings.length} 条，见 $name.warnings.txt）',
        );
      } finally {
        // 卸载页面，等在途的请求回来，再销毁状态，轮询随之停止。
        await tester.pumpWidget(const SizedBox.shrink());
        await Future<void>.delayed(const Duration(milliseconds: 500));
        container.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
  } finally {
    await tester.pump(const Duration(seconds: 1));
    collect();
    debugDisableShadows = true;
  }
}

void main() {
  final shots = _selectedShots();
  final sizes = _selectedSizes();
  final crop = _selectedCrop();
  final scale = double.parse(_scaleArg);
  final roleFilter = _list(_rolesArg);
  for (final role in roleFilter) {
    if (!_accounts.containsKey(role)) {
      throw ArgumentError('没有这个身份：$role。可用的有：${_accounts.keys.join(' ')}');
    }
  }
  final report = <String>[];

  setUpAll(() async {
    _mockPlugins();
    await _loadFonts();
    // 和应用启动时一样：起本地媒体服务，演示图片按网络地址加载。
    // 测试环境默认把所有 HTTP 请求挡回 400，这里放开，只会访问本机的媒体服务。
    HttpOverrides.global = null;
    await DemoMedia.start();
    MediaUrl.setFileBaseUrl(DemoMedia.fileBaseUrl);
    registerDemoFixtures();
  });

  tearDownAll(() {
    try {
      _cacheDir.deleteSync(recursive: true);
    } catch (_) {
      // 临时目录删不掉不影响结果。
    }
    // ignore: avoid_print
    print('\n页面预览（$_label）：\n${report.join('\n')}');
  });

  for (final size in sizes) {
    for (final shot in shots) {
      for (final role in roleFilter.isEmpty ? shot.roles : roleFilter) {
        testWidgets(
          '${shot.id} · $role · ${size.width.round()}x${size.height.round()}',
          (tester) => _render(tester, shot, role, size, scale, crop, report),
        );
      }
    }
  }
}
