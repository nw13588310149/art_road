import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_font.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/help_guide_controller.dart';
import '../state/help_guide_state.dart';

const _textPrimary = Color(0xFF0B081A);
const _textSecondary = Color(0xFF8E8D95);
const _softBorder = Color(0xFFF3F2F3);

class HelpGuidePage extends ConsumerWidget {
  const HelpGuidePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(helpGuideControllerProvider);
    final controller = ref.read(helpGuideControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuideHeader(onBack: () => _backToHome(context)),
        SizedBox(height: ui(14)),
        _CategoryBar(
          categories: state.categories,
          selectedCategoryId: state.selectedCategoryId,
          onSelected: controller.selectCategory,
        ),
        SizedBox(height: ui(12)),
        Expanded(child: _GuideGrid(items: state.visibleItems)),
      ],
    );
  }

  void _backToHome(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(RoutePaths.home);
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ShellPageSurface(
      height: ui(54),
      borderRadius: BorderRadius.circular(ui(14)),
      gradient: const LinearGradient(
        colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFFF9FF)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: ui(12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ui(8)),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(ui(8)),
                child: Container(
                  width: ui(28),
                  height: ui(28),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ui(8)),
                    border: Border.all(color: _softBorder),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: ui(20),
                    color: _textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '操作指南',
                style: TextStyle(
                  color: _textPrimary,
                  fontFamily: 'PingFang SC',
                  fontSize: ui(16),
                  height: 1.1,
                  fontWeight: AppFont.w600,
                ),
              ),
              SizedBox(height: ui(3)),
              Text(
                '音乐之路APP操作指南',
                style: TextStyle(
                  color: const Color(0xFFC2C1C5),
                  fontFamily: 'PingFang SC',
                  fontSize: ui(10),
                  height: 1.1,
                  fontWeight: AppFont.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<HelpGuideCategory> categories;
  final String selectedCategoryId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(7)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories
              .map((category) {
                final selected = category.id == selectedCategoryId;
                return Padding(
                  padding: EdgeInsets.only(left: ui(3)),
                  child: Material(
                    color: selected ? _textPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(ui(6)),
                    child: InkWell(
                      onTap: () => onSelected(category.id),
                      borderRadius: BorderRadius.circular(ui(6)),
                      child: Container(
                        height: ui(32),
                        padding: EdgeInsets.symmetric(horizontal: ui(14)),
                        alignment: Alignment.center,
                        child: Text(
                          category.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF57545F),
                            fontFamily: 'PingFang SC',
                            fontSize: ui(12),
                            height: 1,
                            fontWeight: selected ? AppFont.w500 : AppFont.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _GuideGrid extends StatelessWidget {
  const _GuideGrid({required this.items});

  final List<HelpGuideItem> items;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= ui(760)
            ? 3
            : constraints.maxWidth >= ui(500)
            ? 2
            : 1;
        return GridView.builder(
          padding: EdgeInsets.only(bottom: ui(16)),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: ui(10),
            mainAxisSpacing: ui(12),
            mainAxisExtent: ui(204),
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _GuideCard(item: items[index]),
        );
      },
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.item});

  final HelpGuideItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textPrimary,
              fontFamily: 'PingFang SC',
              fontSize: ui(13),
              height: 1.2,
              fontWeight: AppFont.w500,
            ),
          ),
          SizedBox(height: ui(4)),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textSecondary,
              fontFamily: 'PingFang SC',
              fontSize: ui(10),
              height: 1.1,
              fontWeight: AppFont.w400,
            ),
          ),
          SizedBox(height: ui(8)),
          Expanded(child: _GuideCover(subject: item.title)),
        ],
      ),
    );
  }
}

class _GuideCover extends StatelessWidget {
  const _GuideCover({required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(10)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xFFF5F1FF),
                  Color(0xFF8A77FF),
                  Color(0xFF6847F4),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: <double>[0, 0.48, 1],
              ),
            ),
          ),
          CustomPaint(painter: _GuideWavePainter()),
          Positioned(
            top: ui(8),
            left: ui(9),
            child: Row(
              children: [
                Container(
                  width: ui(20),
                  height: ui(20),
                  padding: EdgeInsets.all(ui(3)),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8C58FF),
                    borderRadius: BorderRadius.circular(ui(5)),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: ui(13),
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: ui(3)),
                Container(
                  height: ui(16),
                  padding: EdgeInsets.symmetric(horizontal: ui(4)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(ui(4)),
                  ),
                  child: Text(
                    '2.0',
                    style: TextStyle(
                      color: const Color(0xFF6B41E8),
                      fontFamily: 'Manrope',
                      fontSize: ui(8),
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.05),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '音乐之路 功能指南',
                  style: TextStyle(
                    color: const Color(0xFF7540FF),
                    fontFamily: 'PingFang SC',
                    fontSize: ui(22),
                    height: 1.05,
                    fontWeight: AppFont.w600,
                    shadows: const <Shadow>[
                      Shadow(color: Colors.white, blurRadius: 6),
                    ],
                  ),
                ),
                SizedBox(height: ui(5)),
                Container(
                  constraints: BoxConstraints(maxWidth: ui(190)),
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(14),
                    vertical: ui(4),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4E20D3),
                    borderRadius: BorderRadius.circular(ui(18)),
                  ),
                  child: Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'PingFang SC',
                      fontSize: ui(14),
                      height: 1,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ui(8),
            child: Text(
              '学音乐就用音乐之路 APP',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontFamily: 'PingFang SC',
                fontSize: ui(6),
                height: 1,
                fontWeight: AppFont.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0x00FFFFFF),
          Color(0xA8FFFFFF),
          Color(0x00FFFFFF),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final purple = Paint()
      ..color = const Color(0x4D4423D4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (var i = 0; i < 24; i++) {
      final y = size.height * (0.13 + i * 0.034);
      final amplitude = 4.0 + i * 0.45;
      final path = Path()..moveTo(-8, y);
      for (double x = -8; x <= size.width + 8; x += 4) {
        final wave = math.sin((x / size.width * math.pi * 3.2) + i * 0.22);
        path.lineTo(x, y + wave * amplitude);
      }
      canvas.drawPath(path, i.isEven ? glow : purple);
    }

    final flare = Paint()
      ..shader =
          RadialGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: 0.78),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.52, size.height * 0.08),
              radius: size.width * 0.52,
            ),
          );
    canvas.drawRect(Offset.zero & size, flare);
  }

  @override
  bool shouldRepaint(covariant _GuideWavePainter oldDelegate) => false;
}
