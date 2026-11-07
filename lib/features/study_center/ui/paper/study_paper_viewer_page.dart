import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../../state/study_detail_providers.dart';
import '../standard/grade_standard_dialog.dart';
import '../widgets/grade_band_table.dart';
import '../widgets/study_common.dart';
import 'study_paper_watermark.dart';

/// 深色看图页上的次级文字与分隔线。
final _onDarkMuted = AppColors.onBrand.withValues(alpha: 0.64);
final _onDarkLine = AppColors.onBrand.withValues(alpha: 0.12);

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
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            _ViewerTopBar(
              exam: exam,
              subjectId: _subjectId,
              compare: _compare,
              onSubjectChanged: (id) => setState(() => _subjectId = id),
              onCompareChanged: (value) => setState(() => _compare = value),
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
    required this.onCompareChanged,
    required this.onOpenStandard,
  });

  final StudyExamRecord exam;
  final String subjectId;
  final bool compare;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<bool> onCompareChanged;
  final VoidCallback? onOpenStandard;

  @override
  Widget build(BuildContext context) {
    final title = Row(
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                exam.examName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title16.copyWith(color: AppColors.onBrand),
              ),
              Text(
                '原卷查看 · 仅供本人学习，请勿外传',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption12.copyWith(color: _onDarkMuted),
              ),
            ],
          ),
        ),
      ],
    );
    final subjects = AppSegmented<String>(
      size: AppControlSize.sm,
      segments: [
        for (final subject in exam.subjects)
          AppSegment(value: subject.subjectId, label: subject.subjectName),
      ],
      value: subjectId,
      onChanged: onSubjectChanged,
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSegmented<bool>(
          size: AppControlSize.sm,
          segments: const [
            AppSegment(value: false, label: '原卷'),
            AppSegment(value: true, label: '对照样图'),
          ],
          value: compare,
          onChanged: onCompareChanged,
        ),
        const SizedBox(width: AppSpace.s8),
        AppButton(
          label: '评分标准',
          icon: Icons.rule_rounded,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.sm,
          onTap: onOpenStandard,
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s12,
        AppSpace.s8,
        AppSpace.s16,
        AppSpace.s8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 880) {
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpace.s16),
                subjects,
                const SizedBox(width: AppSpace.s16),
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
                  const SizedBox(width: AppSpace.s12),
                  actions,
                ],
              ),
              const SizedBox(height: AppSpace.s8),
              Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: subjects,
                ),
              ),
            ],
          );
        },
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
        actionLabel: '重试',
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
                color: AppColors.ink,
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
              left: AppSpace.s16,
              bottom: AppSpace.s12,
              child: _HintLabel(text: '双指缩放 · 双击放大'),
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
        actionLabel: '重试',
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
        actionLabel: '重试',
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
            left: AppSpace.s12,
            top: AppSpace.s12,
            child: IgnorePointer(child: _HintLabel(text: label, strong: true)),
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
        Container(width: 2, color: _onDarkLine),
        Container(
          width: 24,
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.br12,
            boxShadow: AppShadow.thumb,
          ),
          child: const RotatedBox(
            quarterTurns: 1,
            child: Icon(
              Icons.unfold_more_rounded,
              size: 18,
              color: AppColors.textSecondary,
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
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s20,
        AppSpace.s12,
        AppSpace.s20,
        AppSpace.s12,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _onDarkLine)),
      ),
      child: Row(
        children: [
          Text(
            '我的档位',
            style: AppText.caption12.copyWith(color: _onDarkMuted),
          ),
          const SizedBox(width: AppSpace.s12),
          if (subject.hasScore) ...[
            StudyGradeTag(grade: grade),
            const SizedBox(width: AppSpace.s8),
            StudyNumberText(
              formatScore(subject.score),
              unit: ' / ${formatScore(subject.maxScore)} 分',
              color: AppColors.onBrand,
              unitColor: _onDarkMuted,
            ),
          ] else
            Text(
              '待出分',
              style: AppText.body13.copyWith(color: _onDarkMuted),
            ),
          const SizedBox(width: AppSpace.s20),
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

class _HintLabel extends StatelessWidget {
  const _HintLabel({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s8,
        vertical: AppSpace.s4,
      ),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: strong ? 0.72 : 0.56),
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        text,
        style: (strong ? AppText.caption12Strong : AppText.caption12).copyWith(
          color: AppColors.onBrand,
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
        padding: const EdgeInsets.all(AppSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: _onDarkMuted),
            const SizedBox(height: AppSpace.s12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppText.body14.copyWith(color: AppColors.onBrand),
            ),
            if (label != null && action != null) ...[
              const SizedBox(height: AppSpace.s16),
              AppButton(
                label: label,
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onTap: action,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
