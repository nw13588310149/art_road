import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/ui/app_colors.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/popup_selector_field.dart';
import '../../../shell/ui/shell_layout.dart';

/// 原版筛选下拉：默认 220×44，白底、圆角 12、`#F3F2F3` 描边、14 号字。
///
/// 对应 R `admin_teacher_management_view.dart` 753–838（`_ClassFilterField`）；
/// 名册 120、通知 160 等变宽通过 [width] 传入。
class SmartCampusFilterDropdown<T> extends StatefulWidget {
  const SmartCampusFilterDropdown({
    required this.items,
    required this.value,
    required this.itemLabel,
    required this.onChanged,
    this.width = 220,
    this.popupWidth = 280,
    super.key,
  });

  final List<T> items;
  final T value;
  final String Function(T item) itemLabel;
  final ValueChanged<T> onChanged;
  final double width;
  final double popupWidth;

  @override
  State<SmartCampusFilterDropdown<T>> createState() =>
      _SmartCampusFilterDropdownState<T>();
}

class _SmartCampusFilterDropdownState<T>
    extends State<SmartCampusFilterDropdown<T>> {
  final _fieldKey = GlobalKey();
  bool _open = false;

  Future<void> _openMenu() async {
    final fieldCtx = _fieldKey.currentContext;
    if (fieldCtx == null) return;
    setState(() => _open = true);
    final selected = await showAppPopupSelector<T>(
      anchorContext: fieldCtx,
      items: widget.items,
      value: widget.value,
      itemLabel: widget.itemLabel,
      width: DashboardScaleScope.of(fieldCtx).ui(widget.popupWidth),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null) widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      key: _fieldKey,
      onTap: _openMenu,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: ui(widget.width),
        height: ui(44),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.itemLabel(widget.value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  height: 1.2,
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: ui(22),
                color: const Color(0xFFC6C6C6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 原版筛选搜索框：324×44，白底、圆角 12、16 放大镜 + 14 号输入。
///
/// 对应 R `admin_teacher_management_view.dart` 879–923。
class SmartCampusFilterSearchField extends StatelessWidget {
  const SmartCampusFilterSearchField({
    required this.hintText,
    required this.onChanged,
    this.controller,
    this.width = 324,
    super.key,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final double width;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(width),
      height: ui(44),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
      ),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      child: Row(
        children: [
          AppAssetGraphic(
            AppAssets.shellV2Search,
            width: ui(16),
            height: ui(16),
            fit: BoxFit.contain,
          ),
          SizedBox(width: ui(10)),
          Expanded(
            child: AppTextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: AppColors.brand,
              cursorWidth: 1.5,
              cursorHeight: ui(16),
              style: TextStyle(
                fontSize: ui(14),
                height: 1.2,
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: ui(14),
                  color: const Color(0xFFD1D1D1),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 原版筛选行：左 [leading]（状态页签等）或 [dropdown]；右为下拉+搜索。
///
/// - 教师管理：无 leading，左 220 下拉、右 324 搜索（中间 Spacer）。
/// - 学生管理：左黑底页签，右下拉+搜索（间距 12）。
///
/// 对应 R `admin_teacher_management_view.dart` 867–925、
/// `admin_student_management_view.dart` 924–1000。
/// [useWrap] 为窄横屏修复：页签与右侧筛选项可折行，不挡内容。
class SmartCampusFilterRow extends StatelessWidget {
  const SmartCampusFilterRow({
    required this.search,
    this.leading,
    this.dropdown,
    this.useWrap = false,
    super.key,
  }) : assert(leading != null || dropdown != null);

  final Widget search;

  /// 左侧附加（如 [SmartCampusDarkTabs]）。有值时 [dropdown] 挪到右侧与搜索并排。
  final Widget? leading;

  final Widget? dropdown;

  /// 窄横屏时改为 Wrap，避免遮挡。
  final bool useWrap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final drop = dropdown;
    final lead = leading;

    // Wrap 不会自己撑满一行，宽度不撑满时 spaceBetween 不生效、搜索框会贴着左边排；
    // 撑满后一行放得下就和原版一样左右分开，放不下才折行。
    Widget wrapped(List<Widget> children) => SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: ui(12),
        runSpacing: ui(12),
        children: children,
      ),
    );

    if (lead == null) {
      // 教师管理：左下拉 + Spacer + 右搜索
      assert(drop != null);
      if (useWrap) return wrapped([drop!, search]);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [drop!, const Spacer(), search],
      );
    }

    final right = drop == null
        ? search
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              drop,
              SizedBox(width: ui(12)),
              search,
            ],
          );
    if (useWrap) return wrapped([lead, right]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [lead, const Spacer(), right],
    );
  }
}
