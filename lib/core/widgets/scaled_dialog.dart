import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_text_field.dart';
import 'popup_selector_field.dart';
import '../../features/shell/ui/shell_layout.dart';
import '../constants/app_assets.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 与管理员「教师档案」等 [showScaledDialog] 弹窗一致的入场时长（对齐
/// Material [DialogRoute] 默认 150ms）。
const Duration kAppDialogTransitionDuration = Duration(milliseconds: 150);

/// 统一居中弹窗过渡：渐显 + [Curves.easeOut]（与教师档案弹窗一致）。
Widget appDialogTransitionBuilder(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  );
}

/// 全局统一弹窗入口：在打开前先从 [context] 读取 [DashboardScaleScope]，
/// 再把同一份 [DashboardScaleData] 注入弹窗子树，并使用 [appDialogTransitionBuilder]。
///
/// 这样从 Dashboard 内层页面弹出 [GradientHeaderDialog] 等统一弹窗时，
/// `DashboardScaleScope.of(...)` 在 root Overlay 子树中仍可正常工作。
Future<T?> showScaledDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  bool useSafeArea = true,
  RouteSettings? routeSettings,
}) {
  final scale = DashboardScaleScope.of(context);
  final resolvedBarrierLabel = barrierDismissible
      ? (barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel)
      : null;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black54,
    barrierLabel: resolvedBarrierLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    transitionDuration: kAppDialogTransitionDuration,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      Widget child = DashboardScaleScope(
        data: scale,
        child: Builder(builder: builder),
      );
      if (useSafeArea) {
        child = SafeArea(child: child);
      }
      return child;
    },
    transitionBuilder: appDialogTransitionBuilder,
  );
}

/// 通知详情弹窗正文相对默认表单弹窗上移的设计基准（px）。
/// 标题距顶不变，仅缩小标题与正文间距，并等量加大底部内边距以保持容器高度。
const double kNoticeDetailDialogContentShiftUp = 16;

/// 通知详情专用弹窗：标题位置不变，正文上移 [kNoticeDetailDialogContentShiftUp]，
/// 底部留白等量增大以维持弹窗总高度。
class NoticeDetailGradientDialog extends StatelessWidget {
  const NoticeDetailGradientDialog({
    super.key,
    required this.title,
    required this.child,
    this.width = 460,
  });

  final String title;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final defaultGap = appDialogGapBeforeFirstInput(
      topInset: kAppDialogTitlePaddingTop,
    );
    return GradientHeaderDialog(
      title: title,
      width: width,
      gapBeforeChild: defaultGap - kNoticeDetailDialogContentShiftUp,
      contentPadding: const EdgeInsets.fromLTRB(
        20,
        kAppDialogTitlePaddingTop,
        20,
        20 + kNoticeDetailDialogContentShiftUp,
      ),
      child: child,
    );
  }
}

/// 通知详情弹窗：复用 [showScaledDialog] 动画，遮罩略浅（18% 黑）。
Future<T?> showNoticeDetailDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? barrierColor,
  String? barrierLabel,
  bool barrierDismissible = true,
}) {
  return showScaledDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.18),
    barrierLabel: barrierLabel,
    builder: builder,
  );
}

/// 输入弹窗标题的设计基准：对齐首页 [ShellSectionTitleBar]（如「最新」），字号 20。
const double kAppDialogTitleFontSize = 20;
const Color kAppDialogTitleColor = Color(0xFF1A1A1A);
const double kAppDialogTitlePaddingTop = 25;

/// 输入弹窗首个输入框顶边距容器顶部的设计基准。
const double kAppDialogFirstInputTop = 90;

/// 标题下方到 [child] 顶部的间距，使首个输入框顶边落在 [kAppDialogFirstInputTop]。
double appDialogGapBeforeFirstInput({
  required double topInset,
  double titleFontSize = kAppDialogTitleFontSize,
}) {
  return (kAppDialogFirstInputTop - topInset - titleFontSize)
      .clamp(0.0, double.infinity);
}

/// 输入弹窗 / [GradientHeaderDialog] 居中标题样式。
TextStyle appDialogTitleTextStyle(
  double Function(num) ui, {
  double fontSize = kAppDialogTitleFontSize,
}) {
  return TextStyle(
    fontSize: ui(fontSize),
    color: kAppDialogTitleColor,
    fontFamily: 'PingFang SC',
    fontWeight: AppFont.w500,
    height: 1,
  );
}

