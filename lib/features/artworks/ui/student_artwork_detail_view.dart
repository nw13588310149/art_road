import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/art/art_tokens.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/art_widgets.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/artwork_detail_controller.dart';
import 'artwork_compare_page.dart';
import 'widgets/artwork_annotation.dart';
import 'widgets/artwork_widgets.dart';

/// 学生作品详情：大图（可叠加老师批注、对比范画）、作品信息、最终得分与老师点评。
class StudentArtworkDetailView extends ConsumerStatefulWidget {
  const StudentArtworkDetailView({
    required this.artworkId,
    required this.onBack,
    super.key,
  });

  final String artworkId;
  final VoidCallback onBack;

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
        ArtPageHeader(
          title: work?.title ?? '作品详情',
          subtitle: work == null
              ? null
              : '${work.subject} · 绘于 ${ArtworkRules.dotDate(work.drawingDate)}',
          onBack: widget.onBack,
          actions: [if (work != null) ArtworkStatusBadge(done: work.reviewed)],
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
                : _buildBody(detail),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ArtworkDetail detail) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imagePanel = _buildImagePanel(detail);
        final info = _InfoColumn(detail: detail);
        if (constraints.maxWidth >= 820) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: imagePanel),
                const SizedBox(width: 16),
                SizedBox(width: 340, child: SingleChildScrollView(child: info)),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            SizedBox(height: 420, child: imagePanel),
            const SizedBox(height: 16),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (withAnnotations.isNotEmpty)
                _AnnotationToggle(
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
                    style: ArtText.caption(),
                  ),
                ),
              const Spacer(),
              ArtButton(
                label: '对比范画',
                primary: false,
                icon: Icons.compare_rounded,
                height: 32,
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
          const SizedBox(height: 10),
          Expanded(
            child: images.isEmpty
                ? const ArtEmptyState(
                    icon: Icons.image_outlined,
                    message: '这份作品没有图片',
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
          const SizedBox(height: 8),
          Text(
            _showAnnotations && annotators.isNotEmpty
                ? '红蓝笔迹为${annotators.join('、')}老师的批注 · 点击图片全屏查看'
                : '点击图片全屏查看',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ArtText.caption(size: 11),
          ),
          if (images.length > 1) ...[
            const SizedBox(height: 10),
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

class _AnnotationToggle extends StatelessWidget {
  const _AnnotationToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: value ? ArtColors.brand : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: value ? ArtColors.brand : ArtColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.visibility_rounded : Icons.visibility_off_outlined,
              size: 16,
              color: value ? Colors.white : ArtColors.ink2,
            ),
            const SizedBox(width: 6),
            Text(
              '显示老师批注',
              style: ArtText.body(
                size: 13,
                color: value ? Colors.white : ArtColors.ink2,
                weight: AppFont.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.detail});

  final ArtworkDetail detail;

  @override
  Widget build(BuildContext context) {
    final work = detail.work;
    final reviewed = detail.reviews.where((r) => r.reviewed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreCard(detail: detail),
        const SizedBox(height: 12),
        _WorkInfoCard(work: work),
        const SizedBox(height: 18),
        ArtworkSectionTitle(
          title: '老师点评',
          trailing: Text(
            '${work.reviewedCount}/${work.teacherCount} 位老师已点评',
            style: ArtText.caption(),
          ),
        ),
        if (!work.reviewed)
          _PendingNote(teachers: detail.teachers)
        else
          for (final review in reviewed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ArtworkReviewCard(review: review),
            ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.detail});

  final ArtworkDetail detail;

  @override
  Widget build(BuildContext context) {
    final work = detail.work;
    final score = work.finalScore;
    final reviewed = work.reviewed;
    final fg = reviewed ? Colors.white : ArtColors.ink;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: reviewed ? ArtColors.brandGradient : null,
        color: reviewed ? null : ArtColors.subtle,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reviewed ? '最终得分' : '等待老师点评',
                  style: ArtText.caption(
                    color: reviewed
                        ? Colors.white.withValues(alpha: 0.85)
                        : ArtColors.ink3,
                  ),
                ),
                const SizedBox(height: 6),
                if (reviewed && score != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        ArtworkRules.formatScore(score),
                        style: ArtText.number(size: 32, color: fg),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ ${ArtworkRules.formatScore(work.maxScore)}',
                        style: ArtText.caption(
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    reviewed
                        ? '老师没有打分，请查看评语'
                        : '${work.reviewedCount}/${work.teacherCount} 位老师已点评',
                    style: ArtText.body(color: fg, weight: AppFont.w500),
                  ),
                if (reviewed && score != null && work.teacherCount > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${work.teacherCount} 位老师评分的平均分',
                    style: ArtText.caption(
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            reviewed
                ? Icons.emoji_events_outlined
                : Icons.hourglass_top_rounded,
            size: 34,
            color: reviewed
                ? Colors.white.withValues(alpha: 0.75)
                : ArtColors.warn,
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
    return ArtCard(
      color: ArtColors.subtle,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ArtworkSubjectChip(subject: work.subject),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '绘于 ${ArtworkRules.dotDate(work.drawingDate)}',
                  style: ArtText.caption(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '提交于 ${ArtworkRules.shortTime(work.createTime)} · ${work.imageCount} 张照片',
            style: ArtText.caption(),
          ),
          const SizedBox(height: 8),
          Text(
            work.description.isEmpty ? '没有填写作品说明' : work.description,
            style: work.description.isEmpty
                ? ArtText.caption()
                : ArtText.body(size: 13, color: ArtColors.ink2, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _PendingNote extends StatelessWidget {
  const _PendingNote({required this.teachers});

  final List<ArtworkTeacher> teachers;

  @override
  Widget build(BuildContext context) {
    return ArtCard(
      color: ArtColors.subtle,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_clock_outlined,
                size: 18,
                color: ArtColors.warn,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '全部老师点评完成后，即可查看分数、评语和批注',
                  style: ArtText.body(size: 13, weight: AppFont.w500),
                ),
              ),
            ],
          ),
          for (final teacher in teachers) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ArtAvatar(name: teacher.teacherName, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${teacher.teacherName}老师',
                    style: ArtText.body(size: 13),
                  ),
                ),
                ArtworkStatusBadge(done: teacher.reviewed),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
