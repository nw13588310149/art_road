import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../data/today_models.dart';

/// 今日页图表与状态的用色。
///
/// 主系列用品牌紫，同一色系的浅色做底和非重点；好 / 需注意 / 有问题三种状态
/// 用绿、琥珀、红，这一组用配色校验脚本核过（色觉差异下相邻两色仍可区分；
/// 琥珀色与白底对比度不足 3:1，所以每处都带文字标签和数字）。
/// 三科的科目色里色彩与速写太接近，图表里不用它们区分系列，靠文字标注。
abstract final class TodayPalette {
  static const brand = AppColors.brand;

  /// 非重点的柱子：品牌紫的浅一档。
  static const brandMuted = Color(0xFFB3A8FF);
  static const good = AppColors.success;
  static const caution = Color(0xFFE8A317);
  static const bad = AppColors.danger;
  static const neutral = Color(0xFFC7CAD3);

  /// 没有填充的底：进度条、还没做的事。
  static const track = Color(0xFFEEF0F6);

  /// 头图的渐变：从深一档的品牌紫到浅一档。
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5A47E6), Color(0xFF715EFE), Color(0xFF9A8BFF)],
    stops: [0, 0.55, 1],
  );

  /// 重点柱子的渐变。
  static const barGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xFF5D45ED), Color(0xFF8F7DFF)],
  );

  static Color tone(String name) => switch (name) {
    'good' => good,
    'caution' => caution,
    'bad' => bad,
    'neutral' => neutral,
    _ => brand,
  };

  /// 进度条的底：与填充同一色系的浅色。
  static Color trackOf(String name) => switch (name) {
    'good' => AppColors.successSoft,
    'caution' => AppColors.warningSoft,
    'bad' => AppColors.dangerSoft,
    'neutral' => AppColors.surfaceSubtle,
    _ => AppColors.brandTint,
  };

  /// 色块上的文字：深色块用白字，浅色块用墨色。
  static Color onTone(String name) => switch (name) {
    'caution' || 'neutral' => AppColors.ink,
    _ => AppColors.onBrand,
  };

  static AppTone tagTone(String name) => switch (name) {
    'danger' || 'bad' => AppTone.danger,
    'warning' || 'caution' => AppTone.warning,
    'brand' => AppTone.brand,
    'good' => AppTone.success,
    _ => AppTone.neutral,
  };
}

/// 图标底色的四种色调，和首页九宫格图标是同一家：紫、粉、青，加一个琥珀。
/// 只用来给图标分组上色，不承载数据含义。
enum TodayTint {
  purple(Color(0xFF715EFE), Color(0xFFEFECFF)),
  pink(Color(0xFFF2557F), Color(0xFFFFECF1)),
  teal(Color(0xFF0FA89A), Color(0xFFE0F6F2)),
  amber(Color(0xFFDD8A00), Color(0xFFFFF2D8)),
  blue(Color(0xFF3B7CF5), Color(0xFFE7F0FF));

  const TodayTint(this.color, this.soft);

  final Color color;
  final Color soft;

  static TodayTint parse(String name) => switch (name) {
    'pink' => TodayTint.pink,
    'teal' => TodayTint.teal,
    'amber' => TodayTint.amber,
    'blue' => TodayTint.blue,
    _ => TodayTint.purple,
  };
}

/// 一件事的图标，按类型取。
IconData todayStepIcon(String kind) => switch (kind) {
  'lesson' => Icons.class_outlined,
  'homework' => Icons.brush_outlined,
  'revise' => Icons.auto_fix_high_outlined,
  'practice' => Icons.timer_outlined,
  'reading' => Icons.menu_book_outlined,
  'dorm' => Icons.bedtime_outlined,
  'review' => Icons.rate_review_outlined,
  'lead' => Icons.fact_check_outlined,
  'approval' => Icons.task_alt_rounded,
  'supervise' => Icons.notification_important_outlined,
  'follow' => Icons.person_search_outlined,
  'message' => Icons.forum_outlined,
  'patrol' => Icons.directions_walk_rounded,
  'punch' => Icons.fingerprint_rounded,
  'note' => Icons.edit_note_rounded,
  _ => Icons.push_pin_outlined,
};

/// 一件事的图标色调：上课紫，作品与点评粉，练习与沟通青，查寝与巡查琥珀，其余蓝。
TodayTint todayStepTint(String kind) => switch (kind) {
  'lesson' => TodayTint.purple,
  'homework' || 'revise' || 'review' || 'lead' => TodayTint.pink,
  'approval' || 'supervise' => TodayTint.pink,
  'practice' || 'follow' || 'message' => TodayTint.teal,
  'dorm' || 'patrol' || 'punch' => TodayTint.amber,
  _ => TodayTint.blue,
};

