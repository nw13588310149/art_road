import 'package:flutter/material.dart';

import '../../../core/art/art_tokens.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/widgets/art_widgets.dart';

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
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 160),
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
      backgroundColor: const Color(0xFF15141A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Text(
                    '对比范画',
                    style: ArtText.title(size: 17, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '拖动中间分隔条调整比例，双击恢复一半；双指可缩放细看',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ArtText.caption(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                : ArtNetworkImage(
                                    widget.images[_mine],
                                    fit: BoxFit.contain,
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
                                width: 5,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _ComparePane(
                            label: '范画 · $subjectLabel',
                            child: Image.asset(
                              _samples[_sample],
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  if (widget.images.length > 1)
                    Flexible(
                      child: _ThumbRow(
                        title: '我的作品',
                        count: widget.images.length,
                        selected: _mine,
                        onSelect: (i) => setState(() => _mine = i),
                        builder: (i) => ArtNetworkImage(widget.images[i]),
                      ),
                    ),
                  const Spacer(),
                  Flexible(
                    child: _ThumbRow(
                      title: '换一张范画',
                      count: _samples.length,
                      selected: _sample,
                      onSelect: (i) => setState(() => _sample = i),
                      builder: (i) =>
                          Image.asset(_samples[i], fit: BoxFit.cover),
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
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: const Color(0xFF232229),
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
              left: 10,
              top: 10,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: Colors.white,
                      fontWeight: AppFont.w500,
                      fontFamily: 'PingFang SC',
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
    required this.count,
    required this.selected,
    required this.onSelect,
    required this.builder,
  });

  final String title;
  final int count;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget Function(int index) builder;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: ArtText.caption(color: Colors.white70)),
        const SizedBox(width: 10),
        Flexible(
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              itemCount: count,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(index),
                child: Container(
                  width: 48,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: index == selected
                          ? ArtColors.brandSoft
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: builder(index),
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
