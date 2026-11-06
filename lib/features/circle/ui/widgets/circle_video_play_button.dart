import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';

/// 列表 / 沉浸模式统一的视频播放按钮（暂停态展示）。
class CircleVideoPlayButton extends StatelessWidget {
  const CircleVideoPlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(48),
      height: ui(48),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: ui(28),
      ),
    );
  }
}
