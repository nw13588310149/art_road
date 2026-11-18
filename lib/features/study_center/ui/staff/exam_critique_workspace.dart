import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../../artworks/data/artwork_models.dart';
import '../../data/exam_critique_models.dart';
import '../../state/exam_critique_controller.dart';
import '../paper/study_paper_compare.dart';
import '../widgets/critique_canvas.dart';
import 'exam_critique_panel.dart';

/// 打开讲评工作台。[personalArchiveId] 不为空时直接给那位学生录个人讲评。
Future<void> openExamCritiqueWorkspace(
  BuildContext context, {
  required String examId,
  required String subjectId,
  String personalArchiveId = '',
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ExamCritiqueWorkspace(
        args: CritiqueWorkspaceArgs(
          examId: examId,
          subjectId: subjectId,
          personalArchiveId: personalArchiveId,
        ),
      ),
    ),
  );
}

/// 月考讲评工作台（沉浸页）：白色顶栏下面左边是卷子和老师标的几处，右栏是选中卷子的
/// 讲评、已选的讲评卷和按档位排好的全部原卷。能改的老师点卷面加一处，写一句话或录一段
/// 语音；先存草稿，发布后学生才看得到。
class ExamCritiqueWorkspace extends ConsumerStatefulWidget {
  const ExamCritiqueWorkspace({required this.args, super.key});

  final CritiqueWorkspaceArgs args;

  @override
  ConsumerState<ExamCritiqueWorkspace> createState() =>
      _ExamCritiqueWorkspaceState();
}

class _ExamCritiqueWorkspaceState extends ConsumerState<ExamCritiqueWorkspace> {
  final _summary = TextEditingController();
  final _markText = TextEditingController();
  final _markFocus = FocusNode();
  final _panelScroll = ScrollController();
  bool _leaving = false;

  AutoDisposeStateNotifierProvider<ExamCritiqueController, ExamCritiqueState>
  get _provider => examCritiqueControllerProvider(widget.args);

  ExamCritiqueController get _controller => ref.read(_provider.notifier);

  @override
  void dispose() {
    _summary.dispose();
    _markText.dispose();
    _markFocus.dispose();
    _panelScroll.dispose();
    super.dispose();
  }

