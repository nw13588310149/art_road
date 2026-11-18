import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../artworks/data/artwork_models.dart';
import '../../../artworks/state/artwork_voice_player.dart';
import '../../../artworks/ui/widgets/artwork_mark_list.dart';
import '../../../artworks/ui/widgets/artwork_voice_note.dart';
import '../../data/exam_critique_models.dart';
import '../../state/exam_critique_controller.dart';
import '../../state/study_detail_providers.dart';
import '../widgets/critique_canvas.dart';
import 'study_paper_compare.dart';

/// 原卷查看的「讲评」模式：左边画布是选中的那张讲评卷和老师标的几处，右栏按
/// 我的原卷、我这一档、上一档、其他档列出讲评卷。点编号或列表里的一处，弹出这一处的
/// 讲评并播放语音；一页共用一个播放器。打开即算听过。
class StudyPaperCritiqueView extends ConsumerStatefulWidget {
  const StudyPaperCritiqueView({
    required this.examId,
    required this.subjectId,
    required this.wide,
    super.key,
  });

  final String examId;
  final String subjectId;
  final bool wide;

  @override
  ConsumerState<StudyPaperCritiqueView> createState() =>
      _StudyPaperCritiqueViewState();
}

class _StudyPaperCritiqueViewState
    extends ConsumerState<StudyPaperCritiqueView> {
  final _popover = OverlayPortalController();
  final _popoverLink = LayerLink();

  /// 图上编号、浮层和列表算一组：点它们不会关掉浮层。
  final _markGroup = Object();
  final _rowKeys = <String, GlobalKey>{};

  StudySubjectKey get _key =>
      StudySubjectKey(examId: widget.examId, subjectId: widget.subjectId);

  /// 点图上编号或列表行：选中、打开浮层、播这一处的语音。再点同一个编号收起。
  void _selectMark(NumberedArtworkMark item, {bool fromList = false}) {
    final controller = ref.read(studentCritiqueProvider(_key).notifier);
    final player = ref.read(artworkVoicePlayerProvider.notifier);
    final previous = ref.read(studentCritiqueProvider(_key)).selectedMarkKey;
    if (previous == item.key && !fromList) {
      _closeMark();
      return;
    }
    controller.selectMark(item.key);
    _popover.show();
    if (item.mark.hasVoice) {
      player.play(
        artworkMarkPlayKey(item),
        item.mark.voiceUrl,
        seconds: item.mark.voiceSeconds,
      );
    } else if (previous != null) {
      player.stopIfActive('mark:$previous');
    }
    if (!fromList) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final row = _rowKeys[item.key]?.currentContext;
        if (mounted && row != null) {
          Scrollable.ensureVisible(row, alignment: 0.3);
        }
      });
    }
  }

  void _closeMark() {
    ref.read(studentCritiqueProvider(_key).notifier).selectMark(null);
    _popover.hide();
  }

  void _selectPaper(CritiquePaper paper) {
    _popover.hide();
    ref.read(artworkVoicePlayerProvider.notifier).stop();
    ref.read(studentCritiqueProvider(_key).notifier).selectPaper(paper.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = studentCritiqueProvider(_key);
    final state = ref.watch(provider);
    ref.listen<StudentCritiqueState>(provider, (previous, next) {
      final critique = next.critique;
      if (critique != null && !critique.read && previous?.critique == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(provider.notifier).markRead();
        });
      }
    });
    final critique = state.critique;
    if (critique == null) {
      final body = state.failed
          ? StudyPaperMessage(
              icon: Icons.cloud_off_rounded,
              text: state.errorMessage.isEmpty ? '讲评加载失败' : state.errorMessage,
              actionLabel: '重试',
              onAction: ref.read(provider.notifier).load,
            )
          : const Center(child: AppLoadingIndicator());
      return AppCanvasLayout(
        wide: widget.wide,
        canvasColor: AppColors.canvasDark,
        canvas: body,
        panel: const SizedBox.shrink(),
      );
    }
    final section = state.selectedSection;
    if (section == null) {
      return AppCanvasLayout(
        wide: widget.wide,
        canvasColor: AppColors.canvasDark,
        canvas: const StudyPaperMessage(
          icon: Icons.record_voice_over_outlined,
          text: '老师还没有发布这一科的讲评',
        ),
        panel: const SizedBox.shrink(),
      );
    }
    final paper = section.paper;
    final marks = paper.numberedMarks(paper.id);
    for (final item in marks) {
      _rowKeys.putIfAbsent(item.key, GlobalKey.new);
    }
    final selectedMark = marks
        .where((m) => m.key == state.selectedMarkKey)
        .firstOrNull;
    return AppCanvasLayout(
      wide: widget.wide,
      canvasColor: AppColors.canvasDark,
      hint: [
        '${section.label} · ${critiquePaperLabel(paper)}',
        if (marks.isNotEmpty) '点编号看这一处讲评',
      ].join(' · '),
      canvas: OverlayPortal(
        controller: _popover,
        overlayChildBuilder: (_) => _buildPopover(selectedMark),
        child: CritiqueCanvas(
          key: ValueKey<String>('critique-canvas-${paper.id}'),
          imageUrl: paper.imageUrl,
          marks: marks,
          selectedKey: selectedMark?.key,
          selectedLink: _popoverLink,
          tapGroup: _markGroup,
          watermarkText: critique.watermarkText,
          onTapPin: (key) =>
              _selectMark(marks.firstWhere((m) => m.key == key)),
        ),
      ),
      panel: TapRegion(
        groupId: _markGroup,
        child: _CritiquePanel(
          critique: critique,
          sections: state.sections,
          selected: section,
          marks: marks,
          selectedMarkKey: selectedMark?.key,
          rowKeys: _rowKeys,
          onSelectPaper: _selectPaper,
          onSelectMark: (item) => _selectMark(item, fromList: true),
        ),
      ),
    );
  }

  Widget _buildPopover(NumberedArtworkMark? item) {
    if (item == null) {
      return const SizedBox.shrink();
    }
    // 编号在卷子左侧时浮层放右边，在下半部时向上展开，尽量不出画面。
    final right = item.mark.x <= 0.6;
    final down = item.mark.y <= 0.6;
    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: _popoverLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment(right ? 1 : -1, down ? -1 : 1),
        followerAnchor: Alignment(right ? -1 : 1, down ? -1 : 1),
        child: TapRegion(
          groupId: _markGroup,
          onTapOutside: (_) => _closeMark(),
          child: ArtworkMarkPopover(item: item, onClose: _closeMark),
        ),
      ),
    );
  }
}