/// 「渐变顶部装饰 + 居中标题 + 自定义内容 + 底部按钮」对话框容器。
///
/// 提取自 courseware「上传课件」弹窗的视觉系统，复用给所有需要：
///   · 圆角 24 + 顶部 #D2C6FF→white 渐变（stops 0 / 0.21 / 1）
///   · 顶部一张装饰位图（默认 `AppAssets.coursewareUploadHeader`）
///   · 居中标题（20/w500，行高 1，距顶 25；对齐首页「最新」区块标题）
///   · 首个输入框顶边距容器顶部 84（标题区与 [child] 之间自动留白）
///   · 自定义 [child] 表单内容
///   · 可选底部 [actionBar]（推荐传入 [AppDialogActionBar]）
/// 的弹窗。`width` 默认 420（设计基准 428，少 8 用作左右 inset 余量）。
///
/// 用法示例：
/// ```dart
/// showScaledDialog<void>(
///   context: context,
///   builder: (ctx) => GradientHeaderDialog(
///     title: '申请查寝补卡',
///     child: _MyForm(),
///     actionBar: AppDialogActionBar(
///       onCancel: () => Navigator.pop(ctx),
///       onConfirm: () => Navigator.pop(ctx, true),
///     ),
///   ),
/// );
/// ```
class GradientHeaderDialog extends StatelessWidget {
  const GradientHeaderDialog({
    super.key,
    required this.title,
    required this.child,
    this.actionBar,
    this.width = 420,
    this.titleFontSize = kAppDialogTitleFontSize,
    this.titlePaddingTop = kAppDialogTitlePaddingTop,
    this.contentPadding,
    this.gapBeforeChild,
    this.headerAsset = AppAssets.coursewareUploadHeader,
    this.headerHeight,
    this.gradientMidStop = 0.21,
    this.actionBarSpacing = 20,
  });

  /// 标题文字（居中显示）。
  final String title;

  /// 标题与 actionBar 之间的主体内容。
  final Widget child;

  /// 底部按钮区。传入 null 时没有按钮（少数纯展示弹窗用）。
  final Widget? actionBar;

  /// 弹窗整体宽度（design 默认 420）。
  final double width;

  /// 标题字号（默认 [kAppDialogTitleFontSize]）。
  final double titleFontSize;

  /// 标题距弹窗顶部的距离（默认 [kAppDialogTitlePaddingTop]）。
  final double titlePaddingTop;

  /// content 内边距（默认左右 20、底部 20、顶部由 [titlePaddingTop] 决定）。
  final EdgeInsets? contentPadding;

  /// 标题与 [child] 之间的间距；为 null 时按 [appDialogGapBeforeFirstInput] 计算。
  final double? gapBeforeChild;

  /// 顶部装饰位图资源；传 `null` 则不画装饰图。
  final String? headerAsset;

  /// 装饰图高度（默认 fitWidth 自适应）。
  final double? headerHeight;

  /// 渐变中间 stop（默认 0.21；笔记/资料输入弹窗用 0.35）。
  final double gradientMidStop;

