import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../../artworks/data/artwork_models.dart';
import '../../../artworks/ui/widgets/artwork_mark_layer.dart';
import '../../../artworks/ui/widgets/artwork_mark_list.dart';
import '../../../artworks/ui/widgets/artwork_voice_comment_field.dart';
import '../../../artworks/ui/widgets/artwork_voice_note.dart';
import '../../data/exam_critique_models.dart';
import '../../state/exam_critique_controller.dart';

/// 讲评工作台的右栏，从上到下：选中的这张卷子（加入、总结、语音、几处讲评；选中一处时
/// 改这一处），已选的讲评卷，按档位排好的全部原卷。
class ExamCritiquePanel extends StatelessWidget {
  const ExamCritiquePanel({
    required this.state,
    required this.summaryController,
    required this.markController,
    required this.markFocus,
    required this.onSelect,
    required this.onAdd,
    required this.onRemove,
    required this.onSummaryChanged,
    required this.onSummaryVoiceChanged,
    required this.onSelectMark,
    required this.onCloseMark,
    required this.onMarkTextChanged,
    required this.onMarkVoiceChanged,
    required this.onRemoveMark,
    required this.onUpload,
    super.key,
  });

  final ExamCritiqueState state;
  final TextEditingController summaryController;
  final TextEditingController markController;
  final FocusNode markFocus;
  final ValueChanged<String> onSelect;
  final void Function(String archiveId, bool shared) onAdd;
  final ValueChanged<CritiquePaper> onRemove;
  final ValueChanged<String> onSummaryChanged;
  final void Function(String path, int seconds) onSummaryVoiceChanged;
  final ValueChanged<NumberedArtworkMark> onSelectMark;
  final VoidCallback onCloseMark;
  final ValueChanged<String> onMarkTextChanged;
  final void Function(String path, int seconds) onMarkVoiceChanged;
  final void Function(ArtworkMark mark, int number) onRemoveMark;
  final ArtworkVoiceUpload onUpload;

  @override
  Widget build(BuildContext context) {
    final board = state.board!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectedPaper(panel: this, board: board),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpace.s16),
          child: AppRule(),
        ),
        _AddedPapers(
          critique: board.critique,
          selectedKey: state.selectedKey,
          canEdit: board.canEdit,
          onSelect: onSelect,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpace.s16),
          child: AppRule(),
        ),
        _AllPapers(board: board, state: state, onSelect: onSelect),
      ],
    );
  }
}

class _SelectedPaper extends StatelessWidget {
  const _SelectedPaper({required this.panel, required this.board});

  final ExamCritiquePanel panel;
  final ExamCritiqueBoard board;

  @override
  Widget build(BuildContext context) {
    final state = panel.state;
    final candidate = state.selectedCandidate;
    if (candidate == null) {
      return Text('从下面选一张卷子', style: AppText.body14);
    }
    final draft = state.draft;
    final saved = state.savedPaper;
    final kind = draft == null
        ? '还没加进讲评'
        : (draft.shared ? '代表卷' : '个人讲评 · 只给${candidate.studentName}看');
    final meta = [
      if (candidate.organizationName.isNotEmpty) candidate.organizationName,
      if (saved != null && saved.teacherName.isNotEmpty)
        '${saved.teacherName}老师'
            '${saved.updatedTime.length >= 16 ? ' ${saved.updatedTime.substring(5, 16)}' : ''}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(kind, style: AppText.caption12),
        const SizedBox(height: AppSpace.s4),
        Row(
          children: [
            Expanded(
              child: Text(
                '${candidate.grade} 档 · ${formatScore(candidate.score)} 分 · '
                '${candidate.studentName}',
                maxLines: 2,
                style: AppText.title16,
              ),
            ),
            if (saved != null && board.canEdit && state.selectedMark == null)
              AppIconAction(
                icon: Icons.delete_outline_rounded,
                semanticLabel: saved.shared ? '移出这张代表卷' : '删除这份个人讲评',
                onTap: state.saving ? null : () => panel.onRemove(saved),
              ),
          ],
        ),
        if (meta.isNotEmpty) Text(meta, style: AppText.caption12),
        const SizedBox(height: AppSpace.s12),
        if (draft == null)
          _AddActions(
            board: board,
            candidate: candidate,
            busy: state.saving,
            onAdd: panel.onAdd,
          )
        else if (state.selectedMark case final mark? when board.canEdit)
          _MarkEditor(panel: panel, draft: draft, mark: mark)
        else
          _PaperEditor(panel: panel, draft: draft, editable: board.canEdit),
      ],
    );
  }
}

