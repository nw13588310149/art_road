import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../ui/app_empty_state.dart';

/// 课程列表为空时的占位（旧名保留），等同组件库 [AppEmptyState]。
///
/// [schoolMode]、[imageAsset] 为旧参数，不再生效（不再显示大插图）。
class CourseEmptyPlaceholder extends StatelessWidget {
  const CourseEmptyPlaceholder({
    super.key,
    this.message = '暂无课程',
    this.schoolMode = false,
    this.imageAsset = AppAssets.emptyCoursePlaceholder,
  });

  final String message;
  final bool schoolMode;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.event_available_outlined,
      title: message,
      description: '排课后会在这里显示上课时间和任课老师',
    );
  }
}
