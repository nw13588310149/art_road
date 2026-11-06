import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/study_detail_providers.dart';
import '../standard/grade_standard_dialog.dart';
import '../widgets/grade_band_table.dart';
import '../widgets/study_common.dart';
import 'study_paper_watermark.dart';

const _viewerBackground = Color(0xFF15131D);
const _viewerPanel = Color(0xFF1E1B29);

/// 全屏查看原卷：科目切换、缩放、水印、A 档样图对照。
Future<void> openStudyPaperViewer(
  BuildContext context, {
  required StudyExamRecord exam,
  String subjectId = '',
  bool compare = false,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => StudyPaperViewerPage(
        exam: exam,
        initialSubjectId: subjectId,
        initialCompare: compare,
      ),
    ),
  );
}

class StudyPaperViewerPage extends ConsumerStatefulWidget {
  const StudyPaperViewerPage({
    required this.exam,
    this.initialSubjectId = '',
    this.initialCompare = false,
    super.key,
  });

  final StudyExamRecord exam;
  final String initialSubjectId;
  final bool initialCompare;

  @override
  ConsumerState<StudyPaperViewerPage> createState() =>
      _StudyPaperViewerPageState();
}

class _StudyPaperViewerPageState extends ConsumerState<StudyPaperViewerPage> {
  late String _subjectId;
  late bool _compare;
  double _split = 0.5;

  @override
  void initState() {
    super.initState();
    final subjects = widget.exam.subjects;
    _subjectId =
        widget.exam.subjectById(widget.initialSubjectId)?.subjectId ??
        subjects.where((s) => s.paperAvailable).firstOrNull?.subjectId ??
        subjects.firstOrNull?.subjectId ??
        '';
    _compare = widget.initialCompare;
  }

  StudySubjectKey get _key =>
      StudySubjectKey(examId: widget.exam.examId, subjectId: _subjectId);

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final subject = exam.subjectById(_subjectId);
    final paper = subject == null ? null : ref.watch(studyPaperProvider(_key));
    final standard = subject == null
        ? null
        : ref.watch(studyGradeStandardProvider(_key));

    final Widget body;
    if (subject == null || paper == null || standard == null) {
      body = const _ViewerMessage(
        icon: Icons.image_not_supported_outlined,
        text: '这场考试暂无可查看的科目',
      );
    } else if (_compare) {
      body = _CompareView(
        paper: paper,
        standard: standard,
        split: _split,
        onSplitChanged: (value) => setState(() => _split = value),
        onRetryPaper: () => ref.invalidate(studyPaperProvider(_key)),
        onRetryStandard: () => ref.invalidate(studyGradeStandardProvider(_key)),
      );
    } else {
      body = _SingleView(
        paper: paper,
        onRetry: () => ref.invalidate(studyPaperProvider(_key)),
      );
    }

    return Scaffold(
      backgroundColor: _viewerBackground,
      body: SafeArea(
        child: Column(
          children: [
            _ViewerTopBar(
              exam: exam,
              subjectId: _subjectId,
              compare: _compare,
              onSubjectChanged: (id) => setState(() => _subjectId = id),
              onToggleCompare: () => setState(() => _compare = !_compare),
              onOpenStandard: subject == null
                  ? null
                  : () => showStudyGradeStandard(
                      context,
                      examId: exam.examId,
                      subject: subject,
                    ),
            ),
            Expanded(child: body),
            if (subject != null && standard != null)
              _BandLegendBar(subject: subject, standard: standard),
          ],
        ),
      ),
    );
  }
}

class _ViewerTopBar extends StatelessWidget {
  const _ViewerTopBar({
    required this.exam,
    required this.subjectId,
    required this.compare,
    required this.onSubjectChanged,
    required this.onToggleCompare,
    required this.onOpenStandard,
  });

  final StudyExamRecord exam;
  final String subjectId;
  final bool compare;
  final ValueChanged<String> onSubjectChanged;
  final VoidCallback onToggleCompare;
  final VoidCallback? onOpenStandard;

