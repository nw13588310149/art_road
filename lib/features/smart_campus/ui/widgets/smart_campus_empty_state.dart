// =============================================================================
// 智慧校园「空状态」统一组件
//
// 设计语言（对齐考评 / 作业 / 成绩页现有视觉）：
//   - 主色 #8741FF 紫；标题 #0B081A / 副标题 #B6B5BB；PingFang SC。
//   - 两种主视觉：①插图（404 系列 PNG，如评卷 st.png / 书本 jp.png）；
//     ②柔和渐变圆底 + 紫色图标（无合适插图时的自包含降级）。
//   - 可选副标题与操作按钮（如「重新加载」），按钮为紫色描边胶囊。
//
// 提供两种密度：
//   - 默认（full）：用于整块内容区为空（如「暂无可批改的考试」）。
//   - compact：用于卡片内 / 表格内的轻量留白（如「暂无学生提交」）。
// =============================================================================

import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kEmptyTitle = Color(0xFF0B081A);
const Color _kEmptyHint = Color(0xFFB6B5BB);
const Color _kEmptyPurple = Color(0xFF8741FF);

class SmartCampusEmptyState extends StatelessWidget {
  const SmartCampusEmptyState({
    super.key,
    required this.title,
    this.subtitle = '',
    this.illustration,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.padding,
  });

  /// 主标题（必填），如「暂无可批改的考试」。
  final String title;

  /// 副标题（可选），补充说明或引导。
  final String subtitle;

  /// 插图资源路径（可选）。提供时优先于 [icon]。
  final String? illustration;

  /// 无插图时的降级图标。
  final IconData icon;

  /// 操作按钮文案（可选），如「重新加载」。
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 紧凑模式：用于卡片 / 表格内的小留白。
  final bool compact;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasIllustration = illustration != null && illustration!.isNotEmpty;
    final visualSize = compact ? 56.0 : (hasIllustration ? 160.0 : 72.0);

    final visual = hasIllustration
        ? Image.asset(
            illustration!,
            width: ui(visualSize),
            height: ui(visualSize),
            fit: BoxFit.contain,
          )
        : Container(
            width: ui(visualSize),
            height: ui(visualSize),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF4F0FF), Color(0xFFFBF6FF)],
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: ui(compact ? 26 : 34),
              color: _kEmptyPurple,
            ),
          );

    return Container(
      width: double.infinity,
      padding:
          padding ??
          EdgeInsets.symmetric(vertical: ui(compact ? 24 : 40)),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          visual,
          SizedBox(height: ui(compact ? 10 : 16)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui(compact ? 13 : 15),
              color: _kEmptyTitle,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
              height: 1.3,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            SizedBox(height: ui(6)),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ui(320)),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kEmptyHint,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: ui(16)),
            _EmptyActionButton(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}

class _EmptyActionButton extends StatelessWidget {
  const _EmptyActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(10)),
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(18)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(10)),
          border: Border.all(color: _kEmptyPurple.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: ui(16), color: _kEmptyPurple),
            SizedBox(width: ui(6)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(13),
                color: _kEmptyPurple,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
