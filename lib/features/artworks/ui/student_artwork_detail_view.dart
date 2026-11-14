import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/artwork_detail_controller.dart';
import '../state/artwork_review_controller.dart';
import '../../smart_campus/ui/widgets/homework_voice_comment.dart';
import 'artwork_compare_page.dart';
import 'artwork_upload_dialog.dart';
import 'widgets/artwork_annotation.dart';
import 'widgets/artwork_marks.dart';
import 'widgets/artwork_review_timeline.dart';
import 'widgets/artwork_widgets.dart';

/// 学生作品详情：大图（可切换老师批注、对比范画）、最终得分、作品信息与老师点评。
class StudentArtworkDetailView extends ConsumerStatefulWidget {
  const StudentArtworkDetailView({
    required this.artworkId,
    required this.onBack,
    this.onOpenArtwork,
    this.readOnly = false,
    super.key,
  });

  final String artworkId;
  final VoidCallback onBack;
  final ValueChanged<String>? onOpenArtwork;
  final bool readOnly;

  @override
  ConsumerState<StudentArtworkDetailView> createState() =>
      _StudentArtworkDetailViewState();
}

class _StudentArtworkDetailViewState
    extends ConsumerState<StudentArtworkDetailView> {
  int _imageIndex = 0;
  bool _showAnnotations = true;

  @override
  Widget build(BuildContext context) {
    final provider = studentArtworkDetailProvider(widget.artworkId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen<ArtworkDetailState>(provider, (previous, next) {
      final message = next.errorMessage;
      if (message.isEmpty || message == previous?.errorMessage) {
        return;
      }
      AppToast.showError(context, message);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) {
          controller.clearError();
        }
      });
    });

    final detail = state.detail;
    final work = detail?.work;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: work?.title ?? '作品详情',
          subtitle: work == null
              ? null
              : '${work.subject} · 绘于 ${ArtworkRules.dateText(work.drawingDate)}',
          onBack: widget.onBack,
          actions: [
            if (work != null) ArtworkStatusMark(reviewed: work.reviewed),
          ],
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
              : _buildBody(detail),
        ),
      ],
    );
  }

  Widget _buildBody(ArtworkDetail detail) {
    final previousId = ArtworkReviewController.previousVersionId(detail);
    final previous = previousId == null
        ? null
        : ref.watch(studentArtworkDetailProvider(previousId)).detail;
    return LayoutBuilder(
      builder: (context, constraints) {
        final imagePanel = _buildImagePanel(detail);
        final info = _InfoColumn(
          detail: detail,
          canRevise:
              !widget.readOnly &&
              detail.isOwner &&
              detail.work.reviewed &&
              detail.versions.every(
                (version) => version.version <= detail.work.version,
              ),
          onOpenArtwork: widget.onOpenArtwork,
          onCompare:
              previous == null ||
                  previous.images.isEmpty ||
                  detail.images.isEmpty
              ? null
              : () => openArtworkCompare(
                  context,
                  images: detail.images.map((image) => image.url).toList(),
                  previousImages: previous.images
                      .map((image) => image.url)
                      .toList(),
                  subject: detail.work.subject,
                  initialIndex: _imageIndex,
                ),
        );
        if (constraints.maxWidth >= 800) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s4,
              AppSpace.page,
              AppSpace.s20,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: imagePanel),
                const SizedBox(width: AppSpace.s16),
                SizedBox(width: 340, child: SingleChildScrollView(child: info)),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s4,
            AppSpace.page,
            AppSpace.s24,
          ),
          children: [
            SizedBox(height: 420, child: imagePanel),
            const SizedBox(height: AppSpace.s16),
            info,
          ],
        );
      },
    );
  }

  Widget _buildImagePanel(ArtworkDetail detail) {
    final images = detail.images;
    final index = images.isEmpty ? 0 : _imageIndex.clamp(0, images.length - 1);
    final withAnnotations = detail.reviews
        .where((r) => r.annotations.isNotEmpty)
        .toList();
    final strokes = <AnnotationStroke>[
      for (final review in withAnnotations)
        ...review.annotations.where((s) => s.imageIndex == index),
    ];
    final annotators = <String>[
      for (final review in withAnnotations)
        if (review.annotations.any((s) => s.imageIndex == index))
          review.teacherName,
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
                    detail.work.reviewed ? '老师没有在作品上批注' : '老师的批注会显示在作品上',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12,
                  ),
                ),
              const Spacer(),
              AppButton(
                label: '对比范画',
                icon: Icons.compare_rounded,
                variant: AppButtonVariant.quiet,
                size: AppButtonSize.sm,
                onTap: images.isEmpty
                    ? null
                    : () => openArtworkCompare(
                        context,
                        images: images.map((e) => e.url).toList(),
                        initialIndex: index,
                        subject: detail.work.subject,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Expanded(
            child: images.isEmpty
                ? const AppEmptyState(
                    icon: Icons.image_outlined,
                    title: '这份作品没有图片',
                    description: '重新上传作品时请至少选择 1 张照片',
                  )
                : ArtworkAnnotatedImage(
                    url: images[index].url,
                    imageIndex: index,
                    strokes: _showAnnotations
                        ? strokes
                        : const <AnnotationStroke>[],
                    onTap: () => showImageGallery(
                      context,
                      images: images.map((e) => e.url).toList(),
                      initialIndex: index,
                      heroTagPrefix: 'artwork_${detail.work.id}',
                    ),
                  ),
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              _showAnnotations && annotators.isNotEmpty
                  ? '批注来自${annotators.join('、')}老师 · 点击图片全屏查看原图'
                  : '点击图片全屏查看原图',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption12,
            ),
          ],
          if (images.length > 1) ...[
            const SizedBox(height: AppSpace.s8),
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
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.detail,
    required this.canRevise,
    this.onOpenArtwork,
    this.onCompare,
  });

  final ArtworkDetail detail;
  final bool canRevise;
  final ValueChanged<String>? onOpenArtwork;
  final VoidCallback? onCompare;

  @override
  Widget build(BuildContext context) {
    final work = detail.work;
    final reviewed = artworkReviewsByTime(
      detail.reviews.where((r) => r.reviewed),
    );
    final leadLabel = work.leadStatus.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreCard(detail: detail),
        if (artworkMarkTags(work).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s8),
            child: Wrap(spacing: AppSpace.s4, children: artworkMarkTags(work)),
          ),
        const SizedBox(height: AppSpace.s12),
        _WorkInfoCard(work: work),
        if (detail.versions.length > 1 && onOpenArtwork != null) ...[
          const SizedBox(height: AppSpace.s12),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final version in detail.versions)
                AppChip(
                  label: '第 ${version.version} 版',
                  selected: work.id == version.id,
                  onTap: () => onOpenArtwork!(version.id),
                ),
            ],
          ),
        ],
        if (onCompare != null)
          AppButton(
            label: '版本对比',
            variant: AppButtonVariant.secondary,
            onTap: onCompare,
          ),
        if (canRevise) ...[
          const SizedBox(height: AppSpace.s12),
          AppButton(
            label: '改画重交',
            icon: Icons.brush_outlined,
            onTap: () async {
              final ok = await showArtworkUploadDialog(
                context,
                parentId: work.id,
                title: work.title,
                subject: work.subject,
              );
              if (ok == true && context.mounted) {
                AppToast.showSuccess(context, '改画已提交');
              }
            },
          ),
        ],
        const SizedBox(height: AppSpace.s20),
        AppSectionHeader(
          title: '老师点评',
          trailing: Text(
            work.reviewed
                ? (leadLabel.isEmpty
                      ? (work.teacherName.isEmpty
                            ? '已点评'
                            : '${work.teacherName}老师')
                      : leadLabel)
                : '待点评',
            style: AppText.caption12,
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        if (!work.reviewed)
          const AppNotice(
            tone: AppTone.warning,
            icon: Icons.lock_clock_outlined,
            message: '责任老师点评后，即可查看分数、评语和批注',
          )
        else
          for (var i = 0; i < reviewed.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.s8),
            ArtworkReviewCard(review: reviewed[i]),
            if (reviewed[i].voiceUrl.isNotEmpty)
              HomeworkVoiceCommentBubble(
                relativePath: reviewed[i].voiceUrl,
                durationSec: reviewed[i].voiceSeconds,
              ),
          ],
        if (detail.timeline.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s20),
          const AppSectionHeader(title: '点评时间线'),
          const SizedBox(height: AppSpace.s8),
          ArtworkReviewTimeline(events: detail.timeline),
        ],
        if (detail.review case final review?
            when review.dimensions.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
          AppCard(
            title: '分项评价',
            child: Column(
              spacing: AppSpace.s8,
              children: [
                for (final dimension in detail.dimensions)
                  if (review.dimensions[dimension.key] case final level?)
                    AppListRow(
                      title: dimension.name,
                      trailing: Text('$level / 5', style: AppText.body14),
                    ),
                for (final resolution in review.tagResolutions)
                  AppListRow(
                    title: resolution.tag,
                    trailing: AppTag(
                      label: resolution.resolved ? '已改善' : '仍需加强',
                      tone: resolution.resolved
                          ? AppTone.success
                          : AppTone.warning,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 最终得分：白底卡片 + 品牌紫大号数字。
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.detail});

  final ArtworkDetail detail;

  @override
  Widget build(BuildContext context) {
    final work = detail.work;
    final score = work.finalScore;
    final reviewed = work.reviewed;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reviewed ? '最终得分' : '等待老师点评', style: AppText.caption12),
                const SizedBox(height: AppSpace.s4),
                if (reviewed && score != null)
                  ArtworkScore(
                    score: score,
                    maxScore: work.maxScore,
                    size: 32,
                    color: AppColors.brand,
                  )
                else
                  Text(
                    reviewed ? '老师没有打分，请查看评语' : '等待责任老师点评',
                    style: AppText.body14Strong,
                  ),
                if (reviewed &&
                    work.leadStatus == ArtworkLeadStatus.inReview) ...[
                  const SizedBox(height: AppSpace.s4),
                  Text('复核中', style: AppText.caption12),
                ],
              ],
            ),
          ),
          Icon(
            reviewed ? Icons.task_alt_rounded : Icons.hourglass_top_rounded,
            size: 28,
            color: reviewed ? AppColors.success : AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _WorkInfoCard extends StatelessWidget {
  const _WorkInfoCard({required this.work});

  final ArtworkSummary work;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: work.title,
      color: AppColors.surfaceSubtle,
      bordered: false,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            '提交于 ${ArtworkRules.shortTime(work.createTime)} · ${work.imageCount} 张照片',
            style: AppText.caption12,
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            work.description.isEmpty ? '没有填写作品说明' : work.description,
            style: work.description.isEmpty
                ? AppText.caption12
                : AppText.body14,
          ),
        ],
      ),
    );
  }
}