  /// 选中的卷子和这一处都在右栏最上面：换了选择就回到顶上。
  void _revealSelection(ExamCritiqueState? previous, ExamCritiqueState next) {
    final changed =
        previous?.selectedKey != next.selectedKey ||
        (next.selectedMarkId != null &&
            previous?.selectedMarkId != next.selectedMarkId);
    if (!changed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _panelScroll.hasClients) _panelScroll.jumpTo(0);
    });
  }

  /// 换了卷子或换了一处时，输入框换成那一份的文字。
  void _syncFields(ExamCritiqueState? previous, ExamCritiqueState next) {
    final reloaded = !identical(previous?.board, next.board);
    if (reloaded || previous?.draft?.key != next.draft?.key) {
      final text = next.draft?.summary ?? '';
      if (_summary.text != text) _summary.text = text;
    }
    if (reloaded || previous?.selectedMarkId != next.selectedMarkId) {
      final text = next.selectedMark?.text ?? '';
      if (_markText.text != text) _markText.text = text;
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    final state = ref.read(_provider);
    if (state.dirty) {
      final discard = await showAppConfirm(
        context: context,
        title: '有没保存的讲评',
        message: '离开后这张卷子上的改动不会保存。',
        confirmLabel: '不保存，离开',
        cancelLabel: '继续编辑',
        danger: true,
      );
      if (!discard || !mounted) return;
    }
    _leaving = true;
    Navigator.of(context).pop();
  }

  Future<void> _publish(ExamCritiqueState state) async {
    final board = state.board;
    if (board == null) return;
    final ready = board.critique.papers.where((p) => p.hasContent).length;
    final draftReady = state.draft?.hasContent ?? false;
    if (ready == 0 && !draftReady) {
      AppToast.showError(context, '先给至少一张卷子录上讲评，再发布');
      return;
    }
    final result = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => _PublishDialog(
        sharedCount: board.critique.sharedCount,
        personalCount: board.critique.personalCount,
        initialShowNames: board.critique.showNames,
        onConfirm: (showNames) async {
          final ok = await _controller.setPublished(true, showNames: showNames);
          if (dialogContext.mounted) Navigator.of(dialogContext).pop(ok);
        },
      ),
    );
    if (result == true && mounted) {
      AppToast.showSuccess(context, '讲评已发布，学生会收到消息');
    }
  }

  Future<void> _unpublish() async {
    final confirmed = await showAppConfirm(
      context: context,
      title: '撤回讲评',
      message: '撤回后学生暂时看不到这一科的讲评，改好后可以再发布。',
      confirmLabel: '撤回',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    if (await _controller.setPublished(false) && mounted) {
      AppToast.showSuccess(context, '已撤回，学生暂时看不到');
    }
  }

  Future<void> _save() async {
    if (await _controller.save() && mounted) {
      AppToast.showSuccess(context, '已保存');
    }
  }

  Future<void> _removePaper(CritiquePaper paper) async {
    final confirmed = await showAppConfirm(
      context: context,
      title: paper.shared ? '移出这张代表卷' : '删除这份个人讲评',
      message: paper.hasContent
          ? '卷面上的 ${paper.marks.length} 处讲评和总结会一起删除。'
          : '这张卷子还没有讲评内容。',
      confirmLabel: paper.shared ? '移出' : '删除',
      danger: true,
    );
    if (confirmed && mounted) {
      await _controller.removeSelected();
    }
  }

  Future<void> _removeMark(ArtworkMark mark, int number) async {
    if (!mark.isEmpty) {
      final confirmed = await showAppConfirm(
        context: context,
        title: '删除第 $number 处讲评',
        message: mark.hasVoice ? '这一处的文字和语音都会删除。' : '这一处的文字会删除。',
        confirmLabel: '删除',
        danger: true,
      );
      if (!confirmed || !mounted) return;
    }
    _controller.removeMark(mark.id);
  }

  void _addMark(Offset at) {
    final id = _controller.addMark(at);
    if (id != null) {
      _markFocus.requestFocus();
    }
  }

  void _selectMark(String? id) {
    _controller.selectMark(id);
    if (id == null) {
      _markFocus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    ref.listen<ExamCritiqueState>(_provider, (previous, next) {
      _syncFields(previous, next);
      _revealSelection(previous, next);
      final message = next.errorMessage;
      if (message.isEmpty || message == previous?.errorMessage) return;
      AppToast.showError(context, message);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.mounted) _controller.clearError();
      });
    });

    final board = state.board;
    final Widget body;
    if (board == null) {
      body = state.loadFailed
          ? AppErrorState(
              title: '讲评加载失败',
              description: state.errorMessage.isEmpty
                  ? '请检查网络后重试'
                  : state.errorMessage,
              onRetry: _controller.load,
            )
          : const Center(child: AppLoadingIndicator());
    } else {
      body = AppPageBody(
        scrollable: false,
        builder: (context, wide) => AppCanvasLayout(
          wide: wide,
          canvasColor: AppColors.canvasDark,
          panelWidth: wide ? 320 : 280,
          panelController: _panelScroll,
          hint: _hint(state),
          canvas: _buildCanvas(state),
          panel: ExamCritiquePanel(
            state: state,
            summaryController: _summary,
            markController: _markText,
            markFocus: _markFocus,
            onSelect: (key) => _controller.select(key),
            onAdd: (archiveId, shared) =>
                _controller.addPaper(archiveId: archiveId, shared: shared),
            onRemove: _removePaper,
            onSummaryChanged: _controller.setSummary,
            onSummaryVoiceChanged: _controller.setSummaryVoice,
            onSelectMark: (item) => _selectMark(item.mark.id),
            onCloseMark: () => _selectMark(null),
            onMarkTextChanged: (text) {
              final id = ref.read(_provider).selectedMarkId;
              if (id != null) _controller.setMarkText(id, text);
            },
            onMarkVoiceChanged: (path, seconds) {
              final id = ref.read(_provider).selectedMarkId;
              if (id != null) _controller.setMarkVoice(id, path, seconds);
            },
            onRemoveMark: _removeMark,
            onUpload: _controller.uploadVoice,
          ),
        ),
      );
    }

    return PopScope(
      canPop: !state.dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                state: state,
                onBack: _leave,
                onSave: _save,
                onPublish: () => _publish(state),
                onUnpublish: _unpublish,
              ),
              const AppRule(),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  String _hint(ExamCritiqueState state) {
    final candidate = state.selectedCandidate;
    if (candidate == null) return '';
    final draft = state.draft;
    final label = [
      '${candidate.grade} 档',
      '${formatScore(candidate.score)} 分',
      candidate.studentName,
    ].join(' · ');
    if (draft == null) {
      return '$label · 还没加进讲评';
    }
    final kind = draft.shared ? '代表卷' : '个人讲评';
    if (!state.canEdit) {
      return '$label · $kind · 点编号看这一处讲评';
    }
    return '$label · $kind · 点卷面加一处，按住编号拖动 · '
        '${draft.marks.length} / ${ExamCritiqueRules.marksPerPaper} 处';
  }

  Widget _buildCanvas(ExamCritiqueState state) {
    final candidate = state.selectedCandidate;
    if (candidate == null) {
      return const StudyPaperMessage(
        icon: Icons.image_not_supported_outlined,
        text: '这一科还没有可讲评的原卷',
      );
    }
    final draft = state.draft;
    final marks = draft?.numberedMarks(draft.key) ?? const <NumberedArtworkMark>[];
    final editable = state.canEdit && draft != null;
    String idOf(String key) => key.substring(key.lastIndexOf('/') + 1);
    final selectedId = state.selectedMarkId;
    return CritiqueCanvas(
      key: ValueKey<String>('critique-canvas-${state.selectedKey}'),
      imageUrl: candidate.imageUrl,
      marks: marks,
      selectedKey: selectedId == null || draft == null
          ? null
          : '${draft.key}/$selectedId',
      onTapPin: (key) {
        final id = idOf(key);
        _selectMark(id == selectedId ? null : id);
        if (id != selectedId && editable) _markFocus.requestFocus();
      },
      onMovePin: editable
          ? (key, position) {
              final id = idOf(key);
              _controller.moveMark(id, position);
              if (id != ref.read(_provider).selectedMarkId) _selectMark(id);
            }
          : null,
      onTapBlank: editable ? _addMark : null,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.onBack,
    required this.onSave,
    required this.onPublish,
    required this.onUnpublish,
  });

  final ExamCritiqueState state;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;

  @override
  Widget build(BuildContext context) {
    final board = state.board;
    final critique = state.critique;
    final title = board == null
        ? '讲评'
        : '${ExamCritiqueRules.shortExamName(board.examName)} · '
              '${board.subjectName} · 讲评';
    final busy = state.saving;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
      alignment: Alignment.center,
      child: AppTitleBar(
        title: title,
        caption: board == null ? '' : _status(state),
        onBack: onBack,
        backLabel: '关闭讲评',
        actions: [
          if (board != null && board.canEdit) ...[
            if (critique.published)
              AppPlainButton(
                label: '撤回发布',
                onTap: busy ? null : onUnpublish,
              )
            else
              AppPlainButton(
                label: '保存草稿',
                enabled: state.dirty && !busy,
                onTap: onSave,
              ),
            const SizedBox(width: AppSpace.s8),
            if (critique.published)
              AppButton(
                label: '保存修改',
                enabled: state.dirty && !busy,
                loading: busy && state.dirty,
                onTap: onSave,
              )
            else
              AppButton(
                label: '发布讲评',
                enabled: !busy,
                onTap: onPublish,
              ),
          ],
        ],
      ),
    );
  }

  static String _status(ExamCritiqueState state) {
    final critique = state.critique;
    final parts = <String>[
      if (critique.published)
        '已发布${_date(critique.publishTime)}'
      else
        '草稿',
      if (critique.sharedCount > 0) '代表卷 ${critique.sharedCount} 张',
      if (critique.personalCount > 0) '个人讲评 ${critique.personalCount} 份',
      if (!state.canEdit)
        critique.teacherName.isEmpty ? '只读' : '只读 · ${critique.teacherName}老师录入',
      if (state.dirty) '有改动未保存',
    ];
    return parts.join(' · ');
  }

  static String _date(String time) =>
      time.length >= 16 ? ' ${time.substring(5, 16)}' : '';
}

