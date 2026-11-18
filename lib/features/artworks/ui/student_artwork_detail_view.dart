import 'widgets/artwork_review_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/artwork_detail_controller.dart';
import '../state/artwork_review_controller.dart';
import '../state/artwork_voice_player.dart';
import '../state/student_artworks_controller.dart';
import 'artwork_compare_page.dart';
import 'artwork_upload_dialog.dart';
import 'widgets/artwork_annotation.dart';
import 'widgets/artwork_mark_layer.dart';
import 'widgets/artwork_mark_list.dart';
import 'widgets/artwork_marks.dart';
import 'widgets/artwork_previous_marks.dart';
import 'widgets/artwork_review_timeline.dart';
import 'widgets/artwork_voice_note.dart';
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

  /// 选中的定点点评（[NumberedArtworkMark.key]），图上编号和列表行一起高亮。
  String? _selectedMark;
  final _popover = OverlayPortalController();
  final _popoverLink = LayerLink();

  /// 图上编号、浮层和列表算一组：点它们不会关掉浮层。
  final _markGroup = Object();
  final _markRowKeys = <String, GlobalKey>{};

  static List<NumberedArtworkMark> _marksOf(ArtworkDetail detail) =>
      artworkDetailMarks(detail);

  /// 作品主人才能标「改了 / 没看懂」。
  bool _canRespond(ArtworkDetail detail) => detail.isOwner && !widget.readOnly;

  void _respond(NumberedArtworkMark item, ArtworkMarkResponseStatus? status) {
    ref
        .read(studentArtworkDetailProvider(widget.artworkId).notifier)
        .respondToMark(item, status);
  }

  /// 从这一版改画重交成功：刷新这一版（版本和「改画重交」跟着变），能切换时切到新的一版。
  void _onSubmitted(ArtworkSubmission? submission) {
    if (submission == null || submission.parentId != widget.artworkId) {
      return;
    }
    ref.invalidate(studentArtworkDetailProvider(widget.artworkId));
    final open = widget.onOpenArtwork;
    if (open != null && submission.id.isNotEmpty) {
      open(submission.id);
    }
  }

  /// 点图上编号或列表行：选中、打开浮层、播这一处的语音。再点同一个编号收起。
  void _selectMark(NumberedArtworkMark item, {bool fromList = false}) {
    final player = ref.read(artworkVoicePlayerProvider.notifier);
    final previous = _selectedMark;
    if (previous == item.key && !fromList) {
      _closeMark();
      return;
    }
    setState(() {
      _selectedMark = item.key;
      _showAnnotations = true;
      _imageIndex = item.mark.imageIndex;
    });
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
        final row = _markRowKeys[item.key]?.currentContext;
        if (mounted && row != null) {
          Scrollable.ensureVisible(row, alignment: 0.3);
        }
      });
    }
  }

  void _closeMark() {
    if (_selectedMark == null) {
      return;
    }
    setState(() => _selectedMark = null);
    _popover.hide();
  }

  void _selectImage(int index) {
    if (index == _imageIndex) {
      return;
    }
    _closeMark();
    setState(() => _imageIndex = index);
  }

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
    ref.listen<ArtworkSubmission?>(
      studentArtworkSubmittedProvider,
      (_, next) => _onSubmitted(next),
    );

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

  @override
  void didUpdateWidget(covariant StudentArtworkDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkId != widget.artworkId) {
      _selectedMark = null;
      _imageIndex = 0;
    }
  }

  Widget _buildBody(ArtworkDetail detail) {
    final previousId = ArtworkReviewController.previousVersionId(detail);
    final previous = previousId == null
        ? null
        : ref.watch(studentArtworkDetailProvider(previousId)).detail;
    final marks = _marksOf(detail);
    final previousMarks =
        previous == null || previous.images.isEmpty || detail.images.isEmpty
        ? const <NumberedArtworkMark>[]
        : _marksOf(previous);
    return LayoutBuilder(
      builder: (context, constraints) {
        final imagePanel = OverlayPortal(
          controller: _popover,
          overlayChildBuilder: (_) => _buildPopover(detail, marks),
          child: _buildImagePanel(detail, marks),
        );
        final info = _InfoColumn(
          detail: detail,
          marks: marks.isEmpty ? null : _buildMarksSection(detail, marks),
          previousMarks: previousMarks.isEmpty
              ? null
              : ArtworkPreviousMarks(
                  marks: previousMarks,
                  onOpen: (item) => openArtworkMarkBeforeAfter(
                    context,
                    current: detail,
                    previous: previous!,
                    item: item,
                  ),
                ),
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

  Widget _buildMarksSection(
    ArtworkDetail detail,
    List<NumberedArtworkMark> marks,
  ) {
    final teachers = marks.map((m) => m.teacherId).toSet();
    for (final item in marks) {
      _markRowKeys.putIfAbsent(item.key, GlobalKey.new);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: '定点点评',
          trailing: Text(
            '${marks.length} 处 · 点编号看画上的位置',
            style: AppText.caption12,
          ),
        ),
        TapRegion(
          groupId: _markGroup,
          child: ArtworkMarkList(
            marks: marks,
            selectedKey: _selectedMark,
            showTeacher: teachers.length > 1,
            rowKeys: _markRowKeys,
            onSelect: (item) => _selectMark(item, fromList: true),
            onRespond: _canRespond(detail) ? _respond : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPopover(ArtworkDetail detail, List<NumberedArtworkMark> marks) {
    final item = marks.where((m) => m.key == _selectedMark).firstOrNull;
    if (item == null ||
        !_showAnnotations ||
        item.mark.imageIndex != _imageIndex) {
      return const SizedBox.shrink();
    }
    // 编号在画的左侧时浮层放右边，在下半部时浮层向上展开，尽量不出画面。
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
          child: ArtworkMarkPopover(
            item: item,
            showTeacher: marks.map((m) => m.teacherId).toSet().length > 1,
            onClose: _closeMark,
            onRespond: _canRespond(detail)
                ? (status) => _respond(item, status)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildMarkLayer(List<NumberedArtworkMark> marksHere, int teachers) {
    return ArtworkMarkLayer(
      pins: [
        for (final item in marksHere)
          ArtworkMarkPin(
            key: item.key,
            position: item.mark.position,
            number: item.number,
            semanticLabel: ArtworkRules.markSemantics(
              item.number,
              item.mark.text,
              hasVoice: item.mark.hasVoice,
              voiceSeconds: item.mark.voiceSeconds,
              teacherName: teachers > 1 ? item.teacherName : '',
              response: item.mark.response?.status,
            ),
          ),
      ],
      selectedKey: _selectedMark,
      selectedLink: _popoverLink,
      tapGroup: _markGroup,
      onTapPin: (key) => _selectMark(marksHere.firstWhere((m) => m.key == key)),
    );
  }

  Widget _buildImagePanel(
    ArtworkDetail detail,
    List<NumberedArtworkMark> marks,
  ) {
    final images = detail.images;
    final index = images.isEmpty ? 0 : _imageIndex.clamp(0, images.length - 1);
    final withAnnotations = detail.reviews
        .where((r) => r.annotations.isNotEmpty)
        .toList();
    final marksHere = <NumberedArtworkMark>[
      for (final item in marks)
        if (item.mark.imageIndex == index) item,
    ];
    final teacherCount = marks.map((m) => m.teacherId).toSet().length;
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
              if (withAnnotations.isNotEmpty || marks.isNotEmpty)
                AppSegmented<bool>(
                  size: AppControlSize.sm,
                  segments: const [
                    AppSegment(value: false, label: '原图'),
                    AppSegment(value: true, label: '老师批注'),
                  ],
                  value: _showAnnotations,
                  onChanged: (value) {
                    if (!value) {
                      _closeMark();
                    }
                    setState(() => _showAnnotations = value);
                  },
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
                      titles: [detail.work.title],
                    ),
                    overlay: _showAnnotations && marksHere.isNotEmpty
                        ? _buildMarkLayer(marksHere, teacherCount)
                        : null,
                  ),
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              <String>[
                if (_showAnnotations && annotators.isNotEmpty)
                  '批注来自${annotators.join('、')}老师',
                if (_showAnnotations && marksHere.isNotEmpty) '点编号看这一处的点评',
                '点击图片全屏查看原图',
              ].join(' · '),
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
              onSelect: _selectImage,
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
    this.marks,
    this.previousMarks,
    this.onOpenArtwork,
    this.onCompare,
  });

  final ArtworkDetail detail;
  final bool canRevise;

  /// 定点点评列表，紧跟在得分下面，和左边画上的编号对照着看。
  final Widget? marks;

  /// 改画版本：上一版的定点点评，在这一版的定点点评下面。
  final Widget? previousMarks;
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
        if (marks case final section?) ...[
          const SizedBox(height: AppSpace.s16),
          section,
        ],
        if (previousMarks case final section?) ...[
          const SizedBox(height: AppSpace.s16),
          section,
        ],
        const SizedBox(height: 12),
        ArtworkReviewSummary(detail: detail),
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
              ArtworkVoiceNoteBar(
                playKey: 'review:${reviewed[i].teacherId}',
                source: reviewed[i].voiceUrl,
                seconds: reviewed[i].voiceSeconds,
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
          if (work.practiceSource.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppTag(
                label: '练习来源：${work.practiceSource['label'] ?? ''}',
              ),
            ),
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
