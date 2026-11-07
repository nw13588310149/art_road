import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/shell/ui/shell_layout.dart';
import '../constants/app_assets.dart';
import '../ui/app_button.dart';
import '../ui/app_colors.dart';
import '../ui/app_dialog.dart';
import '../ui/app_pressable.dart';
import '../ui/app_shadows.dart';
import '../ui/app_spacing.dart';
import '../ui/app_text.dart';
import 'app_text_field.dart';
import 'popup_selector_field.dart';

// 旧弹窗入口：新代码请用 `core/ui` 的 showAppDialog / showAppConfirm / AppDialog。
// 这里保留原有函数与参数，外观已统一为组件库样式（白底、圆角 12、标题 20、
// AppButton 按钮、scrim 遮罩），不再绘制渐变、装饰图和按钮投影。

/// 与 [showScaledDialog] 弹窗一致的入场时长（不超过组件库浮层的 200ms）。
const Duration kAppDialogTransitionDuration = Duration(milliseconds: 150);

/// 统一居中弹窗过渡：渐显 + [Curves.easeOut]。
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

/// 全局弹窗入口：打开前从 [context] 读取 [DashboardScaleScope]，
/// 再把同一份 [DashboardScaleData] 注入弹窗子树。
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
    barrierColor: barrierColor ?? AppColors.scrim,
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
const double kNoticeDetailDialogContentShiftUp = 16;

/// 通知详情弹窗：标题位置不变，正文上移 [kNoticeDetailDialogContentShiftUp]。
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
        AppSpace.s24,
        kAppDialogTitlePaddingTop,
        AppSpace.s24,
        AppSpace.s24,
      ),
      child: child,
    );
  }
}

/// 通知详情弹窗：复用 [showScaledDialog]。
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
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    builder: builder,
  );
}

/// 弹窗标题字号（与组件库 AppText.title20 一致）。
const double kAppDialogTitleFontSize = 20;
const Color kAppDialogTitleColor = AppColors.ink;
const double kAppDialogTitlePaddingTop = 24;

/// 输入弹窗首个输入框顶边距容器顶部的设计基准。
const double kAppDialogFirstInputTop = 76;

/// 标题下方到 [GradientHeaderDialog.child] 顶部的间距，使首个输入框顶边落在
/// [kAppDialogFirstInputTop]。
double appDialogGapBeforeFirstInput({
  required double topInset,
  double titleFontSize = kAppDialogTitleFontSize,
}) {
  return (kAppDialogFirstInputTop - topInset - 28).clamp(0.0, double.infinity);
}

/// 弹窗标题样式（AppText.title20）。
TextStyle appDialogTitleTextStyle(
  double Function(num) ui, {
  double fontSize = kAppDialogTitleFontSize,
}) {
  return AppText.title20;
}

/// 「标题 + 自定义内容 + 底部按钮」弹窗容器（旧名保留）。
///
/// 外观与组件库 AppDialog 一致：白底、圆角 12、浮层阴影、左对齐 20 号标题。
/// [headerAsset]、[headerHeight]、[gradientMidStop]、[titleFontSize] 为旧参数，
/// 不再生效（不画渐变与装饰图，标题固定 20 号）。
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
    this.actionBarSpacing = 24,
  });

  final String title;
  final Widget child;

  /// 底部按钮区，推荐 [AppDialogActionBar]；null 时没有按钮。
  final Widget? actionBar;
  final double width;
  final double titleFontSize;
  final double titlePaddingTop;
  final EdgeInsets? contentPadding;
  final double? gapBeforeChild;
  final String? headerAsset;
  final double? headerHeight;
  final double gradientMidStop;
  final double actionBarSpacing;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final resolvedPadding =
        contentPadding ??
        EdgeInsets.fromLTRB(
          ui(AppSpace.s24),
          ui(titlePaddingTop),
          ui(AppSpace.s24),
          ui(AppSpace.s24),
        );
    final topInset = contentPadding?.top ?? titlePaddingTop;
    final gap =
        gapBeforeChild ??
        appDialogGapBeforeFirstInput(topInset: topInset);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: ui(32), vertical: ui(24)),
      child: Container(
        width: ui(width),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br12,
          boxShadow: AppShadow.overlay,
        ),
        child: Padding(
          padding: resolvedPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.title20),
              SizedBox(height: ui(gap)),
              Flexible(child: SingleChildScrollView(child: child)),
              if (actionBar != null) ...[
                SizedBox(height: ui(actionBarSpacing)),
                actionBar!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部「取消 / 确认」按钮组：AppButton(secondary) + AppButton(primary)，平分宽度。
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
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: cancelLabel,
            variant: AppButtonVariant.secondary,
            expand: true,
            onTap: onCancel,
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: AppButton(
            label: confirmLabel,
            expand: true,
            onTap: confirmEnabled ? onConfirm : null,
          ),
        ),
      ],
    );
  }
}

