import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/artwork_lead_review_controller.dart';
import 'widgets/artwork_annotation.dart';
import 'widgets/artwork_widgets.dart';

final _scoreFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d{0,8}(\.\d{0,2})?'),
);

/// 组长复核工作台：左侧作品大图与老师批注，右侧老师点评和复核表单
/// （组长点评、改定分数、标为范例、标记需关注，或退回老师重评）。
class ArtworkLeadReviewWorkspace extends ConsumerStatefulWidget {
  const ArtworkLeadReviewWorkspace({
    required this.artworkId,
    required this.onBack,
    required this.onOpenArtwork,
    super.key,
  });

  final String artworkId;
  final VoidCallback onBack;

  /// 「通过并下一份」后打开队列里的下一份作品。
  final ValueChanged<String> onOpenArtwork;

  @override
  ConsumerState<ArtworkLeadReviewWorkspace> createState() =>
      _ArtworkLeadReviewWorkspaceState();
}

enum _Busy { none, approve, approveNext, giveBack }

class _ArtworkLeadReviewWorkspaceState
    extends ConsumerState<ArtworkLeadReviewWorkspace> {
  final _comment = TextEditingController();
  final _score = TextEditingController();
  bool _exemplar = false;
  bool _attention = false;
  bool _formReady = false;
  String _savedForm = '';
  int _imageIndex = 0;
  bool _showAnnotations = true;
  _Busy _busy = _Busy.none;

  AutoDisposeStateNotifierProvider<
    ArtworkLeadReviewController,
    ArtworkLeadReviewState
  >
  get _provider => artworkLeadReviewControllerProvider(widget.artworkId);

  @override
  void dispose() {
    _comment.dispose();
    _score.dispose();
    super.dispose();
  }

  String _formSignature() => <String>[
    _comment.text.trim(),
    _score.text.trim(),
    '$_exemplar',
    '$_attention',
  ].join('\u0001');

  bool get _formDirty => _formReady && _formSignature() != _savedForm;

  void _initForm(ArtworkDetail detail) {
    final lead = detail.leadReview;
    final saved = lead != null && lead.approved ? lead : null;
    final score = saved?.score;
    _comment.text = saved?.content ?? '';
    _score.text = score == null ? '' : ArtworkRules.formatScore(score);
    _exemplar = saved?.exemplar ?? false;
    _attention = saved?.attention ?? false;
    _formReady = true;
    _savedForm = _formSignature();
  }

  Future<void> _save({required bool approve, bool next = false}) async {
    final detail = ref.read(_provider).detail;
    if (detail == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    final work = detail.work;
    final content = _comment.text.trim();
    if (ArtworkRules.lengthOf(content) > ArtworkRules.commentLimit) {
      AppToast.showError(context, '复核意见最多 ${ArtworkRules.commentLimit} 个字');
      return;
    }
    double? score;
    if (approve) {
      final parsed = ArtworkRules.parseScore(
        _score.text,
        ArtworkRules.formatScore(work.maxScore),
      );
      if (parsed.error != null) {
        AppToast.showError(context, parsed.error!);
        return;
      }
      score = parsed.score;
    } else {
      if (content.isEmpty) {
        AppToast.showError(context, '请填写退回原因，老师会按原因重新点评');
        return;
      }
      final confirmed = await showAppConfirm(
        context: context,
        title: '退回重评',
        message: '退回后，${work.teacherNames}老师需要重新点评，学生端会回到等待点评。',
        confirmLabel: '退回',
      );
      if (!confirmed || !mounted) {
        return;
      }
    }
    setState(
      () => _busy = !approve
          ? _Busy.giveBack
          : (next ? _Busy.approveNext : _Busy.approve),
    );
    final result = await ref
        .read(_provider.notifier)
        .save(
          approve: approve,
          content: content,
          score: score,
          exemplar: _exemplar,
          attention: _attention,
          next: next,
        );
    if (!mounted) {
      return;
    }
    setState(() => _busy = _Busy.none);
    if (result == null) {
      return;
    }
    _savedForm = _formSignature();
    final nextId = result.nextArtworkId;
    if (!approve) {
      AppToast.showSuccess(context, '已退回，等老师重新点评');
      widget.onBack();
    } else if (!next) {
      AppToast.showSuccess(context, '复核已保存');
    } else if (nextId == null) {
      AppToast.showSuccess(context, '已通过，待复核的作品都已完成');
    } else {
      AppToast.showSuccess(context, '已通过，进入下一份');
      widget.onOpenArtwork(nextId);
    }
  }

  Future<void> _back() async {
    if (_formDirty) {
      final leave = await showAppConfirm(
        context: context,
        title: '放弃未保存的复核？',
        message: '组长点评、分数或标记还没有保存，返回后这些修改将丢失。',
        confirmLabel: '放弃修改',
        cancelLabel: '继续复核',
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
    final controller = ref.read(_provider.notifier);
    ref.listen<ArtworkLeadReviewState>(_provider, (previous, next) {
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
                ? '组内复核'
                : '复核 · ${work.studentName}',
            subtitle: work == null
                ? null
                : <String>[
                    work.title,
                    work.subject,
                    if (work.teacherNames.isNotEmpty)
                      '${work.teacherNames}老师点评',
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
                : _buildBody(detail, state),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ArtworkDetail detail, ArtworkLeadReviewState state) {
    final work = detail.work;
    final canReview = work.leadPending || work.leadApproved;
    return LayoutBuilder(
      builder: (context, constraints) {
        final imagePanel = _buildImagePanel(detail);
        final sections = _buildSections(detail, canReview);
        final actions = canReview ? _buildActions(state) : null;
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
                            children: sections,
                          ),
                        ),
                      ),
                      if (actions != null) ...[
                        const SizedBox(height: AppSpace.s12),
                        actions,
                      ],
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
                  padding: const EdgeInsets.only(bottom: AppSpace.s8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 440, child: imagePanel),
                      const SizedBox(height: AppSpace.s16),
                      ...sections,
                    ],
                  ),
                ),
              ),
              if (actions != null) ...[
                const SizedBox(height: AppSpace.s12),
                actions,
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePanel(ArtworkDetail detail) {
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
    final withAnnotations = detail.reviews
        .where((r) => r.annotations.isNotEmpty)
        .toList();
    final strokes = <AnnotationStroke>[
      for (final review in withAnnotations)
        ...review.annotations.where((s) => s.imageIndex == index),
    ];
    return AppCard(
      color: AppColors.surfaceSubtle,
      bordered: false,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Column(
        children: [
          Row(
            children: [
              if (withAnnotations.isNotEmpty)
                AppSegmented<bool>(
                  size: AppControlSize.sm,
                  segments: const [
                    AppSegment(value: false, label: '原图'),
                    AppSegment(value: true, label: '老师批注'),
                  ],
                  value: _showAnnotations,
                  onChanged: (value) =>
                      setState(() => _showAnnotations = value),
                )
              else
                Flexible(
                  child: Text(
                    '老师没有在作品上批注',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12,
                  ),
                ),
              const Spacer(),
              Text(
                images.length > 1
                    ? '第 ${index + 1}/${images.length} 张'
                    : '点击图片全屏查看',
                style: AppText.caption12,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Expanded(
            child: ArtworkAnnotatedImage(
              url: images[index].url,
              imageIndex: index,
              strokes: _showAnnotations ? strokes : const <AnnotationStroke>[],
              onTap: () => showImageGallery(
                context,
                images: images.map((e) => e.url).toList(),
                initialIndex: index,
                heroTagPrefix: 'artwork_lead_${detail.work.id}',
              ),
            ),
          ),
          if (images.length > 1) ...[
            const SizedBox(height: AppSpace.s12),
            ArtworkThumbnailStrip(
              images: images,
              selectedIndex: index,
              onSelect: (i) => setState(() => _imageIndex = i),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSections(ArtworkDetail detail, bool canReview) {
    final work = detail.work;
    final lead = detail.leadReview;
    final shown = artworkReviewsByTime(
      detail.reviews.where((r) => r.reviewed || r.returned),
    );
    final waiting = detail.reviews
        .where((r) => !r.reviewed && !r.returned)
        .toList();
    return <Widget>[
      _WorkCard(work: work),
      const SizedBox(height: AppSpace.s12),
      AppCard(
        title: '老师点评',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.s8),
              ArtworkReviewCard(review: shown[i]),
              if (shown[i].returned)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s4),
                  child: Text('已退回，等这位老师重新点评', style: AppText.caption12),
                ),
            ],
            for (final review in waiting)
              AppListRow(
                title: '${review.teacherName}老师',
                leading: AppAvatar(name: review.teacherName, size: 28),
                trailing: const ArtworkStatusTag(done: false),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s4,
                  vertical: AppSpace.s8,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpace.s12),
      if (!canReview) ...[
        AppNotice(
          tone: AppTone.warning,
          message: work.leadReturned
              ? '已退回重评，老师重新点评后会回到待复核'
              : '老师还没有完成点评，全部点评完成后可以复核',
        ),
        if (lead != null && !lead.approved) ...[
          const SizedBox(height: AppSpace.s12),
          ArtworkLeadReviewCard(review: lead, showAttention: true),
        ],
      ] else
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionHeader(
                title: '组长点评',
                subtitle: '通过时可以不写；退回重评时写清退回原因',
                titleStyle: AppText.title16,
              ),
              const SizedBox(height: AppSpace.s8),
              AppInputField(
                controller: _comment,
                hint: '补充意见，或写下退回原因',
                multiline: true,
                minLines: 3,
                maxLines: 6,
                maxLength: ArtworkRules.commentLimit,
              ),
              const SizedBox(height: AppSpace.s16),
              AppSectionHeader(
                title: '改定分数',
                subtitle: '留空表示沿用老师的评分',
                titleStyle: AppText.title16,
              ),
              const SizedBox(height: AppSpace.s8),
              Row(
                children: [
                  SizedBox(
                    width: 104,
                    child: AppInputField(
                      controller: _score,
                      hint: '分数',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_scoreFormatter],
                    ),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Text(
                      work.finalScore == null
                          ? '满分 ${ArtworkRules.formatScore(work.maxScore)}，老师没有打分'
                          : '满分 ${ArtworkRules.formatScore(work.maxScore)}，'
                                '当前 ${ArtworkRules.formatScore(work.finalScore)} 分',
                      maxLines: 2,
                      style: AppText.caption12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s16),
              AppCheckbox(
                value: _exemplar,
                label: '标为范例',
                onChanged: (value) => setState(() => _exemplar = value),
              ),
              const SizedBox(height: AppSpace.s8),
              AppCheckbox(
                value: _attention,
                label: '该生需关注（只有教职工可见）',
                onChanged: (value) => setState(() => _attention = value),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _buildActions(ArtworkLeadReviewState state) {
    final busy = state.saving || _busy != _Busy.none;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: AppButton(
            label: '退回重评',
            variant: AppButtonVariant.secondary,
            expand: true,
            loading: _busy == _Busy.giveBack,
            onTap: busy ? null : () => _save(approve: false),
          ),
        ),
        const SizedBox(width: AppSpace.s8),
        Expanded(
          flex: 2,
          child: AppButton(
            label: '通过',
            variant: AppButtonVariant.secondary,
            expand: true,
            loading: _busy == _Busy.approve,
            onTap: busy ? null : () => _save(approve: true),
          ),
        ),
        const SizedBox(width: AppSpace.s8),
        Expanded(
          flex: 4,
          child: AppButton(
            label: '通过并下一份',
            expand: true,
            loading: _busy == _Busy.approveNext,
            onTap: busy ? null : () => _save(approve: true, next: true),
          ),
        ),
      ],
    );
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.work});

  final ArtworkSummary work;

  @override
  Widget build(BuildContext context) {
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
              if (finalScore != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('当前得分', style: AppText.caption12),
                    ArtworkScore(score: finalScore, maxScore: work.maxScore),
                  ],
                )
              else
                ArtworkLeadStatusTag(status: work.leadStatus),
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
        ],
      ),
    );
  }
}
