import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../core/network/media_url.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_models.dart';
import '../../state/study_detail_providers.dart';
import '../standard/grade_standard_dialog.dart';
import 'study_paper_compare.dart';
import 'study_paper_critique.dart';
import 'study_paper_panel.dart';
import 'study_paper_watermark.dart';

/// 原卷查看的三种模式：原卷、老师讲评（这一科发布了讲评时才有）、对照样图。
enum StudyPaperMode { paper, critique, compare }

/// 全屏查看原卷：科目切换、缩放、水印、老师讲评、A 档样图对照。
Future<void> openStudyPaperViewer(
  BuildContext context, {
  required StudyExamRecord exam,
  String subjectId = '',
  bool compare = false,
  bool critique = false,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => StudyPaperViewerPage(
        exam: exam,
        initialSubjectId: subjectId,
        initialMode: compare
            ? StudyPaperMode.compare
            : (critique ? StudyPaperMode.critique : StudyPaperMode.paper),
      ),
    ),
  );
}

/// 原卷查看是沉浸页：不带外壳，白色顶栏下面是深色画布加右侧面板；对照样图时两张
/// 卷子并排，面板收起。
class StudyPaperViewerPage extends ConsumerStatefulWidget {
  const StudyPaperViewerPage({
    required this.exam,
    this.initialSubjectId = '',
    this.initialMode = StudyPaperMode.paper,
    super.key,
  });

  final StudyExamRecord exam;
  final String initialSubjectId;
  final StudyPaperMode initialMode;

  @override
  ConsumerState<StudyPaperViewerPage> createState() =>
      _StudyPaperViewerPageState();
}

class _StudyPaperViewerPageState extends ConsumerState<StudyPaperViewerPage> {
  late String _subjectId;
  late StudyPaperMode _mode;
  final _compareView = AppCompareController(
    modes: const [AppCompareMode.sideBySide],
  );

  @override
  void initState() {
    super.initState();
    final subjects = widget.exam.subjects;
    final critique = widget.initialMode == StudyPaperMode.critique;
    _subjectId =
        widget.exam.subjectById(widget.initialSubjectId)?.subjectId ??
        (critique
            ? subjects.where((s) => s.critiqueAvailable).firstOrNull?.subjectId
            : null) ??
        subjects.where((s) => s.paperAvailable).firstOrNull?.subjectId ??
        subjects.firstOrNull?.subjectId ??
        '';
    _mode = _modeFor(_subjectId, widget.initialMode);
  }

  @override
  void dispose() {
    _compareView.dispose();
    super.dispose();
  }

  /// 换到没有讲评的科目时，讲评模式退回原卷。
  StudyPaperMode _modeFor(String subjectId, StudyPaperMode wanted) =>
      wanted == StudyPaperMode.critique &&
          !(widget.exam.subjectById(subjectId)?.critiqueAvailable ?? false)
      ? StudyPaperMode.paper
      : wanted;

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
      body = const StudyPaperMessage(
        icon: Icons.image_not_supported_outlined,
        text: '这场考试暂无可查看的科目',
        dark: false,
      );
    } else if (_mode == StudyPaperMode.critique) {
      body = AppPageBody(
        scrollable: false,
        builder: (context, wide) => StudyPaperCritiqueView(
          key: ValueKey<String>('critique-${subject.subjectId}'),
          examId: exam.examId,
          subjectId: subject.subjectId,
          wide: wide,
        ),
      );
    } else if (_mode == StudyPaperMode.compare) {
      body = AppPageBody(
        scrollable: false,
        builder: (context, wide) => StudyPaperCompareView(
          paper: paper,
          standard: standard,
          controller: _compareView,
          onRetryPaper: () => ref.invalidate(studyPaperProvider(_key)),
          onRetryStandard: () =>
              ref.invalidate(studyGradeStandardProvider(_key)),
        ),
      );
    } else {
      body = AppPageBody(
        scrollable: false,
        builder: (context, wide) => AppCanvasLayout(
          wide: wide,
          canvasColor: AppColors.canvasDark,
          hint: '双指缩放 · 双击放大',
          canvas: _SingleView(
            paper: paper,
            onRetry: () => ref.invalidate(studyPaperProvider(_key)),
          ),
          panel: StudyPaperPanel(
            exam: exam,
            subject: subject,
            standard: standard,
            onRetryStandard: () =>
                ref.invalidate(studyGradeStandardProvider(_key)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ViewerTopBar(
              exam: exam,
              subjectId: _subjectId,
              mode: _mode,
              critiqueAvailable: subject?.critiqueAvailable ?? false,
              onSubjectChanged: (id) {
                _compareView.reset();
                setState(() {
                  _subjectId = id;
                  _mode = _modeFor(id, _mode);
                });
              },
              onModeChanged: (value) => setState(() => _mode = value),
              onOpenStandard: subject == null
                  ? null
                  : () => showStudyGradeStandard(
                      context,
                      examId: exam.examId,
                      subject: subject,
                      subjects: exam.subjects,
                    ),
            ),
            const AppRule(),
            Expanded(child: body),
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
    required this.mode,
    required this.critiqueAvailable,
    required this.onSubjectChanged,
    required this.onModeChanged,
    required this.onOpenStandard,
  });

  final StudyExamRecord exam;
  final String subjectId;
  final StudyPaperMode mode;
  final bool critiqueAvailable;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<StudyPaperMode> onModeChanged;
  final VoidCallback? onOpenStandard;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
      alignment: Alignment.center,
      child: AppTitleBar(
        title: exam.examName,
        caption: '仅供本人学习，请勿外传',
        onBack: () => Navigator.of(context).maybePop(),
        backLabel: '关闭原卷',
        tabs: exam.subjects.length > 1
            ? AppViewTabs<String>(
                items: [
                  for (final subject in exam.subjects)
                    AppViewTab(
                      value: subject.subjectId,
                      label: subject.subjectName,
                    ),
                ],
                value: subjectId,
                onChanged: onSubjectChanged,
              )
            : null,
        actions: [
          AppViewTabs<StudyPaperMode>(
            dense: true,
            items: [
              const AppViewTab(value: StudyPaperMode.paper, label: '原卷'),
              if (critiqueAvailable)
                const AppViewTab(value: StudyPaperMode.critique, label: '讲评'),
              const AppViewTab(value: StudyPaperMode.compare, label: '对照样图'),
            ],
            value: mode,
            onChanged: onModeChanged,
          ),
          const SizedBox(width: AppSpace.s16),
          AppPlainButton(
            label: '评分标准',
            icon: Icons.rule_rounded,
            onTap: onOpenStandard,
          ),
        ],
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
      error: (error, _) => StudyPaperMessage(
        icon: Icons.cloud_off_rounded,
        text: studyErrorText(error, '原卷加载失败'),
        actionLabel: '重试',
        onAction: onRetry,
      ),
      data: (value) {
        if (!value.viewable) {
          return StudyPaperMessage(
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
                color: AppColors.canvasDark,
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              initialScale: PhotoViewComputedScale.contained,
              filterQuality: FilterQuality.medium,
              loadingBuilder: (context, event) =>
                  const Center(child: AppLoadingIndicator()),
              errorBuilder: (context, error, stackTrace) => StudyPaperMessage(
                icon: Icons.broken_image_outlined,
                text: '原卷图片加载失败，链接可能已过期',
                actionLabel: '重新获取',
                onAction: onRetry,
              ),
            ),
            Positioned.fill(
              child: StudyPaperWatermark(text: value.watermarkText),
            ),
          ],
        );
      },
    );
  }
}