/// 弹窗内的文本输入框：白底、1px 描边、圆角 8，聚焦描边转品牌紫。
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
    final textStyle = AppText.body14.copyWith(color: AppColors.ink);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: AppRadius.br8,
      borderSide: BorderSide(color: color),
    );
    return SizedBox(
      height: multiline ? ui(multilineHeight) : ui(AppSize.buttonMd),
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
        textInputAction: multiline
            ? TextInputAction.newline
            : TextInputAction.done,
        onSubmitted: onSubmitted,
        textAlignVertical: multiline
            ? TextAlignVertical.top
            : TextAlignVertical.center,
        cursorColor: AppColors.brand,
        cursorWidth: 1.5,
        cursorHeight: 16,
        style: textStyle,
        decoration: InputDecoration(
          hintText: hintText,
          counterText: '',
          hintStyle: textStyle.copyWith(color: AppColors.textPlaceholder),
          contentPadding: EdgeInsets.symmetric(
            horizontal: ui(AppSpace.s12),
            vertical: ui(AppSpace.s12),
          ),
          filled: true,
          fillColor: AppColors.surface,
          enabledBorder: border(AppColors.line),
          focusedBorder: border(AppColors.brand),
          border: border(AppColors.line),
        ),
      ),
    );
  }
}

/// 弹出一个文本输入对话框，返回用户输入（trim 后）；点击取消返回 null。
///
/// 默认单行；[multiline] 为 true 时使用多行输入，适合个人简介等场景。
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

  /// 多行输入（换行、多行滚动）。
  bool multiline = false,

  /// 多行模式下输入框高度（逻辑像素）。
  double multilineHeight = 152,
}) async {
  final controller = TextEditingController(text: initialValue);
  final focusNode = FocusNode();
  final result = await showScaledDialog<String>(
    context: context,
    builder: (dialogContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (focusNode.canRequestFocus && !focusNode.hasFocus) {
          focusNode.requestFocus();
        }
      });
      final note = subtitle?.trim();
      return GradientHeaderDialog(
        title: title,
        gapBeforeChild: AppSpace.s16,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (note != null && note.isNotEmpty) ...[
              Text(note, style: AppText.body13),
              const SizedBox(height: AppSpace.s8),
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
        ),
      );
    },
  );
  focusNode.dispose();
  controller.dispose();
  return result;
}

/// 单选弹窗（性别 / 省份 / 身份等）：点击选项即关闭并返回所选项；取消返回 null。
Future<String?> showOptionsDialog({
  required BuildContext context,
  required String title,
  required List<String> options,
  String? selected,
  String cancelLabel = '取消',
}) async {
  return showScaledDialog<String>(
    context: context,
    builder: (dialogContext) {
      final ui = DashboardScaleScope.of(dialogContext).ui;
      return GradientHeaderDialog(
        title: title,
        gapBeforeChild: AppSpace.s12,
        actionBarSpacing: AppSpace.s16,
        actionBar: AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.secondary,
          expand: true,
          onTap: () => Navigator.of(dialogContext).pop(),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: ui(360)),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
            itemBuilder: (context, index) {
              final value = options[index];
              final active = value == selected;
              return AppPressable(
                onTap: () => Navigator.of(dialogContext).pop(value),
                selected: active,
                child: SizedBox(
                  height: 46,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (active
                                  ? AppText.body14Strong
                                  : AppText.body14)
                              .copyWith(
                                color: active
                                    ? AppColors.brand
                                    : AppColors.ink,
                              ),
                        ),
                      ),
                      AppDropdownSelectedMark(size: 18, selected: active),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

/// 单按钮提示弹窗（「暂未开放」「保存成功」等纯告知场景），等同 AppDialog + 一个主按钮。
Future<void> showInfoDialog({
  required BuildContext context,
  required String title,
  String? content,
  String confirmLabel = '知道了',
  bool barrierDismissible = true,
}) async {
  await showAppDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => AppDialog(
      title: title,
      message: content,
      actions: [
        AppButton(
          label: confirmLabel,
          onTap: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

/// 二次确认对话框，返回 `true` 表示点了确认；等同组件库的 showAppConfirm。
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  bool barrierDismissible = true,
}) {
  return showAppConfirm(
    context: context,
    title: title,
    message: content,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    barrierDismissible: barrierDismissible,
  );
}