/// 发布前确认：说清谁会看到，选择代表卷上要不要显示学生姓名。
class _PublishDialog extends StatefulWidget {
  const _PublishDialog({
    required this.sharedCount,
    required this.personalCount,
    required this.initialShowNames,
    required this.onConfirm,
  });

  final int sharedCount;
  final int personalCount;
  final bool initialShowNames;
  final Future<void> Function(bool showNames) onConfirm;

  @override
  State<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends State<_PublishDialog> {
  late bool _showNames = widget.initialShowNames;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final reach = [
      if (widget.sharedCount > 0)
        '参加这场考试的学生会在「学情」看到 ${widget.sharedCount} 张代表卷',
      if (widget.personalCount > 0) '${widget.personalCount} 份个人讲评只给对应的学生',
    ].join('；');
    return AppDialog(
      title: '发布讲评',
      message: reach.isEmpty ? '发布后学生会在「学情」看到讲评。' : '$reach。',
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: '发布',
          loading: _busy,
          onTap: () async {
            setState(() => _busy = true);
            await widget.onConfirm(_showNames);
            if (mounted) setState(() => _busy = false);
          },
        ),
      ],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('代表卷显示学生姓名', style: AppText.body14Strong),
                Text('不显示时学生只看到档位和分数', style: AppText.caption12),
              ],
            ),
          ),
          AppSwitch(
            value: _showNames,
            activeColor: AppColors.ink,
            semanticLabel: '代表卷显示学生姓名',
            onChanged: (value) => setState(() => _showNames = value),
          ),
        ],
      ),
    );
  }
}