/// 还没加进讲评的卷子：加为代表卷，或者只给这位学生录个人讲评。
class _AddActions extends StatelessWidget {
  const _AddActions({
    required this.board,
    required this.candidate,
    required this.busy,
    required this.onAdd,
  });

  final ExamCritiqueBoard board;
  final CritiqueCandidate candidate;
  final bool busy;
  final void Function(String archiveId, bool shared) onAdd;

  @override
  Widget build(BuildContext context) {
    if (!board.canEdit) {
      return Text('这张卷子没有讲评。', style: AppText.body13);
    }
    final full = board.critique.sharedCount >= ExamCritiqueRules.sharedPapers;
    final hasPersonal =
        board.paper(critiquePaperKey(candidate.archiveId, shared: false)) !=
        null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          full
              ? '代表卷已经选满 ${ExamCritiqueRules.sharedPapers} 张，先移出一张再加。'
              : '代表卷参加这场考试的学生都能看到；个人讲评只给这位学生看。',
          style: AppText.body13,
        ),
        const SizedBox(height: AppSpace.s12),
        Row(
          children: [
            AppButton(
              label: '加为代表卷',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.sm,
              enabled: !busy && !full,
              onTap: () => onAdd(candidate.archiveId, true),
            ),
            const SizedBox(width: AppSpace.s8),
            if (!hasPersonal)
              AppPlainButton(
                label: '录个人讲评',
                enabled: !busy,
                onTap: () => onAdd(candidate.archiveId, false),
              ),
          ],
        ),
      ],
    );
  }
}

/// 选中卷子的讲评：总结、总结语音和卷面上的几处。不能改时只读。
class _PaperEditor extends StatelessWidget {
  const _PaperEditor({
    required this.panel,
    required this.draft,
    required this.editable,
  });

  final ExamCritiquePanel panel;
  final CritiquePaper draft;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final marks = draft.numberedMarks(draft.key);
    final summary = draft.summary.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (editable) ...[
          AppInputField(
            controller: panel.summaryController,
            label: '总结（可选）',
            hint: '这张卷子整体怎么样、和上一档差在哪里',
            multiline: true,
            minLines: 3,
            maxLines: 6,
            maxLength: ExamCritiqueRules.summaryLimit,
            onChanged: panel.onSummaryChanged,
          ),
          const SizedBox(height: AppSpace.s12),
          Text('总结语音（可选）', style: AppText.caption12Strong),
          const SizedBox(height: AppSpace.s8),
          ArtworkVoiceCommentField(
            key: ValueKey<String>('summary-voice-${draft.key}'),
            path: draft.voiceUrl,
            seconds: draft.voiceSeconds,
            onUpload: panel.onUpload,
            onChanged: panel.onSummaryVoiceChanged,
          ),
        ] else ...[
          Text(
            summary.isEmpty ? '没有写总结。' : summary,
            style: summary.isEmpty
                ? AppText.body13
                : AppText.body14.copyWith(color: AppColors.textSecondary),
          ),
          if (draft.hasVoice)
            Transform.translate(
              offset: const Offset(-6, 0),
              child: ArtworkVoiceNoteButton(
                playKey: 'summary:${draft.key}',
                source: draft.voiceUrl,
                seconds: draft.voiceSeconds,
              ),
            ),
        ],
        const SizedBox(height: AppSpace.s16),
        AppSectionTitle(
          title: '卷面讲评',
          note: marks.isEmpty
              ? (editable ? '点卷面要说的位置加一处' : '')
              : '${marks.length} 处',
        ),
        const SizedBox(height: AppSpace.s4),
        if (marks.isEmpty)
          Text(
            editable ? '每张最多 ${ExamCritiqueRules.marksPerPaper} 处，每处写一句话或录一段语音。' : '没有标记。',
            style: AppText.caption12,
          )
        else
          ArtworkMarkList(
            marks: marks,
            maxLines: 2,
            selectedKey: panel.state.selectedMarkId == null
                ? null
                : '${draft.key}/${panel.state.selectedMarkId}',
            onSelect: panel.onSelectMark,
          ),
      ],
    );
  }
}

/// 选中一处时：改这一处的文字和语音，或者删掉。
class _MarkEditor extends StatelessWidget {
  const _MarkEditor({
    required this.panel,
    required this.draft,
    required this.mark,
  });

  final ExamCritiquePanel panel;
  final CritiquePaper draft;
  final ArtworkMark mark;