/// 讲评的右栏：一行出处，下面按先后列出讲评卷；选中的那张展开总结、语音和几处讲评。
class _CritiquePanel extends StatelessWidget {
  const _CritiquePanel({
    required this.critique,
    required this.sections,
    required this.selected,
    required this.marks,
    required this.selectedMarkKey,
    required this.rowKeys,
    required this.onSelectPaper,
    required this.onSelectMark,
  });

  final StudentExamCritique critique;
  final List<CritiqueSection> sections;
  final CritiqueSection selected;
  final List<NumberedArtworkMark> marks;
  final String? selectedMarkKey;
  final Map<String, GlobalKey> rowKeys;
  final ValueChanged<CritiquePaper> onSelectPaper;
  final ValueChanged<NumberedArtworkMark> onSelectMark;

  @override
  Widget build(BuildContext context) {
    final teacher = critique.teacherName;
    final date = critique.publishTime.length >= 10
        ? critique.publishTime.substring(5, 10)
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          [
            '${critique.subjectName} · 讲评',
            if (teacher.isNotEmpty) '$teacher老师',
            if (date.isNotEmpty) '$date 发布',
          ].join(' · '),
          style: AppText.caption12,
        ),
        const SizedBox(height: AppSpace.s4),
        Text(
          critique.myGrade.isEmpty
              ? '共 ${sections.length} 张讲评卷'
              : '我是 ${critique.myGrade} 档 · 共 ${sections.length} 张讲评卷',
          style: AppText.title16,
        ),
        const SizedBox(height: AppSpace.s12),
        const AppRule(),
        for (final section in sections) ...[
          _PaperRow(
            section: section,
            selected: section.paper.id == selected.paper.id,
            onTap: () => onSelectPaper(section.paper),
          ),
          if (section.paper.id == selected.paper.id)
            _PaperDetail(
              paper: section.paper,
              showTeacher: section.paper.teacherName != teacher,
              marks: marks,
              selectedMarkKey: selectedMarkKey,
              rowKeys: rowKeys,
              onSelectMark: onSelectMark,
            ),
          const AppRule(),
        ],
        const SizedBox(height: AppSpace.s12),
        Text(
          critique.showNames ? '讲评卷仅供本场考生学习，请勿外传' : '代表卷不显示姓名，仅供本场考生学习',
          style: AppText.caption12,
        ),
      ],
    );
  }
}

class _PaperRow extends StatelessWidget {
  const _PaperRow({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final CritiqueSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paper = section.paper;
    final label = critiquePaperLabel(paper);
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '${section.label}，$label，${paper.marks.length} 处讲评',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(section.label, style: AppText.caption12),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: selected ? AppText.body14Strong : AppText.body14,
                    ),
                  ],
                ),
              ),
              Text(
                paper.marks.isEmpty ? '总结' : '${paper.marks.length} 处',
                style: AppText.caption12,
              ),
              if (!selected) ...[
                const SizedBox(width: AppSpace.s4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textPlaceholder,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 选中的那张：老师、总结、总结语音和卷面上的几处。
class _PaperDetail extends StatelessWidget {
  const _PaperDetail({
    required this.paper,
    required this.showTeacher,
    required this.marks,
    required this.selectedMarkKey,
    required this.rowKeys,
    required this.onSelectMark,
  });

  final CritiquePaper paper;

  /// 这张由另一位老师讲评时写出是谁；和右栏顶上的老师相同时不重复。
  final bool showTeacher;
  final List<NumberedArtworkMark> marks;
  final String? selectedMarkKey;
  final Map<String, GlobalKey> rowKeys;
  final ValueChanged<NumberedArtworkMark> onSelectMark;

  @override
  Widget build(BuildContext context) {
    final summary = paper.summary.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTeacher && paper.teacherName.isNotEmpty)
            Text('${paper.teacherName}老师', style: AppText.caption12Strong),
          if (summary.isNotEmpty) ...[
            Text(
              summary,
              style: AppText.body14.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (paper.hasVoice)
            Transform.translate(
              offset: const Offset(-6, 0),
              child: ArtworkVoiceNoteButton(
                playKey: 'summary:${paper.id}',
                source: paper.voiceUrl,
                seconds: paper.voiceSeconds,
              ),
            ),
          if (marks.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            ArtworkMarkList(
              marks: marks,
              selectedKey: selectedMarkKey,
              rowKeys: rowKeys,
              onSelect: onSelectMark,
            ),
          ],
        ],
      ),
    );
  }
}