  /// 主体内容与底部 [actionBar] 之间的间距（设计基准 px，默认 20）。
  final double actionBarSpacing;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final resolvedPadding =
        contentPadding ??
        EdgeInsets.fromLTRB(
          ui(20),
          ui(titlePaddingTop),
          ui(20),
          ui(20),
        );
    final topInset = contentPadding?.top ?? titlePaddingTop;
    final resolvedGapBeforeChild = gapBeforeChild ??
        appDialogGapBeforeFirstInput(
          topInset: topInset,
          titleFontSize: titleFontSize,
        );
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: ui(32), vertical: ui(24)),
      child: Container(
        width: ui(width),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const <Color>[Color(0xFFD2C6FF), Colors.white, Colors.white],
            stops: <double>[0, gradientMidStop, 1],
          ),
          borderRadius: BorderRadius.circular(ui(24)),
        ),
        child: Stack(
          children: [
            if (headerAsset != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: headerHeight != null
                    ? Image.asset(
                        headerAsset!,
                        height: ui(headerHeight!),
                        fit: BoxFit.cover,
                      )
                    : Image.asset(headerAsset!, fit: BoxFit.fitWidth),
              ),
            Padding(
              padding: resolvedPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      title,
                      style: appDialogTitleTextStyle(
                        ui,
                        fontSize: titleFontSize,
                      ),
                    ),
                  ),
                  SizedBox(height: ui(resolvedGapBeforeChild)),
                  Flexible(child: SingleChildScrollView(child: child)),
                  if (actionBar != null) ...[
                    SizedBox(height: ui(actionBarSpacing)),
                    actionBar!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 通用底部按钮组（取消 / 确认），样式与上传课件弹窗一致：
/// - 取消：白底 + 浅边框 + 阴影
/// - 确认：紫色渐变 + 阴影
class AppDialogActionBar extends StatelessWidget {
  const AppDialogActionBar({
    required this.onCancel,
    required this.onConfirm,
    this.cancelLabel = '取消',
    this.confirmLabel = '确认',
    this.confirmEnabled = true,
    super.key,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String cancelLabel;
  final String confirmLabel;
  final bool confirmEnabled;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        Expanded(
          child: _AppDialogButton(
            label: cancelLabel,
            onTap: onCancel,
            isPrimary: false,
          ),
        ),
        SizedBox(width: ui(16)),
        Expanded(
          child: _AppDialogButton(
            label: confirmLabel,
            onTap: confirmEnabled ? onConfirm : null,
            isPrimary: true,
          ),
        ),
      ],
    );
  }
}

class _AppDialogButton extends StatelessWidget {
  const _AppDialogButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        height: ui(45),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
                )
              : null,
          color: isPrimary ? null : Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? const Color(0x59AD80FF)
                  : const Color(0x59B5B5B5),
              blurRadius: ui(20),
              offset: Offset(0, ui(16)),
            ),
          ],
        ),
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : const Color(0xFF0B081A),
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 12 / 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 渐变标题弹窗内统一的文本输入框（与「新建笔记」标题弹窗一致）。
class AppDialogTextField extends StatelessWidget {
  const AppDialogTextField({
    super.key,
    required this.controller,
    this.hintText = '',
    this.focusNode,
    this.autofocus = false,
    this.maxLength,
    this.multiline = false,
    this.multilineHeight = 152,
    this.obscureText = false,
    this.inputFormatters,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final bool autofocus;
  final int? maxLength;
  final bool multiline;
  final double multilineHeight;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: multiline ? ui(multilineHeight) : ui(48),
      child: AppTextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        maxLength: maxLength,
        expands: multiline,
        maxLines: multiline ? null : 1,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
        textInputAction: multiline ? TextInputAction.newline : TextInputAction.done,
        onSubmitted: onSubmitted,
        textAlignVertical:
            multiline ? TextAlignVertical.top : TextAlignVertical.center,
        cursorColor: const Color(0xFF8741FF),
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        style: TextStyle(
          fontSize: ui(14),
          color: const Color(0xFF0B081A),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 20 / 14,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          counterText: '',
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: const Color(0xFFB6B5BB),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 20 / 14,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: ui(16),
            vertical: ui(14),
          ),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(8)),
            borderSide: BorderSide(
              color: const Color(0xFFF5F6FA),
              width: ui(1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(8)),
            borderSide: BorderSide(
              color: const Color(0xFFD9C7FF),
              width: ui(1),
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹出一个文本输入对话框，返回用户输入（trim 后非空）；点击取消返回 null。
///
/// 默认单行；[multiline] 为 true 时使用多行输入（类似 HTML `textarea`），
/// 适合个人简介等场景。
///
/// 样式与「我的笔记 → 新建笔记」标题弹窗保持一致：
/// - 420 宽，圆角 24，顶部 #D2C6FF→white 渐变 + 装饰图
/// - 居中标题 20/w500，行高 1，距顶 25（对齐首页「最新」）
/// - 首个输入框顶边距容器顶部 84
/// - 输入框 48 高，圆角 8，1px `#F5F6FA` 描边
/// - 底部按钮使用 [AppDialogActionBar]
Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  String hintText = '',
  /// 标题与输入框之间的小字说明（如资料填写提示）。
  String? subtitle,
  String initialValue = '',
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  int? maxLength,
  /// 多行输入（换行、多行滚动），类似 textarea。
  bool multiline = false,
  /// 多行模式下输入框高度（逻辑像素，经 [DashboardScaleScope] 缩放）。
  double multilineHeight = 152,
}) async {
  final controller = TextEditingController(text: initialValue);
  final focusNode = FocusNode();
  final result = await showScaledDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (focusNode.canRequestFocus && !focusNode.hasFocus) {
          focusNode.requestFocus();
        }
      });
      return GradientHeaderDialog(
        title: title,
        headerHeight: 169,
        gradientMidStop: 0.35,
        actionBar: AppDialogActionBar(
          cancelLabel: cancelLabel,
          confirmLabel: confirmLabel,
          onCancel: () =>
              Navigator.of(dialogContext, rootNavigator: true).pop(),
          onConfirm: () => Navigator.of(
            dialogContext,
            rootNavigator: true,
          ).pop(controller.text.trim()),
        ),
        child: Builder(
          builder: (fieldContext) {
            final ui = DashboardScaleScope.of(fieldContext).ui;
            final resolvedSubtitle = subtitle?.trim();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (resolvedSubtitle != null && resolvedSubtitle.isNotEmpty) ...[
                  Text(
                    resolvedSubtitle,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: const Color(0xFF6D6B75),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 18 / 12,
                    ),
                  ),
                  SizedBox(height: ui(8)),
                ],
                AppDialogTextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  hintText: hintText,
                  maxLength: maxLength,
                  multiline: multiline,
                  multilineHeight: multilineHeight,
                  onSubmitted: multiline
                      ? null
                      : (_) => Navigator.of(
                          dialogContext,
                          rootNavigator: true,
                        ).pop(controller.text.trim()),
                ),
              ],
            );
          },
        ),
      );
    },
  );
  focusNode.dispose();
  controller.dispose();
  return result;
}

