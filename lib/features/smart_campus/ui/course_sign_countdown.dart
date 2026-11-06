import 'dart:async';

import 'package:flutter/material.dart';

import '../../shell/ui/shell_layout.dart';
import '../data/course_sign_data.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 签到操作区当前课程右上角倒计时。
class CourseSignCountdownBadge extends StatefulWidget {
  const CourseSignCountdownBadge({
    super.key,
    required this.startTime,
    required this.endTime,
  });

  final String startTime;
  final String endTime;

  @override
  State<CourseSignCountdownBadge> createState() =>
      _CourseSignCountdownBadgeState();
}

class _CourseSignCountdownBadgeState extends State<CourseSignCountdownBadge> {
  Timer? _timer;
  late CourseSlotCountdownSnapshot _snapshot = buildCourseSlotCountdown(
    now: DateTime.now(),
    startHm: widget.startTime,
    endHm: widget.endTime,
  );

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant CourseSignCountdownBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime ||
        oldWidget.endTime != widget.endTime) {
      _tick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _snapshot = buildCourseSlotCountdown(
        now: DateTime.now(),
        startHm: widget.startTime,
        endHm: widget.endTime,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final ended = _snapshot.phase == CourseSlotPhase.ended;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_snapshot.label.isNotEmpty) ...[
          Text(
            _snapshot.label,
            style: TextStyle(
              fontSize: ui(10),
              color: const Color(0xFFB6B5BB),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 1,
            ),
          ),
          SizedBox(width: ui(4)),
        ],
        Text(
          _snapshot.timeText,
          style: TextStyle(
            fontSize: ended ? ui(12) : ui(14),
            color: ended ? const Color(0xFFB6B5BB) : const Color(0xFF8741FF),
            fontFamily: ended ? 'PingFang SC' : 'Barlow',
            fontWeight: ended ? AppFont.w400 : FontWeight.w600,
            height: 1,
            // 等宽数字，避免每秒刷新时 HH:MM:SS 宽度抖动。
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
