import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

const _samplesBySubject = <String, List<String>>{
  '素描': [
    'assets/demo/art/sketch-bust-2.jpg',
    'assets/demo/art/sketch-portrait-1.jpg',
    'assets/demo/art/sketch-still-3.jpg',
    'assets/demo/art/sketch-geometry-1.jpg',
    'assets/demo/art/detail-sketch.jpg',
  ],
  '色彩': [
    'assets/demo/art/color-still-1.jpg',
    'assets/demo/art/color-landscape-1.jpg',
    'assets/demo/art/color-flower-1.jpg',
    'assets/demo/art/color-still-3.jpg',
    'assets/demo/art/detail-color.jpg',
  ],
  '速写': [
    'assets/demo/art/speed-figure-2.jpg',
    'assets/demo/art/speed-group-1.jpg',
    'assets/demo/art/speed-scene-1.jpg',
    'assets/demo/art/speed-figure-5.jpg',
  ],
};

/// 同科目范画；排除与学生作品同一张的演示图，其他科目三科各取一张。
List<String> _samplesFor(String subject, List<String> myImages) {
  final pool =
      _samplesBySubject[subject] ??
      [for (final list in _samplesBySubject.values) list.first];
  final distinct = pool
      .where(
        (asset) => !myImages.any((url) => url.contains(asset.split('/').last)),
      )
      .toList();
  return distinct.isEmpty ? pool : distinct;
}

