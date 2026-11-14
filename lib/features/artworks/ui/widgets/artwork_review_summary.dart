import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/artwork_models.dart';
import '../../data/artwork_rules.dart';

/// 三类评价身份。人数来自独立评价记录，不以角色数代替点评人数。
class ArtworkReviewSummary extends StatelessWidget {
  const ArtworkReviewSummary({required this.detail, super.key});
  final ArtworkDetail detail;

  @override
  Widget build(BuildContext context) {
    final teachers = detail.reviews.where((review) => review.reviewed).toList();
    final lead = detail.leadReview;
    return AppCard(
      title: '作品点评',
      subtitle: '任课老师 → 教学组长 → 校长',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(
            '任课老师',
            '${teachers.length} / ${detail.work.teacherCount} 位已点评',
          ),
          if (teachers.isEmpty) Text('等待任课老师点评', style: AppText.body13),
          for (final review in teachers)
            _score(review.teacherName, review.score, review.maxScore),
          const Divider(height: 24, color: AppColors.line),
          _heading('教学组长', lead?.action.isNotEmpty == true ? '已点评' : '待点评'),
          if (lead?.action.isNotEmpty == true) ...[
            _score(
              lead!.leaderName,
              lead.score ??
                  (lead.action == 'KEEP' ? detail.work.finalScore : null),
              detail.work.maxScore,
            ),
            if (lead.content.isNotEmpty || lead.reason.isNotEmpty)
              Text(
                lead.content.isNotEmpty ? lead.content : lead.reason,
                style: AppText.body13,
              ),
          ],
          const Divider(height: 24, color: AppColors.line),
          _heading('校长', detail.principalComments.isEmpty ? '可查阅与点评' : '已点评'),
          for (final comment in detail.principalComments) ...[
            _score(comment.name, comment.score, detail.work.maxScore),
            Text(comment.content, style: AppText.body13),
          ],
          const SizedBox(height: 16),
          Text(
            '教学参考分采用组长评分；组长未评分时采用任课老师均分。校长评分独立展示。',
            style: AppText.caption12,
          ),
        ],
      ),
    );
  }

  Widget _heading(String title, String status) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(title, style: AppText.body14Strong)),
        Text(status, style: AppText.caption12),
      ],
    ),
  );

  Widget _score(String name, double? score, double maximum) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        AppAvatar(name: name, size: 28),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: AppText.body14)),
        Text(
          score == null
              ? '未评分'
              : '${ArtworkRules.displayScore(score)} / ${ArtworkRules.displayScore(maximum)}',
          style: AppText.number(size: 16),
        ),
      ],
    ),
  );
}