  @override
  Widget build(BuildContext context) {
    final title = Row(
      children: [
        _RoundIconButton(
          icon: Icons.close_rounded,
          tooltip: '关闭',
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                exam.examName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ArtText.title(size: 16, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                '原卷查看 · 仅供本人学习，请勿外传',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ArtText.caption(color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
    final tabs = _DarkSegment(
      subjects: exam.subjects,
      selectedId: subjectId,
      onChanged: onSubjectChanged,
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DarkButton(
          label: '对照样图',
          icon: Icons.compare_rounded,
          active: compare,
          onTap: onToggleCompare,
        ),
        const SizedBox(width: 8),
        _DarkButton(
          label: '评分标准',
          icon: Icons.rule_rounded,
          onTap: onOpenStandard,
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 880) {
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                tabs,
                const SizedBox(width: 16),
                actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  actions,
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: tabs,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DarkSegment extends StatelessWidget {
  const _DarkSegment({
    required this.subjects,
    required this.selectedId,
    required this.onChanged,
  });

  final List<StudySubjectRecord> subjects;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final subject in subjects)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(subject.subjectId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: subject.subjectId == selectedId
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      StudySubjectIcon.iconOf(subject.subjectName),
                      size: 14,
                      color: subject.subjectId == selectedId
                          ? ArtColors.brandDeep
                          : Colors.white60,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      subject.subjectName,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        fontFamily: 'PingFang SC',
                        fontWeight: subject.subjectId == selectedId
                            ? AppFont.w600
                            : AppFont.w400,
                        color: subject.subjectId == selectedId
                            ? ArtColors.brandDeep
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  const _DarkButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: active ? ArtColors.brand : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    color: Colors.white,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.1),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _SingleView extends StatelessWidget {
  const _SingleView({required this.paper, required this.onRetry});

  final AsyncValue<StudyPaper> paper;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return paper.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, _) => _ViewerMessage(
        icon: Icons.cloud_off_rounded,
        text: studyErrorText(error, '原卷加载失败'),
        actionLabel: '重新加载',
        onAction: onRetry,
      ),
      data: (value) {
        if (!value.viewable) {
          return _ViewerMessage(
            icon: Icons.image_not_supported_outlined,
            text: value.message.isEmpty ? '该科暂无原卷' : value.message,
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            PhotoView(
              key: ValueKey<String>(value.imageUrl),
              imageProvider: CachedNetworkImageProvider(
                MediaUrl.resolve(value.imageUrl),
              ),
              backgroundDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              initialScale: PhotoViewComputedScale.contained,
              filterQuality: FilterQuality.medium,
              loadingBuilder: (context, event) =>
                  const Center(child: AppLoadingIndicator()),
              errorBuilder: (context, error, stackTrace) => _ViewerMessage(
                icon: Icons.broken_image_outlined,
                text: '原卷图片加载失败，链接可能已过期',
                actionLabel: '重新获取',
                onAction: onRetry,
              ),
            ),
            Positioned.fill(
              child: StudyPaperWatermark(text: value.watermarkText),
            ),
            const Positioned(
              left: 16,
              bottom: 14,
              child: _HintChip(text: '双指缩放 · 双击放大'),
            ),
          ],
        );
      },
    );
  }
}

class _CompareView extends StatelessWidget {
  const _CompareView({
    required this.paper,
    required this.standard,
    required this.split,
    required this.onSplitChanged,
    required this.onRetryPaper,
    required this.onRetryStandard,
  });

  final AsyncValue<StudyPaper> paper;
  final AsyncValue<GradeStandard> standard;

  /// 左栏占比 0.2–0.8。
  final double split;
  final ValueChanged<double> onSplitChanged;
  final VoidCallback onRetryPaper;
  final VoidCallback onRetryStandard;

  @override
  Widget build(BuildContext context) {
    final sampleGrade = standard.valueOrNull?.topBand?.grade ?? 'A';
    final mine = paper.when(
      loading: () => const Center(child: AppLoadingIndicator(size: 36)),
      error: (error, _) => _ViewerMessage(
        icon: Icons.cloud_off_rounded,
        text: studyErrorText(error, '原卷加载失败'),
        actionLabel: '重新加载',
        onAction: onRetryPaper,
      ),
      data: (value) => value.viewable
          ? Stack(
              fit: StackFit.expand,
              children: [
                _ZoomableImage(url: value.imageUrl),
                Positioned.fill(
                  child: StudyPaperWatermark(text: value.watermarkText),
                ),
              ],
            )
          : _ViewerMessage(
              icon: Icons.image_not_supported_outlined,
              text: value.message.isEmpty ? '该科暂无原卷' : value.message,
            ),
    );
    final sample = standard.when(
      loading: () => const Center(child: AppLoadingIndicator(size: 36)),
      error: (error, _) => _ViewerMessage(
        icon: Icons.cloud_off_rounded,
        text: studyErrorText(error, '样图加载失败'),
        actionLabel: '重新加载',
        onAction: onRetryStandard,
      ),
      data: (value) {
        final url = value.topBand?.imageUrl ?? '';
        return url.isEmpty
            ? _ViewerMessage(
                icon: Icons.image_not_supported_outlined,
                text: '该科暂无 $sampleGrade 档样图',
              )
            : _ZoomableImage(url: url);
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        const handleWidth = 28.0;
        final available = math.max(0.0, constraints.maxWidth - handleWidth);
        final leftWidth = available * split;
        return Row(
          children: [
            SizedBox(
              width: leftWidth,
              child: _ComparePane(label: '我的原卷', child: mine),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: available <= 0
                  ? null
                  : (details) => onSplitChanged(
                      ((leftWidth + details.delta.dx) / available).clamp(
                        0.2,
                        0.8,
                      ),
                    ),
              child: const MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: SizedBox(width: handleWidth, child: _DividerHandle()),
              ),
            ),
            SizedBox(
              width: available - leftWidth,
              child: _ComparePane(label: '$sampleGrade 档样图', child: sample),
            ),
          ],
        );
      },
    );
  }
}

class _ComparePane extends StatelessWidget {
  const _ComparePane({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            left: 12,
            top: 12,
            child: IgnorePointer(child: _HintChip(text: label, strong: true)),
          ),
        ],
      ),
    );
  }
}

class _DividerHandle extends StatelessWidget {
  const _DividerHandle();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(width: 2, color: Colors.white.withValues(alpha: 0.24)),
        Container(
          width: 24,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const RotatedBox(
            quarterTurns: 1,
            child: Icon(
              Icons.unfold_more_rounded,
              size: 18,
              color: ArtColors.ink2,
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoomableImage extends StatelessWidget {
  const _ZoomableImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image(
          image: CachedNetworkImageProvider(MediaUrl.resolve(url)),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
              frame == null && !wasSynchronouslyLoaded
              ? const Center(child: AppLoadingIndicator(size: 36))
              : child,
          errorBuilder: (context, error, stackTrace) => const _ViewerMessage(
            icon: Icons.broken_image_outlined,
            text: '图片加载失败',
          ),
        ),
      ),
    );
  }
}

class _BandLegendBar extends StatelessWidget {
  const _BandLegendBar({required this.subject, required this.standard});

  final StudySubjectRecord subject;
  final AsyncValue<GradeStandard> standard;

  @override
  Widget build(BuildContext context) {
    final bands = standard.valueOrNull?.bands ?? const <GradeBandInfo>[];
    final grade = subject.grade.isNotEmpty
        ? subject.grade
        : bandForScore(bands, subject.score)?.grade ?? '';
    return Container(
      color: _viewerPanel,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Text('我的档位', style: ArtText.caption(color: Colors.white54)),
          const SizedBox(width: 10),
          if (subject.hasScore) ...[
            ArtGradeBadge(grade: grade, size: 24),
            const SizedBox(width: 8),
            StudyNumberText(
              formatScore(subject.score),
              unit: ' / ${formatScore(subject.maxScore)} 分',
              color: Colors.white,
              unitColor: Colors.white54,
            ),
          ] else
            Text('待出分', style: ArtText.body(size: 13, color: Colors.white70)),
          const SizedBox(width: 20),
          Expanded(
            child: bands.isEmpty
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: GradeBandLegend(
                      bands: bands,
                      highlightGrade: grade,
                      dark: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: strong ? 0.6 : 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.3,
          color: strong ? Colors.white : Colors.white70,
          fontFamily: 'PingFang SC',
          fontWeight: strong ? AppFont.w500 : AppFont.w400,
        ),
      ),
    );
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: ArtText.body(size: 14, color: Colors.white70),
            ),
            if (label != null && action != null) ...[
              const SizedBox(height: 14),
              ArtButton(label: label, onTap: action, height: 34),
            ],
          ],
        ),
      ),
    );
  }
}
