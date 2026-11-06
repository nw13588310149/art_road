// ─────────────────────────────────────────────────────────────────────────────
// school_quiz_practice_page.dart
// 校园刷题页 — 样式与公开刷题页一致，接口携带真实 schoolId。
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../school/state/school_page_controller.dart';
import '../../shell/ui/shell_layout.dart';
import '../../quiz_practice/state/quiz_practice_controller.dart';
import '../../quiz_practice/state/quiz_practice_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ── 页面入口 ────────────────────────────────────────────────────────────────

class SchoolQuizPracticePage extends ConsumerWidget {
  const SchoolQuizPracticePage({super.key});

  String _resolveSchoolId(WidgetRef ref) {
    final stored = ref.watch(appStorageProvider).schoolId;
    if (stored != '0' && stored.isNotEmpty) {
      return stored;
    }
    final fromPage = ref.watch(schoolPageControllerProvider).schoolId;
    return fromPage != '0' ? fromPage : kPublicQuizSchoolId;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = _resolveSchoolId(ref);
    final provider = quizPracticeControllerProvider(schoolId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    ref.listen<QuizPracticeState>(provider, (previous, next) {
      final msg = next.errorMessage;
      if (msg.isEmpty || msg == previous?.errorMessage) return;
      AppToast.show(context, msg);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: ui(240), child: const _CampBanner()),
        SizedBox(height: ui(12)),
        Expanded(
          child: ShellPageSurface(
            padding: EdgeInsets.symmetric(horizontal: ui(25)),
            child: state.loading && state.summaries.isEmpty
                ? const SizedBox.shrink()
                : _PracticeRingRow(
                    summaries: state.summaries,
                    onSelect: (summary) =>
                        _openSession(context, controller, schoolId, summary),
                    onRefresh: controller.refresh,
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSession(
    BuildContext context,
    QuizPracticeController controller,
    String schoolId,
    QuizPracticeSummary summary,
  ) async {
    final args = await controller.buildSessionArgs(summary);
    if (!context.mounted) return;
    if (args == null) {
      AppToast.show(context, '暂无可练习题目');
      return;
    }
    await Navigator.pushNamed(context, RoutePaths.campAnswer, arguments: args);
    if (!context.mounted) return;
    await controller.refresh();
  }
}

// ── Banner ──────────────────────────────────────────────────────────────────

class _CampBanner extends StatelessWidget {
  const _CampBanner();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(16)),
      child: Image.asset(
        'assets/images/home/camp_banner.jpg',
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, _, _) => const _CampBannerFallback(),
      ),
    );
  }
}

class _CampBannerFallback extends StatelessWidget {
  const _CampBannerFallback();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(36)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '刷题练习',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ui(26),
                    fontWeight: AppFont.w600,
                    fontFamily: 'PingFang SC',
                  ),
                ),
                SizedBox(height: ui(8)),
                Text(
                  '夯实基础 · 知识点专项突破',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: ui(14),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.menu_book_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: ui(64),
          ),
        ],
      ),
    );
  }
}

// ── 圆环卡片行 ───────────────────────────────────────────────────────────────

class _PracticeRingRow extends StatelessWidget {
  const _PracticeRingRow({
    required this.summaries,
    required this.onSelect,
    required this.onRefresh,
  });

  final List<QuizPracticeSummary> summaries;
  final ValueChanged<QuizPracticeSummary> onSelect;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return Center(
        child: TextButton(onPressed: onRefresh, child: const Text('点击重试')),
      );
    }
    return Center(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final s in summaries)
            Expanded(
              child: _PracticeRingCard(summary: s, onTap: () => onSelect(s)),
            ),
        ],
      ),
    );
  }
}

class _PracticeRingCard extends StatelessWidget {
  const _PracticeRingCard({required this.summary, required this.onTap});

  final QuizPracticeSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final accent = summary.type.accentColor;
    final ringSize = ui(187);
    final innerSize = ui(134);
    final pillWidth = ui(84);
    final pillHeight = ui(42);
    final pillInnerWidth = ui(66);
    final pillInnerHeight = ui(22);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
          height: ringSize + pillHeight / 2,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: summary.progress,
                    color: accent,
                    trackColor: const Color(0xFFF8F8F8),
                    strokeWidth: ui(8),
                  ),
                ),
              ),
              Positioned(
                top: (ringSize - innerSize) / 2,
                child: Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.30),
                        blurRadius: ui(20),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${summary.progressPercent}%',
                        style: TextStyle(
                          color: const Color(0xFF000000),
                          fontSize: ui(30),
                          fontFamily: 'Barlow',
                          fontWeight: AppFont.w600,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: ui(8)),
                      Text(
                        summary.type.label,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: ui(14),
                          fontWeight: AppFont.w400,
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  width: pillWidth,
                  height: pillHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(pillHeight / 2),
                  ),
                  child: Container(
                    width: pillInnerWidth,
                    height: pillInnerHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(pillInnerHeight / 2),
                    ),
                    child: Text(
                      '${summary.doneCount}/${summary.allCount}',
                      style: TextStyle(
                        color: const Color(0xFF000000),
                        fontSize: ui(11),
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

// ── 圆环 Painter ─────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    final track = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (progress <= 0) return;
    final fg = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi / 2, math.pi * 2 * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
