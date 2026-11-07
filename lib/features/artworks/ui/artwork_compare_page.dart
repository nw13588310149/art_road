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

/// 深色对比页上的次级文字、分栏底色与选中描边。
final _onDarkMuted = AppColors.onBrand.withValues(alpha: 0.64);
final _paneColor = AppColors.onBrand.withValues(alpha: 0.06);

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

/// 全屏对比：左侧我的作品、右侧同科目范画，拖动中间分隔条调整两侧宽度。
Future<void> openArtworkCompare(
  BuildContext context, {
  required List<String> images,
  required String subject,
  int initialIndex = 0,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      transitionDuration: AppMotion.overlay,
      reverseTransitionDuration: AppMotion.overlay,
      pageBuilder: (_, _, _) => ArtworkComparePage(
        images: images,
        subject: subject,
        initialIndex: initialIndex,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class ArtworkComparePage extends StatefulWidget {
  const ArtworkComparePage({
    required this.images,
    required this.subject,
    this.initialIndex = 0,
    super.key,
  });

  final List<String> images;
  final String subject;
  final int initialIndex;

  @override
  State<ArtworkComparePage> createState() => _ArtworkComparePageState();
}

class _ArtworkComparePageState extends State<ArtworkComparePage> {
  static const _handleWidth = 28.0;

  late final List<String> _samples = _samplesFor(widget.subject, widget.images);
  late int _mine = widget.images.isEmpty
      ? 0
      : widget.initialIndex.clamp(0, widget.images.length - 1);
  int _sample = 0;
  double _split = 0.5;

  @override
  Widget build(BuildContext context) {
    final subjectLabel = _samplesBySubject.containsKey(widget.subject)
        ? widget.subject
        : '示范';
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s12,
                AppSpace.s8,
                AppSpace.s16,
                AppSpace.s8,
              ),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.close_rounded,
                    semanticLabel: '关闭',
                    size: AppButtonSize.sm,
                    filled: false,
                    color: AppColors.onBrand,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Text(
                    '对比范画',
                    style: AppText.title16.copyWith(color: AppColors.onBrand),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Text(
                      '拖动中间分隔条调整比例，双击恢复一半；双指可缩放细看',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12.copyWith(color: _onDarkMuted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final available = constraints.maxWidth - _handleWidth;
                    return Row(
                      children: [
                        SizedBox(
                          width: available * _split,
                          child: _ComparePane(
                            label: '我的作品',
                            child: widget.images.isEmpty
                                ? const SizedBox.shrink()
                                : AppImage(
                                    src: widget.images[_mine],
                                    fit: BoxFit.contain,
                                    placeholder: const SizedBox.shrink(),
                                  ),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) => setState(() {
                            _split = (_split + details.delta.dx / available)
                                .clamp(0.15, 0.85);
                          }),
                          onDoubleTap: () => setState(() => _split = 0.5),
                          child: SizedBox(
                            width: _handleWidth,
                            child: Center(
                              child: Container(
                                width: 4,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.onBrand.withValues(
                                    alpha: 0.72,
                                  ),
                                  borderRadius: AppRadius.brPill,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _ComparePane(
                            label: '范画 · $subjectLabel',
                            child: AppImage(
                              src: _samples[_sample],
                              fit: BoxFit.contain,
                              placeholder: const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.s12),
              child: Row(
                children: [
                  if (widget.images.length > 1)
                    Flexible(
                      child: _ThumbRow(
                        title: '我的作品',
                        images: widget.images,
                        selected: _mine,
                        onSelect: (i) => setState(() => _mine = i),
                      ),
                    ),
                  const Spacer(),
                  Flexible(
                    child: _ThumbRow(
                      title: '换一张范画',
                      images: _samples,
                      selected: _sample,
                      onSelect: (i) => setState(() => _sample = i),
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

class _ComparePane extends StatelessWidget {
  const _ComparePane({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.br12,
      child: ColoredBox(
        color: _paneColor,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: SizedBox.expand(child: child),
              ),
            ),
            Positioned(
              left: AppSpace.s8,
              top: AppSpace.s8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s8,
                    vertical: AppSpace.s4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.72),
                    borderRadius: AppRadius.brPill,
                  ),
                  child: Text(
                    label,
                    style: AppText.caption12Strong.copyWith(
                      color: AppColors.onBrand,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        Text(title, style: AppText.caption12.copyWith(color: _onDarkMuted)),
        const SizedBox(width: AppSpace.s12),
        Flexible(
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s8),
              itemBuilder: (context, index) => AppPressable(
                onTap: () => onSelect(index),
                selected: index == selected,
                semanticLabel: '$title第 ${index + 1} 张',
                child: Container(
                  width: 48,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.br8,
                    border: Border.all(
                      color: index == selected
                          ? AppColors.brandSoft
                          : _paneColor,
                      width: 2,
                    ),
                  ),
                  child: AppImage(
                    src: images[index],
                    borderRadius: AppRadius.br4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
