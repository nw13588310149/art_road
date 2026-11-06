import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/art/art_tokens.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/art_widgets.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/artwork_review_controller.dart';
import '../state/artwork_tags_controller.dart';
import 'artwork_tag_manager_dialog.dart';
import 'widgets/artwork_annotation.dart';
import 'widgets/artwork_widgets.dart';

final _scoreFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d{0,8}(\.\d{0,2})?'),
);

/// 点评工作台：左侧作品大图（缩放查看、批注改画），右侧评分、标签、评语与其他老师的点评。
class ArtworkReviewWorkspace extends ConsumerStatefulWidget {
  const ArtworkReviewWorkspace({
    required this.artworkId,
    required this.onBack,
    required this.onOpenArtwork,
    super.key,
  });

  final String artworkId;
  final VoidCallback onBack;

  /// 「保存并下一份」跳转到队列里的下一份作品。
  final ValueChanged<String> onOpenArtwork;

  @override
  ConsumerState<ArtworkReviewWorkspace> createState() =>
      _ArtworkReviewWorkspaceState();
}

class _ArtworkReviewWorkspaceState
    extends ConsumerState<ArtworkReviewWorkspace> {
  final _score = TextEditingController();
  final _maxScore = TextEditingController(text: '100');
  final _comment = TextEditingController();
  final _transform = TransformationController();
  final _tagIds = <String>[];
  bool _formReady = false;
  String _savedForm = '';
  int _imageIndex = 0;
  bool _annotating = false;
  String _penColor = kAnnotationPenColors.first;
  double _penWidth = kAnnotationPenWidths[1];
  bool _savingNext = false;

  AutoDisposeStateNotifierProvider<ArtworkReviewController, ArtworkReviewState>
  get _provider => artworkReviewControllerProvider(widget.artworkId);

  @override
  void dispose() {
    _score.dispose();
    _maxScore.dispose();
    _comment.dispose();
    _transform.dispose();
    super.dispose();
  }

  String _formSignature() => <String>[
    _score.text.trim(),
    _maxScore.text.trim(),
    _comment.text.trim(),
    ..._tagIds,
  ].join('\u0001');

  bool get _formDirty => _formReady && _formSignature() != _savedForm;

  void _initForm(ArtworkDetail detail) {
    final mine = detail.myReview;
    final saved = mine != null && mine.reviewed ? mine : null;
    final score = saved?.score;
    _score.text = score == null ? '' : ArtworkRules.formatScore(score);
    _maxScore.text = ArtworkRules.formatScore(
      detail.requiredFullScore ??
          saved?.maxScore ??
          ArtworkRules.defaultFullScore,
    );
    _comment.text = saved?.content ?? '';
    _tagIds
      ..clear()
      ..addAll(saved?.tags.map((t) => t.id) ?? const <String>[]);
    _formReady = true;
    _savedForm = _formSignature();
  }

  void _toggleTag(String id) {
    if (_tagIds.contains(id)) {
      setState(() => _tagIds.remove(id));
      return;
    }
    if (_tagIds.length >= ArtworkRules.tagsPerReview) {
      AppToast.showError(context, '每份作品最多选择 ${ArtworkRules.tagsPerReview} 个标签');
      return;
    }
    setState(() => _tagIds.add(id));
  }

  void _selectImage(int index) {
    if (index == _imageIndex) {
      return;
    }
    _transform.value = Matrix4.identity();
    setState(() => _imageIndex = index);
  }

  Future<void> _saveStrokes() async {
    final saved = await ref.read(_provider.notifier).saveAnnotations();
    if (saved && mounted) {
      AppToast.showSuccess(context, '批注已保存');
    }
  }

  Future<void> _finishAnnotating() async {
    if (ref.read(_provider).hasUnsavedStrokes) {
      final saved = await ref.read(_provider.notifier).saveAnnotations();
      if (!mounted || !saved) {
        return;
      }
      AppToast.showSuccess(context, '批注已保存');
    }
    setState(() => _annotating = false);
  }

  Future<void> _confirmClear(int imageIndex) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: '清空批注',
      content: '清空这张图上你的全部批注？保存批注后生效。',
      confirmLabel: '清空',
    );
    if (confirmed && mounted) {
      ref.read(_provider.notifier).clear(imageIndex);
    }
  }

  Future<void> _save({required bool next}) async {
    final detail = ref.read(_provider).detail;
    if (detail == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    final parsed = ArtworkRules.parseScore(
      _score.text,
      _maxScore.text,
      requiredFullScore: detail.requiredFullScore,
    );
    final error =
        parsed.error ??
        ArtworkRules.validateReview(
          score: parsed.score,
          tagCount: _tagIds.length,
          comment: _comment.text,
        );
    if (error != null) {
      AppToast.showError(context, error);
      return;
    }
    setState(() => _savingNext = next);
    final result = await ref
        .read(_provider.notifier)
        .save(
          score: parsed.score,
          maxScore: parsed.maxScore,
          content: _comment.text.trim(),
          tagIds: List<String>.of(_tagIds),
          next: next,
        );
    if (!mounted || result == null) {
      return;
    }
    _savedForm = _formSignature();
    final nextId = result.nextArtworkId;
    if (!next) {
      AppToast.showSuccess(context, '点评已保存');
    } else if (nextId == null) {
      AppToast.showSuccess(context, '已保存，待点评的作品都完成了');
    } else {
      AppToast.showSuccess(context, '已保存，进入下一份');
      widget.onOpenArtwork(nextId);
    }
  }

  Future<void> _back() async {
    if (ref.read(_provider).hasUnsavedStrokes) {
      final saved = await ref.read(_provider.notifier).saveAnnotations();
      if (!mounted) {
        return;
      }
      if (!saved) {
        final leave = await showConfirmDialog(
          context: context,
          title: '批注未保存',
          content: '批注还没有保存成功，仍要返回列表吗？',
          confirmLabel: '返回',
          cancelLabel: '留下',
        );
        if (!leave || !mounted) {
          return;
        }
      }
    }
    if (_formDirty) {
      final leave = await showConfirmDialog(
        context: context,
        title: '放弃未保存的点评？',
        content: '分数、标签或评语还没有保存，返回后这些修改将丢失。',
        confirmLabel: '放弃修改',
        cancelLabel: '继续点评',
      );
      if (!leave || !mounted) {
        return;
      }
    }
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final tagsState = ref.watch(artworkTagsControllerProvider);
    final controller = ref.read(_provider.notifier);
    final tagsController = ref.read(artworkTagsControllerProvider.notifier);
    ref.listen<ArtworkReviewState>(_provider, (previous, next) {
      final detail = next.detail;
      if (!_formReady && detail != null) {
        setState(() => _initForm(detail));
      }
      final message = next.errorMessage;
      if (message.isNotEmpty && message != previous?.errorMessage) {
        AppToast.showError(context, message);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.mounted) {
            controller.clearError();
          }
        });
      }
    });
    ref.listen<ArtworkTagsState>(artworkTagsControllerProvider, (
      previous,
      next,
    ) {
      final message = next.errorMessage;
      if (message.isNotEmpty && message != previous?.errorMessage) {
        AppToast.showError(context, message);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (tagsController.mounted) {
            tagsController.clearError();
          }
        });
      }
    });

    final detail = state.detail;
    final work = detail?.work;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _back();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArtPageHeader(
            title: work?.title ?? '作品点评',
            subtitle: work == null
                ? null
                : <String>[
                    work.studentName,
                    work.organizationName,
                    work.subject,
                  ].where((s) => s.isNotEmpty).join(' · '),
            onBack: _back,
            actions: [
              if (work != null)
                ArtworkStatusBadge(
                  done: work.myReviewed,
                  label: work.myReviewed ? '我已点评' : '待我点评',
                ),
            ],
          ),
          Expanded(
            child: PageInitLoadingShell(
              loading: state.loading && detail == null,
              child: detail == null
                  ? (state.loading
                        ? const SizedBox.shrink()
                        : ArtEmptyState(
                            icon: Icons.image_not_supported_outlined,
                            message: '作品加载失败',
                            actionLabel: '重新加载',
                            onAction: controller.load,
                          ))
                  : _buildBody(detail, state, tagsState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    ArtworkDetail detail,
    ArtworkReviewState state,
    ArtworkTagsState tagsState,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imagePanel = _buildImagePanel(detail, state);
        final form = _buildFormSections(detail, tagsState);
        final actions = _buildActions(state);
        if (constraints.maxWidth >= 820) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: imagePanel),
                const SizedBox(width: 16),
                SizedBox(
                  width: 372,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: form,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      actions,
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  // 批注时禁止滚动，竖向笔画才不会被当成滚动手势。
                  physics: _annotating
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 440, child: imagePanel),
                      const SizedBox(height: 16),
                      ...form,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              actions,
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePanel(ArtworkDetail detail, ArtworkReviewState state) {
    final images = detail.images;
    final decoration = BoxDecoration(
      color: const Color(0xFFF2F3F7),
      borderRadius: BorderRadius.circular(16),
    );
    if (images.isEmpty) {
      return DecoratedBox(
        decoration: decoration,
        child: const ArtEmptyState(
          icon: Icons.image_outlined,
          message: '这份作品没有图片',
        ),
      );
    }
    final index = _imageIndex.clamp(0, images.length - 1);
    final strokes = state.strokesOf(index);
    final controller = ref.read(_provider.notifier);
    final image = ArtworkAnnotatedImage(
      url: images[index].url,
      imageIndex: index,
      strokes: strokes,
      pen: _annotating
          ? AnnotationPen(color: _penColor, width: _penWidth)
          : null,
      onStrokeEnd: controller.addStroke,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: decoration,
      child: Column(
        children: [
          if (_annotating)
            _buildAnnotationToolbar(state, index, strokes)
          else
            _buildViewerToolbar(state, images, index, strokes),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _annotating
                  // 保留当前缩放位置绘制；不放在 InteractiveViewer 里，避免手势相互抢占。
                  ? Transform(transform: _transform.value, child: image)
                  : InteractiveViewer(
                      transformationController: _transform,
                      minScale: 1,
                      maxScale: 5,
                      child: image,
                    ),
            ),
          ),
          if (images.length > 1) ...[
            const SizedBox(height: 10),
            ArtworkThumbnailStrip(
              images: images,
              selectedIndex: index,
              onSelect: _selectImage,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildViewerToolbar(
    ArtworkReviewState state,
    List<ArtworkImage> images,
    int index,
    List<AnnotationStroke> strokes,
  ) {
    final parts = <String>[
      images.length > 1 ? '第 ${index + 1}/${images.length} 张' : '作品原图',
      if (strokes.isNotEmpty) '我的批注 ${strokes.length} 笔',
      if (state.dirtyImages.contains(index)) '未保存',
    ];
    return Row(
      children: [
        Expanded(
          child: Text(
            parts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ArtText.caption(),
          ),
        ),
        ArtworkIconAction(
          icon: Icons.center_focus_strong_outlined,
          tooltip: '还原缩放',
          onTap: () => _transform.value = Matrix4.identity(),
        ),
        const SizedBox(width: 6),
        ArtworkIconAction(
          icon: Icons.fullscreen_rounded,
          tooltip: '全屏查看',
          onTap: () => showImageGallery(
            context,
            images: images.map((e) => e.url).toList(),
            initialIndex: index,
            heroTagPrefix: 'review_${widget.artworkId}',
          ),
        ),
        const SizedBox(width: 8),
        ArtButton(
          label: '批注改画',
          primary: false,
          icon: Icons.brush_outlined,
          height: 32,
          onTap: () => setState(() => _annotating = true),
        ),
      ],
    );
  }

  Widget _buildAnnotationToolbar(
    ArtworkReviewState state,
    int index,
    List<AnnotationStroke> strokes,
  ) {
    final controller = ref.read(_provider.notifier);
    Widget divider() => Container(
      width: 1,
      height: 20,
      color: ArtColors.ink4.withValues(alpha: 0.4),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final color in kAnnotationPenColors)
            _PenColorButton(
              color: color,
              selected: color == _penColor,
              onTap: () => setState(() => _penColor = color),
            ),
          divider(),
          for (final width in kAnnotationPenWidths)
            _PenWidthButton(
              width: width,
              color: _penColor,
              selected: width == _penWidth,
              onTap: () => setState(() => _penWidth = width),
            ),
          divider(),
          ArtworkIconAction(
            icon: Icons.undo_rounded,
            tooltip: '撤销',
            onTap: strokes.isEmpty ? null : () => controller.undo(index),
          ),
          ArtworkIconAction(
            icon: Icons.layers_clear_outlined,
            tooltip: '清空本张',
            onTap: strokes.isEmpty ? null : () => _confirmClear(index),
          ),
          ArtButton(
            label: '保存批注',
            icon: Icons.save_outlined,
            height: 32,
            loading: state.savingStrokes,
            onTap: state.hasUnsavedStrokes ? _saveStrokes : null,
          ),
          ArtButton(
            label: '完成',
            primary: false,
            height: 32,
            onTap: state.savingStrokes ? null : _finishAnnotating,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFormSections(
    ArtworkDetail detail,
    ArtworkTagsState tagsState,
  ) {
    return <Widget>[
      _StudentCard(detail: detail),
      const SizedBox(height: 16),
      ArtworkSectionTitle(
        title: '评分',
        trailing: Text('可以只写评语、不打分', style: ArtText.caption(size: 11)),
      ),
      _buildScoreInputs(detail),
      const SizedBox(height: 18),
      ArtworkSectionTitle(
        title: '问题标签',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_tagIds.length}/${ArtworkRules.tagsPerReview}',
              style: ArtText.caption(),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showArtworkTagManager(context),
              child: Text(
                '管理标签',
                style: ArtText.body(
                  size: 12,
                  color: ArtColors.brandDeep,
                  weight: AppFont.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      _buildTagPicker(detail, tagsState),
      const SizedBox(height: 18),
      const ArtworkSectionTitle(title: '评语'),
      AppTextField(
        controller: _comment,
        minLines: 4,
        maxLines: 8,
        maxLength: ArtworkRules.commentLimit,
        keyboardType: TextInputType.multiline,
        style: ArtText.body(height: 1.6),
        decoration: artworkInputDecoration(
          hint: '写下这张画的优点和需要改进的地方',
          showCounter: true,
        ),
      ),
      if (detail.otherReviews.isNotEmpty) ...[
        const SizedBox(height: 14),
        const ArtworkSectionTitle(title: '其他老师的点评'),
        _OtherReviews(detail: detail),
      ],
    ];
  }

  Widget _buildScoreInputs(ArtworkDetail detail) {
    final required = detail.requiredFullScore;
    final locked = required != null;
    return Row(
      children: [
        SizedBox(
          width: 116,
          child: AppTextField(
            controller: _score,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_scoreFormatter],
            textAlign: TextAlign.center,
            style: ArtText.number(size: 20, color: ArtColors.brandDeep),
            decoration: artworkInputDecoration(hint: '分数'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '/',
            style: ArtText.number(size: 20, color: ArtColors.ink4),
          ),
        ),
        SizedBox(
          width: 88,
          child: AppTextField(
            controller: _maxScore,
            enabled: !locked,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_scoreFormatter],
            textAlign: TextAlign.center,
            style: ArtText.number(
              size: 16,
              color: locked ? ArtColors.ink3 : ArtColors.ink,
            ),
            decoration: artworkInputDecoration(hint: '满分'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: locked
              ? Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: ArtColors.ink3,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '已有老师按 ${ArtworkRules.formatScore(required)} 分制评分，满分保持一致',
                        maxLines: 3,
                        style: ArtText.caption(size: 11),
                      ),
                    ),
                  ],
                )
              : Text(
                  '满分默认 100，可修改',
                  maxLines: 2,
                  style: ArtText.caption(size: 11),
                ),
        ),
      ],
    );
  }

  Widget _buildTagPicker(ArtworkDetail detail, ArtworkTagsState tagsState) {
    final tags = tagsState.tags;
    final known = tags.map((t) => t.id).toSet();
    // 已删除的标签只保留在原点评里：仍可取消，不能再次添加。
    final retired = <ArtworkTag>[
      for (final tag in detail.myReview?.tags ?? const <ArtworkTag>[])
        if (!known.contains(tag.id) && _tagIds.contains(tag.id)) tag,
    ];
    if (tagsState.loading && tags.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(child: AppLoadingIndicator(size: 28)),
      );
    }
    if (tags.isEmpty && retired.isEmpty) {
      return Text(
        '还没有点评标签，点击「管理标签」把常见问题做成标签，点评时一键选用。',
        style: ArtText.caption(),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          ArtworkTagChip(
            name: tag.name,
            color: tag.color,
            selected: _tagIds.contains(tag.id),
            tooltip: tag.explanation,
            onTap: () => _toggleTag(tag.id),
          ),
        for (final tag in retired)
          ArtworkTagChip(
            name: '${tag.name}（已删除）',
            color: tag.color,
            selected: true,
            onTap: () => _toggleTag(tag.id),
          ),
      ],
    );
  }

  Widget _buildActions(ArtworkReviewState state) {
    final busy = state.saving;
    return Row(
      children: [
        Expanded(
          child: ArtButton(
            label: '保存',
            primary: false,
            height: 42,
            loading: busy && !_savingNext,
            onTap: busy ? null : () => _save(next: false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ArtButton(
            label: '保存并下一份',
            icon: Icons.skip_next_rounded,
            height: 42,
            loading: busy && _savingNext,
            onTap: busy ? null : () => _save(next: true),
          ),
        ),
      ],
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.detail});

  final ArtworkDetail detail;

  @override
  Widget build(BuildContext context) {
    final work = detail.work;
    final myId = detail.myReview?.teacherId;
    final finalScore = work.finalScore;
    return ArtCard(
      color: ArtColors.subtle,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ArtAvatar(name: work.studentName, url: work.avatarUrl, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      work.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ArtText.body(size: 15, weight: AppFont.w600),
                    ),
                    Text(
                      <String>[
                        work.organizationName,
                        if (work.archiveId.isNotEmpty) '档案号 ${work.archiveId}',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ArtText.caption(size: 11),
                    ),
                  ],
                ),
              ),
              if (work.reviewed && finalScore != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('最终得分', style: ArtText.caption(size: 11)),
                    ArtworkScore(score: finalScore, maxScore: work.maxScore),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ArtworkSubjectChip(subject: work.subject),
              Text(
                '绘于 ${ArtworkRules.dotDate(work.drawingDate)}',
                style: ArtText.caption(size: 11),
              ),
              Text(
                '提交于 ${ArtworkRules.shortTime(work.createTime)}',
                style: ArtText.caption(size: 11),
              ),
            ],
          ),
          if (work.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              work.description,
              style: ArtText.body(size: 13, color: ArtColors.ink2, height: 1.6),
            ),
          ],
          if (detail.teachers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final teacher in detail.teachers)
                  _TeacherPill(
                    teacher: teacher,
                    mine: teacher.teacherId == myId,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TeacherPill extends StatelessWidget {
  const _TeacherPill({required this.teacher, required this.mine});

  final ArtworkTeacher teacher;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final color = teacher.reviewed ? ArtColors.success : ArtColors.warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ArtColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            teacher.reviewed
                ? Icons.check_circle_rounded
                : Icons.schedule_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${teacher.teacherName}${mine ? '（我）' : ''} · ${teacher.reviewed ? '已点评' : '未点评'}',
            style: ArtText.caption(size: 11, color: ArtColors.ink2),
          ),
        ],
      ),
    );
  }
}

/// 其他老师的点评：保存自己的点评前只显示是否已点评。
class _OtherReviews extends StatelessWidget {
  const _OtherReviews({required this.detail});

  final ArtworkDetail detail;

  @override
  Widget build(BuildContext context) {
    final others = detail.otherReviews;
    if (!detail.work.myReviewed) {
      return ArtCard(
        color: ArtColors.subtle,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.visibility_off_outlined,
                  size: 16,
                  color: ArtColors.ink3,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '保存你的点评后，即可查看其他老师的分数与评语',
                    style: ArtText.body(size: 13, weight: AppFont.w500),
                  ),
                ),
              ],
            ),
            for (final review in others) ...[
              const SizedBox(height: 10),
              _PendingTeacherRow(review: review),
            ],
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final review in others)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: review.visible
                ? ArtworkReviewCard(review: review)
                : ArtCard(
                    color: ArtColors.subtle,
                    padding: const EdgeInsets.all(12),
                    child: _PendingTeacherRow(review: review),
                  ),
          ),
      ],
    );
  }
}

class _PendingTeacherRow extends StatelessWidget {
  const _PendingTeacherRow({required this.review});

  final ArtworkReview review;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ArtAvatar(name: review.teacherName, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Text('${review.teacherName}老师', style: ArtText.body(size: 13)),
        ),
        ArtworkStatusBadge(
          done: review.reviewed,
          label: review.reviewed ? '已点评' : '尚未点评',
        ),
      ],
    );
  }
}

class _PenColorButton extends StatelessWidget {
  const _PenColorButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = ArtColors.fromHex(color);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? tone : ArtColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _PenWidthButton extends StatelessWidget {
  const _PenWidthButton({
    required this.width,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dot = 4 + width * 1.6;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? ArtColors.brandWash : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? ArtColors.brandLight : ArtColors.line,
          ),
        ),
        child: Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(
            color: ArtColors.fromHex(color),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
