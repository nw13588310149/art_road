import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../../features/shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 课程列表为空时的统一占位：163×163 插图 + 居中文案。
///
/// 校园课件入口（[schoolMode]）下图示放大至 183×183（+20）。
class CourseEmptyPlaceholder extends StatelessWidget {
  const CourseEmptyPlaceholder({
    super.key,
    this.message = '暂无课程',
    this.schoolMode = false,
    this.imageAsset = AppAssets.emptyCoursePlaceholder,
  });

  static const double _imageSize = 200;
  static const double _schoolImageSize = 183;
  static const double _textVisualPullUp = 22;

  final String message;
  final bool schoolMode;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final imageSize = schoolMode ? _schoolImageSize : _imageSize;
    return SizedBox.expand(
      child: Center(
        child: Transform.translate(
          // 文案上移后布局高度未变，整体视觉重心会偏下；上移一半以在容器内居中。
          offset: Offset(0, -ui(_textVisualPullUp / 2)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                imageAsset,
                width: ui(imageSize),
                height: ui(imageSize),
                fit: BoxFit.contain,
              ),
              SizedBox(height: ui(4)),
              Transform.translate(
                offset: Offset(0, -ui(_textVisualPullUp)),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PingFang SC',
                    fontSize: ui(14),
                    fontWeight: AppFont.w400,
                    color: const Color(0xFF0B081A),
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
