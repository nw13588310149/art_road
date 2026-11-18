import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/artwork_models.dart';
import '../../data/artwork_rules.dart';
import '../artwork_compare_page.dart';
import 'artwork_mark_layer.dart';
import 'artwork_mark_response.dart';
import 'artwork_widgets.dart';

/// 学生看到的定点点评编号：已点评的几位老师按点评先后，同一位老师的按图片先后、
/// 再按添加先后。学生端、老师端说「第几处」都按它。
List<NumberedArtworkMark> artworkDetailMarks(ArtworkDetail detail) =>
    numberArtworkMarks(
      artworkReviewsByTime(detail.reviews.where((r) => r.reviewed)),
    );

/// 打开版本对比，两侧锁定、一起放大到上一版的这一处，顶栏写明是第几处。
Future<void> openArtworkMarkBeforeAfter(
  BuildContext context, {
  required ArtworkDetail current,
  required ArtworkDetail previous,
  required NumberedArtworkMark item,
}) {
  final text = item.mark.text.trim();
  return openArtworkCompare(
    context,
    images: current.images.map((image) => image.url).toList(),
    previousImages: previous.images.map((image) => image.url).toList(),
    subject: current.work.subject,
    initialIndex: item.mark.imageIndex,
    focus: item.mark.position,
    focusLabel: '第 ${item.number} 处 · ${text.isEmpty ? '语音点评' : text}',
  );
}

/// 改画版本上的「上一版的定点点评」：每一处的编号、说的话、老师（几位时）和学生的
/// 回应。整行可点，打开这一处的改前改后。
class ArtworkPreviousMarks extends StatelessWidget {
  const ArtworkPreviousMarks({
    required this.marks,
    required this.onOpen,
    this.responsePrefix = '',
    this.header,
    super.key,
  });

  final List<NumberedArtworkMark> marks;
  final ValueChanged<NumberedArtworkMark> onOpen;

  /// 回应前面的字：老师端写「学生：」，学生端不写。
  final String responsePrefix;

  /// 分区标题；不传时用默认的「上一版的定点点评」一行。
  final Widget? header;

  static const title = '上一版的定点点评';

  @override
  Widget build(BuildContext context) {
    final showTeacher = marks.map((m) => m.teacherId).toSet().length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header ??
            AppSectionHeader(
              title: title,
              trailing: Text(
                ArtworkRules.markCount(marks.map((m) => m.mark)),
                style: AppText.caption12,
              ),
            ),
        for (var i = 0; i < marks.length; i++) ...[
          if (i > 0) const AppRule(),
          _PreviousMarkRow(
            key: ValueKey<String>('previous-mark-${marks[i].key}'),
            item: marks[i],
            showTeacher: showTeacher,
            responsePrefix: responsePrefix,
            onTap: () => onOpen(marks[i]),
          ),
        ],
      ],
    );
  }
}

class _PreviousMarkRow extends StatelessWidget {
  const _PreviousMarkRow({
    required this.item,
    required this.showTeacher,
    required this.responsePrefix,
    required this.onTap,
    super.key,
  });

  final NumberedArtworkMark item;
  final bool showTeacher;
  final String responsePrefix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mark = item.mark;
    final text = mark.text.trim();
    final response = mark.response?.status;
    final semantics = <String>[
      ArtworkRules.markSemantics(
        item.number,
        text,
        hasVoice: mark.hasVoice,
        voiceSeconds: mark.voiceSeconds,
        teacherName: showTeacher ? item.teacherName : '',
        response: response,
      ),
      '看改前改后',
    ].join('，');
    return AppPressable(
      onTap: onTap,
      semanticLabel: semantics,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: ArtworkMarkDot(number: item.number, size: 24),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.isEmpty ? '（只有语音）' : text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: text.isEmpty
                            ? AppText.body14.copyWith(
                                color: AppColors.textSecondary,
                              )
                            : AppText.body14,
                      ),
                      const SizedBox(height: AppSpace.s4),
                      Row(
                        children: [
                          if (showTeacher) ...[
                            Text(
                              '${item.teacherName}老师',
                              style: AppText.caption12,
                            ),
                            const SizedBox(width: AppSpace.s12),
                          ],
                          if (response != null)
                            ArtworkMarkResponseLabel(
                              status: response,
                              prefix: responsePrefix,
                            ),
                          const Spacer(),
                          Text(
                            '看改前改后',
                            style: AppText.caption12.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
