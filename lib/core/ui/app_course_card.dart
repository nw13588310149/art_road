import 'package:flutter/material.dart';

import 'app_avatar.dart';
import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_status_tag.dart';
import 'app_tag.dart';
import 'app_text.dart';

/// 课程阶段。
enum AppCourseStatus { upcoming, inProgress, ended }

/// 课程卡（首页课程、课堂考勤、任课老师今日课表共用），高度随内容。
///
/// - 第一行：起止时间（Barlow 18）+ 右侧状态；
/// - 第二行：科目标签；
/// - 第三行：头像 + 姓名 + 副标题（时长 · 班级 · 教室）。
///
/// 卡片是放在白色面板里的浅灰子卡片；[selected] 时浅紫底 + 品牌紫描边。
class AppCourseCard extends StatelessWidget {
  const AppCourseCard({
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.teacherName,
    this.subtitle = '',
    this.status = AppCourseStatus.upcoming,
    this.statusTag,
    this.avatarUrl = '',
    this.avatar,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String startTime;
  final String endTime;
  final String subject;

  /// 头像旁的名字：任课老师，老师自己的课表里可以是班级名。
  final String teacherName;
  final String subtitle;
  final AppCourseStatus status;

  /// 替换右上角默认状态（如签到结果「正常 / 缺勤」）。
  final Widget? statusTag;
  final String avatarUrl;

  /// 自定义头像，优先于 [avatarUrl]。
  final Widget? avatar;
  final bool selected;
  final VoidCallback? onTap;

  static const double avatarSize = 36;

  @override
  Widget build(BuildContext context) {
    final ended = status == AppCourseStatus.ended;
    final note = subtitle.trim();
    final hasEnd = endTime.isNotEmpty && endTime != '--:--';
    final timeStyle = AppText.displayNumber(
      size: 18,
      color: ended ? AppColors.textSecondary : AppColors.ink,
    ).copyWith(height: 1.2);

    final card = Container(
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: selected ? AppColors.brandWash : AppColors.surfaceSubtle,
        borderRadius: AppRadius.br12,
        border: Border.all(
          color: selected ? AppColors.brand : const Color(0x00000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      style: timeStyle,
                      children: [
                        TextSpan(text: startTime),
                        if (hasEnd) ...[
                          const TextSpan(
                            text: ' – ',
                            style: TextStyle(color: AppColors.textPlaceholder),
                          ),
                          TextSpan(text: endTime),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              statusTag ?? _defaultStatus(),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: ended
                ? AppTag(
                    label: subject,
                    color: AppColors.textTertiary,
                    background: AppColors.surface,
                  )
                : AppTag.subject(subject),
          ),
          const SizedBox(height: AppSpace.s8),
          Row(
            children: [
              avatar ??
                  AppAvatar(
                    name: teacherName,
                    url: avatarUrl,
                    size: avatarSize,
                  ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      teacherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14Strong.copyWith(height: 20 / 14),
                    ),
                    if (note.isNotEmpty)
                      Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption12.copyWith(height: 16 / 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) {
      return card;
    }
    return AppPressable(onTap: onTap, selected: selected, child: card);
  }

  Widget _defaultStatus() {
    return switch (status) {
      AppCourseStatus.inProgress => const AppStatusTag(
        label: '进行中',
        tone: AppTone.brand,
      ),
      AppCourseStatus.upcoming => const AppStatusTag(
        label: '待开始',
        tone: AppTone.warning,
      ),
      AppCourseStatus.ended => const AppStatusTag(label: '已结束'),
    };
  }
}