/// 全屏对比：左侧我的作品（或当前版本）、右侧同科目范画（或上一版本）。
///
/// [focus] 是画上的一处（按图片宽高归一化），打开时两侧一起放大到这一处；
/// [focusLabel] 写在顶栏名称后面，说明对着的是哪一处。
Future<void> openArtworkCompare(
  BuildContext context, {
  required List<String> images,
  required String subject,
  int initialIndex = 0,
  List<String>? previousImages,
  Offset? focus,
  String focusLabel = '',
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: imageCompareRouteName),
      fullscreenDialog: true,
      transitionDuration: AppMotion.overlay,
      reverseTransitionDuration: AppMotion.overlay,
      pageBuilder: (_, _, _) => ArtworkComparePage(
        images: images,
        subject: subject,
        initialIndex: initialIndex,
        previousImages: previousImages,
        focus: focus,
        focusLabel: focusLabel,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// 沉浸的对比页（设计语言第九节）：白色顶栏放返回、名称和两组切换，下面是中性灰
/// 画布（`AppCompareView`），画布下面一行是提示和锁定、旋转、翻转、交换、复位，
/// 最下面一行换图。版本对比时两张是同一幅画，滑动和叠加最有用。
class ArtworkComparePage extends StatefulWidget {
  const ArtworkComparePage({
    required this.images,
    required this.subject,
    this.initialIndex = 0,
    this.previousImages,
    this.focus,
    this.focusLabel = '',
    super.key,
  });

  final List<String> images;
  final String subject;
  final int initialIndex;
  final List<String>? previousImages;

  /// 打开时放大到的一处（0–1），两侧锁定一起放大。
  final Offset? focus;
  final String focusLabel;

  /// 对着一处打开时放大的倍数。
  static const double focusScale = 2.5;

  @override
  State<ArtworkComparePage> createState() => _ArtworkComparePageState();
}

class _ArtworkComparePageState extends State<ArtworkComparePage> {
  final _compare = AppCompareController();

  late final List<String> _samples =
      widget.previousImages ?? _samplesFor(widget.subject, widget.images);
  late int _mine = widget.images.isEmpty
      ? 0
      : widget.initialIndex.clamp(0, widget.images.length - 1);

  /// 版本对比时上一版也从同一张开始。
  late int _sample = _revision && _samples.isNotEmpty
      ? widget.initialIndex.clamp(0, _samples.length - 1)
      : 0;

  bool get _revision => widget.previousImages != null;

  @override
  void initState() {
    super.initState();
    if (widget.focus case final focus?) {
      _compare.setSideZoom(
        0,
        AppCompareZoom(scale: ArtworkComparePage.focusScale, center: focus),
      );
    }
  }

  @override
  void dispose() {
    _compare.dispose();
    super.dispose();
  }

  void _select(void Function() change) {
    setState(change);
    _compare.resetZoom();
  }

  AppComparePane _pane(String label, List<String> images, int index) {
    if (images.isEmpty) {
      return AppComparePane.placeholder(
        label: label,
        child: const AppEmptyState(
          icon: Icons.image_outlined,
          title: '没有可对比的图片',
        ),
      );
    }
    final src = images[index.clamp(0, images.length - 1)];
    return AppComparePane(
      label: label,
      image: AppImage.providerOf(src),
      child: AppImage(
        src: src,
        fit: BoxFit.contain,
        placeholder: const Center(child: AppLoadingIndicator()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final revision = _revision;
    final subjectLabel = _samplesBySubject.containsKey(widget.subject)
        ? widget.subject
        : '示范';
    final mineLabel = revision ? '当前版本' : '我的作品';
    final sampleLabel = revision ? '上一版本' : '范画 · $subjectLabel';
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 64,
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
              alignment: Alignment.center,
              child: ListenableBuilder(
                listenable: _compare,
                builder: (context, _) => AppTitleBar(
                  title: revision ? '版本对比' : '对比范画',
                  caption: widget.focusLabel,
                  onBack: () => Navigator.of(context).maybePop(),
                  backLabel: '关闭对比',
                  actions: [
                    AppCompareModeTabs(controller: _compare),
                    const SizedBox(height: 20, child: AppRule.vertical(gap: 33)),
                    AppViewTabs<bool>(
                      items: const [
                        AppViewTab(value: false, label: '彩色'),
                        AppViewTab(value: true, label: '灰度'),
                      ],
                      value: _compare.grayscale,
                      onChanged: _compare.setGrayscale,
                    ),
                  ],
                ),
              ),
            ),
            const AppRule(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s24,
                  AppSpace.s4,
                  AppSpace.s24,
                  0,
                ),
                child: AppCompareView(
                  controller: _compare,
                  first: _pane(mineLabel, widget.images, _mine),
                  second: _pane(sampleLabel, _samples, _sample),
                  autofocus: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
              child: AppCompareFooter(controller: _compare),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s24,
                0,
                AppSpace.s24,
                AppSpace.s16,
              ),
              child: Row(
                children: [
                  if (widget.images.length > 1)
                    Flexible(
                      child: _ThumbRow(
                        title: mineLabel,
                        images: widget.images,
                        selected: _mine,
                        onSelect: (i) => _select(() => _mine = i),
                      ),
                    ),
                  const Spacer(),
                  if (_samples.length > 1)
                    Flexible(
                      child: _ThumbRow(
                        title: revision ? '上一版本图片' : '换一张范画',
                        images: _samples,
                        selected: _sample,
                        onSelect: (i) => _select(() => _sample = i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一组换图的小图：12 号名称，48 见方的小图完整显示不裁，当前一张 2 像素墨色描边。
class _ThumbRow extends StatelessWidget {
  const _ThumbRow({
    required this.title,
    required this.images,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<String> images;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: AppText.caption12),
        const SizedBox(width: AppSpace.s12),
        Flexible(
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
              itemBuilder: (context, index) {
                final current = index == selected;
                return AppPressable(
                  onTap: () => onSelect(index),
                  selected: current,
                  semanticLabel: '$title第 ${index + 1} 张',
                  child: Container(
                    width: 48,
                    padding: EdgeInsets.all(current ? 1 : 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.br8,
                      border: Border.all(
                        color: current ? AppColors.ink : AppColors.line,
                        width: current ? 2 : 1,
                      ),
                    ),
                    child: AppImage(
                      src: images[index],
                      fit: BoxFit.contain,
                      borderRadius: AppRadius.br4,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
