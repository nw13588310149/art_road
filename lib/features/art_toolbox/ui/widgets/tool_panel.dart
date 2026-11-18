import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import 'tool_slider.dart';

export 'tool_slider.dart';
export 'tool_stage.dart';
export 'tool_swatches.dart';

/// 工具箱各工具共用的面板控件，按 `docs/新页面设计语言.md` 第八节：面板里的分区
/// 用 `AppSectionTitle` 和留白分开，不包灰底块；选项、开关和滑条的选中态用墨色，
/// 不用品牌紫（品牌紫留给一屏里唯一的主按钮和一处关键数字）。

/// 面板里的一个分区：分区标题（16 号粗体，后面可跟一句 12 号的口径），
/// 标题下 12 是内容，分区之间 24。
class ToolPanelSection extends StatelessWidget {
  const ToolPanelSection({
    required this.title,
    required this.child,
    this.note = '',
    this.bottom = AppSpace.s24,
    super.key,
  });

  final String title;
  final Widget child;
  final String note;

  /// 分区下方的留白；内容以自带下边距的参数行结尾时可以调小。
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSectionTitle(title: title, note: note),
          const SizedBox(height: AppSpace.s12),
          child,
        ],
      ),
    );
  }
}

/// 表单里一项的名称：14 号字，下面 6 是控件（与输入框自带的标题同一写法）。
class ToolField extends StatelessWidget {
  const ToolField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.body14),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// 工具参数的一组选项：等宽排开，放不下时换行（5 个排成 3 + 2）。外观同筛选条
/// `AppFilterBar`：选中的垫一块浅灰胶囊、文字墨色加粗，其余是二级文字；看得见的
/// 胶囊高 36，点击区域高 44。
class ToolSegmented<T> extends StatelessWidget {
  const ToolSegmented({
    required this.values,
    required this.value,
    required this.labelOf,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<T> values;
  final T value;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;
  final bool enabled;

  static const double _gap = AppSpace.s4;
  static const double _minWidth = 56;

  /// 一行放得下几个；放不下时各行尽量排得一样多。
  int _columnsFor(double width) {
    final fit = ((width + _gap) / (_minWidth + _gap)).floor().clamp(
      1,
      values.length,
    );
    final rows = (values.length / fit).ceil();
    return (values.length / rows).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        // 向下取到 0.5，避免浮点误差让一行的末项换行。
        final width =
            ((constraints.maxWidth - (columns - 1) * _gap) / columns * 2)
                .floorToDouble() /
            2;
        return Wrap(
          spacing: _gap,
          children: [
            for (final option in values)
              AppPressable(
                enabled: enabled,
                selected: value == option,
                onTap: () => onChanged(option),
                child: Container(
                  width: width,
                  height: 44,
                  alignment: Alignment.center,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s4,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == option ? AppColors.surfaceSubtle : null,
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      labelOf(option),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: value == option
                          ? AppText.body14Strong
                          : AppText.body14.copyWith(
                              color: AppColors.textSecondary,
                            ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 开关行：名称 + 一句说明 + 开关，整行可点，至少 44 高。
class ToolSwitchRow extends StatelessWidget {
  const ToolSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    super.key,
  });

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: AppPressable(
        onTap: () => onChanged(!value),
        toggled: value,
        semanticLabel: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: AppText.body14),
                    if (hint != null) Text(hint!, style: _noteStyle),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              ExcludeSemantics(
                child: AppSwitch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 参数行下面的一句说明：12 号三级文字。
final TextStyle _noteStyle = AppText.caption12;

/// 靠左放在正文里的一个次要操作：文字和上面的正文对齐（抵消按钮自带的 12 内距）。
class ToolInlineAction extends StatelessWidget {
  const ToolInlineAction({
    required this.label,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Transform.translate(
          offset: const Offset(-AppSpace.s12, 0),
          child: AppPlainButton(label: label, icon: icon, onTap: onTap),
        ),
      ],
    );
  }
}

/// 面板里的补充说明文字。
class ToolNote extends StatelessWidget {
  const ToolNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: _noteStyle);
}

/// 滑块行：名称 + 当前值（墨色数字），下面是滑条。
class ToolSliderRow extends StatelessWidget {
  const ToolSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
    this.divisions,
    this.onChangeEnd,
    this.hint,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String valueLabel;
  final String? hint;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppText.body14)),
              Text(valueLabel, style: AppText.number(size: 14)),
            ],
          ),
          if (hint != null) Text(hint!, style: _noteStyle),
          ToolSlider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            semanticLabel: label,
          ),
        ],
      ),
    );
  }
}

/// 面板末尾的说明：一条细线之后是分区标题和一段正文，不包底色。
class ToolTipCard extends StatelessWidget {
  const ToolTipCard({required this.title, required this.text, super.key});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppRule(),
        const SizedBox(height: AppSpace.s24),
        AppSectionTitle(title: title),
        const SizedBox(height: AppSpace.s8),
        ToolTextBlock(text),
      ],
    );
  }
}

/// 一段说明正文：13 号二级文字。
class ToolTextBlock extends StatelessWidget {
  const ToolTextBlock(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.body13.copyWith(height: 22 / 13));
  }
}

/// 面板里的一块信息（取色结果、测量提示）。不再包底色，只留位置。
class ToolInfoBlock extends StatelessWidget {
  const ToolInfoBlock({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(padding: padding, child: child);
}

/// 一句提示：小图标加文字，不铺底色。成功、出错这类状态用状态色的图标，文字
/// 用墨色；「以考试院公布为准」这类说明用中性色。
class ToolNotice extends StatelessWidget {
  const ToolNotice(this.text, {this.tone = AppTone.warning, super.key});

  final String text;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final status = tone == AppTone.success || tone == AppTone.danger;
    final icon = switch (tone) {
      AppTone.success => Icons.check_circle_rounded,
      AppTone.danger => Icons.error_rounded,
      _ => Icons.info_outline_rounded,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 16,
            color: status ? tone.foreground : AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: AppSpace.s8),
        Expanded(
          child: Text(
            text,
            style: status
                ? AppText.body13.copyWith(color: AppColors.ink)
                : AppText.body13,
          ),
        ),
      ],
    );
  }
}
