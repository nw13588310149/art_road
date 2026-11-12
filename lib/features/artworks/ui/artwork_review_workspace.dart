import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/art/art_tokens.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
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
    // 被组长退回的点评也预填进表单，老师在原来的基础上修改。
    final saved = mine != null && (mine.reviewed || mine.returned)
        ? mine
        : null;
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
    final confirmed = await showAppConfirm(
      context: context,
      title: '清空批注',
      message: '清空这张图上你的全部批注？保存批注后生效。',
      confirmLabel: '清空',
      danger: true,
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
      AppToast.showSuccess(context, '已保存，待点评的作品都已完成');
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
        final leave = await showAppConfirm(
          context: context,
          title: '批注未保存',
          message: '批注还没有保存成功，仍要返回列表吗？',
          confirmLabel: '返回',
          cancelLabel: '留下',
        );
        if (!leave || !mounted) {
          return;
        }
      }
    }
    if (_formDirty) {
      final leave = await showAppConfirm(
        context: context,
        title: '放弃未保存的点评？',
        message: '分数、标签或评语还没有保存，返回后这些修改将丢失。',
        confirmLabel: '放弃修改',
        cancelLabel: '继续点评',
        danger: true,
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
          AppPageHeader(
            title: work == null || work.studentName.isEmpty
                ? '作品点评'
                : '点评 · ${work.studentName}',
            subtitle: work == null
                ? null
                : <String>[
                    work.title,
                    work.subject,
                    if (work.createTime.isNotEmpty)
                      '提交于 ${ArtworkRules.shortTime(work.createTime)}',
                  ].where((s) => s.isNotEmpty).join(' · '),
            onBack: _back,
          ),
          Expanded(
            child: detail == null
                ? (state.loading
                      ? const Center(child: AppLoadingIndicator(size: 36))
                      : AppErrorState(
                          title: '作品加载失败',
                          description: '请检查网络后重试',
                          onRetry: controller.load,
                        ))
                : _buildBody(detail, state, tagsState),
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
        const padding = EdgeInsets.fromLTRB(
          AppSpace.page,
          AppSpace.s4,
          AppSpace.page,
          AppSpace.s16,
        );
        if (constraints.maxWidth >= 800) {
          return Padding(
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: imagePanel),
                const SizedBox(width: AppSpace.s16),
                SizedBox(
                  width: 380,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: AppSpace.s8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: form,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.s12),
                      actions,
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: padding,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  // 批注时禁止滚动，竖向笔画才不会被当成滚动手势。
                  physics: _annotating
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  padding: const EdgeInsets.only(bottom: AppSpace.s8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 440, child: imagePanel),
                      const SizedBox(height: AppSpace.s16),
                      ...form,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              actions,
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePanel(ArtworkDetail detail, ArtworkReviewState state) {
    final images = detail.images;
    if (images.isEmpty) {
      return const AppCard(
        color: AppColors.surfaceSubtle,
        bordered: false,
        child: AppEmptyState(
          icon: Icons.image_outlined,
          title: '这份作品没有图片',
          description: '请联系学生重新上传作品照片',
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
    return AppCard(
      color: AppColors.surfaceSubtle,
      bordered: false,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Column(
        children: [
          if (_annotating)
            _buildAnnotationToolbar(state, index, strokes)
          else
            _buildViewerToolbar(state, images, index, strokes),
          const SizedBox(height: AppSpace.s12),
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.br8,
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
            const SizedBox(height: AppSpace.s12),
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
            style: AppText.caption12,
          ),
        ),
        AppIconButton(
          icon: Icons.center_focus_strong_outlined,
          semanticLabel: '还原缩放',
          size: AppButtonSize.sm,
          filled: false,
          color: AppColors.textSecondary,
          onTap: () => _transform.value = Matrix4.identity(),
        ),
        AppIconButton(
          icon: Icons.fullscreen_rounded,
          semanticLabel: '全屏查看原图',
          size: AppButtonSize.sm,
          filled: false,
          color: AppColors.textSecondary,
          onTap: () => showImageGallery(
            context,
            images: images.map((e) => e.url).toList(),
            initialIndex: index,
            heroTagPrefix: 'review_${widget.artworkId}',
          ),
        ),
        const SizedBox(width: AppSpace.s8),
        AppButton(
          label: '批注改画',
          icon: Icons.brush_outlined,
          variant: AppButtonVariant.quiet,
          size: AppButtonSize.sm,
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
    Widget divider() => Container(width: 1, height: 20, color: AppColors.line);
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: AppSpace.s8,
        runSpacing: AppSpace.s8,
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
          AppIconButton(
            icon: Icons.undo_rounded,
            semanticLabel: '撤销',
            size: AppButtonSize.sm,
            filled: false,
            color: AppColors.textSecondary,
            onTap: strokes.isEmpty ? null : () => controller.undo(index),
          ),
          AppIconButton(
            icon: Icons.layers_clear_outlined,
            semanticLabel: '清空本张',
            size: AppButtonSize.sm,
            filled: false,
            color: AppColors.textSecondary,
            onTap: strokes.isEmpty ? null : () => _confirmClear(index),
          ),
          AppButton(
            label: '保存批注',
            icon: Icons.save_outlined,
            size: AppButtonSize.sm,
            loading: state.savingStrokes,
            onTap: state.hasUnsavedStrokes ? _saveStrokes : null,
          ),
          AppButton(
            label: '完成',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
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
    final lead = detail.leadReview;
    final returned = detail.work.returnReason.isNotEmpty;
    return <Widget>[
      _StudentCard(detail: detail),
      const SizedBox(height: AppSpace.s12),
      if (returned) ...[
        const AppNotice(
          tone: AppTone.danger,
          message: '组长退回了这份点评，请按退回原因修改后重新保存',
        ),
        const SizedBox(height: AppSpace.s12),
      ],
      if (lead != null && (returned || lead.approved)) ...[
        ArtworkLeadReviewCard(
          review: lead,
          showAttention: true,
          maxScore: detail.work.maxScore,
        ),
        const SizedBox(height: AppSpace.s12),
      ],
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(
              title: '评分',
              subtitle: '可以只写评语、不打分',
              titleStyle: AppText.title16,
            ),
            const SizedBox(height: AppSpace.s8),
            _buildScoreInputs(detail),
            const SizedBox(height: AppSpace.s16),
            AppSectionHeader(
              title: '点评标签',
              subtitle:
                  '已选 ${_tagIds.length} 个，最多 ${ArtworkRules.tagsPerReview} 个',
              titleStyle: AppText.title16,
              trailing: AppButton(
                label: '管理标签',
                variant: AppButtonVariant.text,
                size: AppButtonSize.sm,
                onTap: () => showArtworkTagManager(context),
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            _buildTagPicker(detail, tagsState),
            const SizedBox(height: AppSpace.s16),
            AppSectionHeader(title: '评语', titleStyle: AppText.title16),
            const SizedBox(height: AppSpace.s8),
            AppInputField(
              controller: _comment,
              hint: '写下这张画的优点和需要改进的地方',
              multiline: true,
              minLines: 4,
              maxLines: 8,
              maxLength: ArtworkRules.commentLimit,
            ),
          ],
        ),
      ),
      if (detail.otherReviews.isNotEmpty) ...[
        const SizedBox(height: AppSpace.s12),
        AppCard(
          title: '其他老师的点评',
          child: _OtherReviews(detail: detail),
        ),
      ],
    ];
  }

  Widget _buildScoreInputs(ArtworkDetail detail) {
    final required = detail.requiredFullScore;
    final locked = required != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 104,
          child: AppInputField(
            controller: _score,
            hint: '分数',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_scoreFormatter],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
          child: Text(
            '/',
            style: AppText.number(size: 16, color: AppColors.textTertiary),
          ),
        ),
        SizedBox(
          width: 80,
          child: AppInputField(
            controller: _maxScore,
            hint: '满分',
            readOnly: locked,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_scoreFormatter],
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Text(
            locked
                ? '已有老师按 ${ArtworkRules.formatScore(required)} 分制评分，满分保持一致'
                : '满分默认 100，可修改',
            maxLines: 3,
            style: AppText.caption12,
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
      return const AppSkeletonText(lines: 2, lineHeight: 30);
    }
    if (tags.isEmpty && retired.isEmpty) {
      return Text(
        '还没有点评标签，点「管理标签」把常见问题和亮点做成标签，点评时一键选用',
        style: AppText.caption12,
      );
    }
    final problems = [
      for (final tag in tags)
        if (!ArtworkRules.isHighlightTag(tag.color)) tag,
    ];
    final highlights = [
      for (final tag in tags)
        if (ArtworkRules.isHighlightTag(tag.color)) tag,
    ];
    Widget chip(ArtworkTag tag, {String? label}) {
      final Widget item = AppChip(
        label: label ?? tag.name,
        selected: _tagIds.contains(tag.id),
        onTap: () => _toggleTag(tag.id),
      );
      return tag.explanation.isEmpty
          ? item
          : Tooltip(
              message: tag.explanation,
              triggerMode: TooltipTriggerMode.longPress,
              child: item,
            );
    }

    Widget group(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(title, style: AppText.caption12),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: chips,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (problems.isNotEmpty)
          group('问题', [for (final tag in problems) chip(tag)]),
        if (highlights.isNotEmpty)
          group('亮点', [for (final tag in highlights) chip(tag)]),
        if (retired.isNotEmpty)
          group('已删除', [
            for (final tag in retired) chip(tag, label: '${tag.name}（已删除）'),
          ]),
      ],
    );
  }

  Widget _buildActions(ArtworkReviewState state) {
    final busy = state.saving;
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: '保存',
            variant: AppButtonVariant.secondary,
            expand: true,
            loading: busy && !_savingNext,
            onTap: busy ? null : () => _save(next: false),
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: AppButton(
            label: '保存并下一份',
            icon: Icons.skip_next_rounded,
            expand: true,
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
    return AppCard(
      title: work.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: work.studentName, url: work.avatarUrl, size: 40),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      work.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title16,
                    ),
                    Text(
                      <String>[
                        work.organizationName,
                        if (work.studentNo.isNotEmpty) '学号 ${work.studentNo}',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              if (work.reviewed && finalScore != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('最终得分', style: AppText.caption12),
                    ArtworkScore(score: finalScore, maxScore: work.maxScore),
                  ],
                )
              else
                ArtworkStatusTag(done: work.myReviewed),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ArtworkSubjectTag(subject: work.subject),
              Text(
                '绘于 ${ArtworkRules.dateText(work.drawingDate)}',
                style: AppText.caption12,
              ),
              Text(
                '提交于 ${ArtworkRules.shortTime(work.createTime)}',
                style: AppText.caption12,
              ),
            ],
          ),
          if (work.description.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Text(work.description, style: AppText.body13),
          ],
          if (detail.teachers.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final teacher in detail.teachers)
                  AppTag(
                    label:
                        '${teacher.teacherName}${teacher.teacherId == myId ? '（我）' : ''} · ${teacher.reviewed ? '已点评' : '待点评'}',
                    tone: teacher.reviewed ? AppTone.success : AppTone.warning,
                    icon: teacher.reviewed
                        ? Icons.check_rounded
                        : Icons.schedule_rounded,
                  ),
              ],
            ),
          ],
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
    final others = artworkReviewsByTime(detail.otherReviews);
    if (!detail.work.myReviewed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppNotice(
            tone: AppTone.neutral,
            icon: Icons.visibility_off_outlined,
            message: '保存你的点评后，即可查看其他老师的分数与评语',
          ),
          for (final review in others) _PendingTeacherRow(review: review),
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < others.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpace.s8),
          if (others[i].visible)
            ArtworkReviewCard(review: others[i])
          else
            _PendingTeacherRow(review: others[i]),
        ],
      ],
    );
  }
}

class _PendingTeacherRow extends StatelessWidget {
  const _PendingTeacherRow({required this.review});

  final ArtworkReview review;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      title: '${review.teacherName}老师',
      leading: AppAvatar(name: review.teacherName, size: 28),
      trailing: ArtworkStatusTag(done: review.reviewed),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s4,
        vertical: AppSpace.s8,
      ),
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
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '批注颜色',
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br8,
          border: Border.all(
            color: selected ? tone : AppColors.line,
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
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '笔画粗细',
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.brandWash : AppColors.surface,
          borderRadius: AppRadius.br8,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.line,
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