  @override
  Widget build(BuildContext context) {
    final number = draft.marks.indexWhere((m) => m.id == mark.id) + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ArtworkMarkDot(number: number, size: 24),
            const SizedBox(width: AppSpace.s8),
            Expanded(child: Text('第 $number 处', style: AppText.title16)),
            AppIconAction(
              icon: Icons.delete_outline_rounded,
              semanticLabel: '删除第 $number 处讲评',
              onTap: () => panel.onRemoveMark(mark, number),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s8),
        AppInputField(
          controller: panel.markController,
          focusNode: panel.markFocus,
          hint: '这一处的问题或做得好的地方，例如：暗部颜色发闷，加一点环境色',
          multiline: true,
          minLines: 3,
          maxLines: 5,
          maxLength: ExamCritiqueRules.markTextLimit,
          onChanged: panel.onMarkTextChanged,
        ),
        const SizedBox(height: AppSpace.s12),
        Text('语音（可选）', style: AppText.caption12Strong),
        const SizedBox(height: AppSpace.s8),
        ArtworkVoiceCommentField(
          key: ValueKey<String>('mark-voice-${mark.id}'),
          path: mark.voiceUrl,
          seconds: mark.voiceSeconds,
          onUpload: panel.onUpload,
          onChanged: panel.onMarkVoiceChanged,
        ),
        const SizedBox(height: AppSpace.s8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Transform.translate(
              offset: const Offset(AppSpace.s12, 0),
              child: AppPlainButton(label: '完成这一处', onTap: panel.onCloseMark),
            ),
          ],
        ),
      ],
    );
  }
}

/// 已经加进讲评的卷子。
class _AddedPapers extends StatelessWidget {
  const _AddedPapers({
    required this.critique,
    required this.selectedKey,
    required this.canEdit,
    required this.onSelect,
  });

  final ExamCritique critique;
  final String selectedKey;
  final bool canEdit;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final papers = critique.papers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionTitle(
          title: '讲评卷',
          note:
              '代表卷 ${critique.sharedCount} / ${ExamCritiqueRules.sharedPapers}'
              '${critique.personalCount > 0 ? ' · 个人 ${critique.personalCount}' : ''}',
        ),
        const SizedBox(height: AppSpace.s4),
        if (papers.isEmpty)
          Text(
            canEdit ? '还没有选卷子。从下面每一档挑一张，标有「建议」的分数最接近这一档的中间。' : '还没有讲评卷。',
            style: AppText.caption12,
          )
        else
          for (final paper in papers)
            _PaperLine(
              title:
                  '${paper.grade} 档 · ${formatScore(paper.score)} 分 · ${paper.studentName}',
              note: paper.shared ? '代表卷' : '个人',
              trailing: paper.hasContent
                  ? (paper.marks.isEmpty ? '总结' : '${paper.marks.length} 处')
                  : '还没有内容',
              selected: paper.key == selectedKey,
              onTap: () => onSelect(paper.key),
            ),
      ],
    );
  }
}

/// 全部原卷，按档位分组；没有卷子的档位也列出来，写明这一档没有。
class _AllPapers extends StatelessWidget {
  const _AllPapers({
    required this.board,
    required this.state,
    required this.onSelect,
  });

  final ExamCritiqueBoard board;
  final ExamCritiqueState state;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final added = {
      for (final paper in board.critique.papers)
        if (paper.shared) paper.archiveId,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionTitle(
          title: '全部原卷',
          note: '${board.candidates.length} 张 · 「建议」最接近这一档的中间分',
        ),
        for (final band in board.bands) ...[
          const SizedBox(height: AppSpace.s12),
          Text(
            '${band.grade} 档 · ${formatScore(band.min)}–${formatScore(band.max)}'
            ' · ${band.count} 张',
            style: AppText.caption12Strong,
          ),
          if (band.count == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
              child: Text('这一档没有卷子', style: AppText.caption12),
            )
          else
            for (final candidate in board.candidatesIn(band.grade))
              _PaperLine(
                title:
                    '${candidate.studentName} · ${formatScore(candidate.score)} 分',
                note: candidate.suggested ? '建议' : '',
                trailing: added.contains(candidate.archiveId) ? '已选' : '',
                selected:
                    state.selectedArchiveId == candidate.archiveId &&
                    state.selectedShared,
                onTap: () => onSelect(
                  critiquePaperKey(candidate.archiveId, shared: true),
                ),
              ),
        ],
      ],
    );
  }
}

/// 右栏里的一行卷子：整行可点，选中的加粗。
class _PaperLine extends StatelessWidget {
  const _PaperLine({
    required this.title,
    required this.note,
    required this.trailing,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String note;
  final String trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: [title, note, trailing].where((t) => t.isNotEmpty).join('，'),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: selected ? AppText.body14Strong : AppText.body14,
                    ),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(width: AppSpace.s8),
                    AppStatusTag(label: note, color: AppColors.textSecondary),
                  ],
                ],
              ),
            ),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: AppSpace.s8),
              Text(trailing, style: AppText.caption12),
            ],
          ],
        ),
      ),
    );
  }
}