/// 单选弹窗（性别 / 省份 / 身份等）：列表中点击即关闭并返回所选项；
/// 取消按钮返回 null。样式与上传课件 / 修改资料弹窗保持一致。
Future<String?> showOptionsDialog({
  required BuildContext context,
  required String title,
  required List<String> options,
  String? selected,
  String cancelLabel = '取消',
}) async {
  return showScaledDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ui(32),
          vertical: ui(24),
        ),
        child: Container(
          width: ui(420),
          padding: EdgeInsets.fromLTRB(ui(24), ui(28), ui(24), ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                ),
              ),
              SizedBox(height: ui(16)),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: ui(360)),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF3F2F3),
                  ),
                  itemBuilder: (context, index) {
                    final value = options[index];
                    final isActive = value == selected;
                    return InkWell(
                      onTap: () => Navigator.of(dialogContext).pop(value),
                      child: Container(
                        height: ui(46),
                        padding: EdgeInsets.symmetric(horizontal: ui(8)),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ui(14),
                                  color: isActive
                                      ? const Color(0xFF8741FF)
                                      : const Color(0xFF0B081A),
                                  fontFamily: 'PingFang SC',
                                  fontWeight: isActive
                                      ? AppFont.w600
                                      : AppFont.w400,
                                ),
                              ),
                            ),
                            AppDropdownSelectedMark(
                              size: ui(18),
                              selected: isActive,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: ui(16)),
              Center(
                child: SizedBox(
                  width: ui(180),
                  child: _AppDialogButton(
                    label: cancelLabel,
                    onTap: () => Navigator.of(dialogContext).pop(),
                    isPrimary: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 单按钮提示弹窗（"暂未开放" / "保存成功" 等纯告知场景）。
/// 样式与 [showConfirmDialog] / [showTextInputDialog] 完全一致：
/// - 圆角 24，白底，宽 420
/// - 18/600 标题 + 14/400 说明文（可选）
/// - 居中单个紫色渐变确认按钮（默认 "知道了"）
Future<void> showInfoDialog({
  required BuildContext context,
  required String title,
  String? content,
  String confirmLabel = '知道了',
  bool barrierDismissible = true,
}) async {
  await showScaledDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ui(32),
          vertical: ui(24),
        ),
        child: Container(
          width: ui(420),
          padding: EdgeInsets.fromLTRB(ui(24), ui(28), ui(24), ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                ),
              ),
              if (content != null && content.isNotEmpty) ...[
                SizedBox(height: ui(12)),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui(14),
                    height: 1.6,
                    color: const Color(0xFF788698),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                  ),
                ),
              ],
              SizedBox(height: ui(24)),
              Center(
                child: SizedBox(
                  width: ui(180),
                  child: _AppDialogButton(
                    label: confirmLabel,
                    onTap: () => Navigator.of(dialogContext).pop(),
                    isPrimary: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 弹出一个二次确认对话框（带说明文本），返回 `true` 表示用户点击确认。
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  bool barrierDismissible = true,
}) async {
  final result = await showScaledDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: ui(32),
          vertical: ui(24),
        ),
        child: Container(
          width: ui(420),
          padding: EdgeInsets.fromLTRB(ui(24), ui(28), ui(24), ui(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: ui(18),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                ),
              ),
              SizedBox(height: ui(12)),
              Text(
                content,
                style: TextStyle(
                  fontSize: ui(14),
                  height: 1.6,
                  color: const Color(0xFF788698),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                ),
              ),
              SizedBox(height: ui(24)),
              AppDialogActionBar(
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
                onCancel: () => Navigator.of(dialogContext).pop(false),
                onConfirm: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
