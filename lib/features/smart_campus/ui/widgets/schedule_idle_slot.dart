import 'package:flutter/material.dart';

import 'schedule_course_card.dart';

/// 课表空格：没有课的格子留白，不画虚线框和「空闲」字样；编辑态的
/// 「申请小课」入口由各页面自己放。
class ScheduleIdleSlot extends StatelessWidget {
  const ScheduleIdleSlot({super.key});

  /// 单张课程卡所在格子的高度（上下各 6 留白）。
  static const double designSlotHeight = kScheduleCourseCardHeight + 12;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