/// 一件事的类型名，给不熟悉的人看的说法。
String todayStepKindLabel(String kind) => switch (kind) {
  'lesson' => '课程',
  'homework' => '交作品',
  'revise' => '改画',
  'practice' => '练习',
  'reading' => '阅读',
  'dorm' => '查寝',
  'review' => '点评',
  'lead' => '复核',
  'approval' => '审批',
  'supervise' => '督办',
  'follow' => '跟进',
  'message' => '回复',
  'patrol' => '巡查',
  'punch' => '打卡',
  'note' => '安排',
  _ => '自己的安排',
};

/// 数字卡、常用入口的图标，按名字取。
IconData todayIcon(String name) => switch (name) {
  'lesson' => Icons.class_outlined,
  'homework' => Icons.brush_outlined,
  'practice' => Icons.timer_outlined,
  'exam' => Icons.flag_outlined,
  'review' => Icons.rate_review_outlined,
  'timely' => Icons.speed_rounded,
  'follow' => Icons.person_search_outlined,
  'approval' => Icons.task_alt_rounded,
  'supervise' => Icons.notification_important_outlined,
  'schedule' => Icons.calendar_month_outlined,
  'upload' => Icons.add_photo_alternate_outlined,
  'leave' => Icons.event_busy_outlined,
  'notes' => Icons.sticky_note_2_outlined,
  'favorite' => Icons.favorite_border_rounded,
  'students' => Icons.groups_outlined,
  'teachers' => Icons.badge_outlined,
  'classes' => Icons.meeting_room_outlined,
  'performance' => Icons.insights_outlined,
  'chart' => Icons.show_chart_rounded,
  'dashboard' => Icons.dashboard_outlined,
  'message' => Icons.forum_outlined,
  'dorm' => Icons.bedtime_outlined,
  'notice' => Icons.campaign_outlined,
  'face' => Icons.face_retouching_natural_outlined,
  'chain' => Icons.account_tree_outlined,
  'history' => Icons.history_rounded,
  'audit' => Icons.edit_calendar_outlined,
  'mail' => Icons.mail_outline_rounded,
  _ => Icons.arrow_outward_rounded,
};

/// 图表卡片的图标与色调，按图表 id 取；不认识的按类型给一个。
({IconData icon, TodayTint tint}) todayChartBadge(TodayChart chart) =>
    switch (chart.id) {
      'week' => (
        icon: Icons.insert_chart_outlined_rounded,
        tint: TodayTint.purple,
      ),
      'practice' => (icon: Icons.timer_outlined, tint: TodayTint.teal),
      'subjects' => (icon: Icons.school_outlined, tint: TodayTint.purple),
      'works' => (icon: Icons.brush_outlined, tint: TodayTint.pink),
      'review' => (icon: Icons.rate_review_outlined, tint: TodayTint.pink),
      'timely' => (icon: Icons.speed_rounded, tint: TodayTint.teal),
      'homework' => (
        icon: Icons.assignment_turned_in_outlined,
        tint: TodayTint.blue,
      ),
      'attendance' ||
      'classAttendance' ||
      'presence' => (icon: Icons.how_to_reg_outlined, tint: TodayTint.teal),
      'attendance7' => (icon: Icons.trending_up_rounded, tint: TodayTint.teal),
      'classDorm' ||
      'check' ||
      'rooms' => (icon: Icons.bedtime_outlined, tint: TodayTint.amber),
      'abnormal' => (
        icon: Icons.report_gmailerrorred_outlined,
        tint: TodayTint.amber,
      ),
      'courses' => (icon: Icons.class_outlined, tint: TodayTint.purple),
      'classes' => (icon: Icons.meeting_room_outlined, tint: TodayTint.blue),
      'handled' => (icon: Icons.task_alt_rounded, tint: TodayTint.pink),
      'face' => (
        icon: Icons.face_retouching_natural_outlined,
        tint: TodayTint.amber,
      ),
      'chain' => (icon: Icons.account_tree_outlined, tint: TodayTint.pink),
      'campus' => (icon: Icons.apartment_rounded, tint: TodayTint.blue),
      'group' => (icon: Icons.groups_outlined, tint: TodayTint.blue),
      _ => (icon: Icons.insights_outlined, tint: TodayTint.purple),
    };

/// 状态对应的颜色：完成是绿，进行中是品牌紫，超时是红，其余是灰。
Color todayStatusColor(TodayStepStatus status) => switch (status) {
  TodayStepStatus.done => TodayPalette.good,
  TodayStepStatus.doing => TodayPalette.brand,
  TodayStepStatus.overdue => TodayPalette.bad,
  _ => AppColors.textTertiary,
};

/// 图标底座：圆角方块 + 线性图标，颜色取一种色调。
class TodayIconChip extends StatelessWidget {
  const TodayIconChip({
    required this.icon,
    required this.tint,
    this.size = 40,
    this.muted = false,
    super.key,
  });

  final IconData icon;
  final TodayTint tint;
  final double size;

  /// 已完成或今天不做的事：图标变灰。
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? AppColors.surfaceSubtle : tint.soft,
        borderRadius: size >= 36 ? AppRadius.br12 : AppRadius.br8,
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: muted ? AppColors.textTertiary : tint.color,
      ),
    );
  }
}
