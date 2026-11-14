import 'package:flutter/material.dart';

import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/ui.dart';
import '../../../smart_campus/state/smart_campus_state.dart';
import '../../../smart_campus/ui/widgets/smart_campus_avatar_role_badge.dart';
import '../../../smart_campus/ui/widgets/smart_campus_square_tag.dart';
import '../../data/artwork_models.dart';
import '../../data/artwork_rules.dart';

/// 作品时间线：提交 → 老师点评 → 补充点评 → 组长复核 → 校长点评 → 推优。
///
/// 每条一行身份方角标签（用原版的身份色）+ 姓名 + 做了什么 + 时间，下面是内容。
class ArtworkReviewTimeline extends StatelessWidget {
  const ArtworkReviewTimeline({required this.events, super.key});

  final List<ArtworkTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < events.length; i++)
          _TimelineRow(event: events[i], last: i == events.length - 1),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.last});

  final ArtworkTimelineEvent event;
  final bool last;

  static const _railWidth = 16.0;

  @override
  Widget build(BuildContext context) {
    final type = event.type.toUpperCase();
    final action = _actionOf(event, type);
    // 提交、推优这两种事件的内容就是动作本身，不再重复一行。
    final content = type == 'SUBMIT' || type == 'FEATURE'
        ? ''
        : event.content.trim();
    final time = event.time.isEmpty ? '' : ArtworkRules.shortTime(event.time);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _railWidth,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: last ? AppColors.brand : AppColors.textPlaceholder,
                      width: 2,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.only(top: 4),
                      color: AppColors.lineSoft,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _RoleTag(role: event.role),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            color: AppColors.ink,
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w500,
                          ),
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: AppText.number(
                            size: 12,
                            color: AppColors.textPlaceholder,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(action, style: AppText.body13),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: AppRadius.br8,
                      ),
                      child: Text(
                        content,
                        style: AppText.body13.copyWith(color: AppColors.ink),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _actionOf(ArtworkTimelineEvent event, String type) {
    String points(double? value) => '${ArtworkRules.displayScore(value)} 分';
    switch (type) {
      case 'SUBMIT':
        return event.content.trim().isEmpty ? '提交作品' : event.content.trim();
      case 'LEAD_REVIEW':
        return '组长点评 · ${points(event.score)}';
      case 'REVIEW_HISTORY':
        return '历史评价 · ${event.score == null ? '未评分' : points(event.score)}';
      case 'REVIEW':
        return event.score == null ? '点评 · 未评分' : '点评 · ${points(event.score)}';
      case 'SUPPLEMENT':
        return '补充点评（不计分）';
      case 'LEAD_KEEP':
        return '复核 · 维持原分';
      case 'LEAD_ADJUST':
        final from = event.fromScore;
        final to = event.toScore ?? event.score;
        return from == null
            ? '复核 · 调分为 ${points(to)}'
            : '复核 · 调分 ${ArtworkRules.displayScore(from)} → ${points(to)}';
      case 'LEAD_SUPPLEMENT':
        return '复核 · 补充评语';
      case 'PRINCIPAL_COMMENT':
        return event.score == null ? '校长点评' : '校长点评 · ${points(event.score)}';
      case 'FEATURE':
        return '推荐到优秀作品墙';
      default:
        return event.content.trim();
    }
  }
}

class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final (label, identity) = switch (role.toUpperCase()) {
      'STUDENT' => ('学生', SmartCampusRole.student),
      'LEADER' => ('组长', SmartCampusRole.headTeacher),
      'PRINCIPAL' => ('校长', SmartCampusRole.principal),
      _ => ('老师', SmartCampusRole.teacher),
    };
    final colors = smartCampusRoleBadgeColors(identity);
    return SmartCampusSquareTag(
      label: label,
      background: colors.bg,
      foreground: colors.fg,
    );
  }
}
