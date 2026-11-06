import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/router/app_navigator.dart';
import '../../features/shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

const Color _kPickerPrimary = Color(0xFF8741FF);
const Color _kPickerTitle = Color(0xFF0B081A);
const Color _kPickerMuted = Color(0xFF6D6B75);
const Color _kToolbarBorder = Color(0xFFE6E8EB);

/// iOS 风格底部滚轮选择器（静音 [ListWheelScrollView] + 取消/确定工具栏）。
///
/// 仿 iOS 系统「地区」等 Picker：自底部滑出，中间滚轮切换，点确定返回选中项。
/// 不使用 [CupertinoPicker]：其在 iOS 上会对每个刻度播放
/// `SystemSoundType.tick` + 触觉，快速滚动时听感像滋滋声，且与后台
/// 长音频（musicPlay 等）叠在一起更明显。
/// 通过根 Navigator 的 [showGeneralDialog] 铺满整屏宽度（含侧栏区域），
/// 避免 [showModalBottomSheet] 在宽屏/横屏 dashboard 下只覆盖内容区的问题。
Future<String?> showAppWheelPicker({
  required BuildContext context,
  required String title,
  required List<String> items,
  String? selected,
  String cancelLabel = '取消',
  String confirmLabel = '确定',
}) async {
  if (items.isEmpty) return null;

  final scale = DashboardScaleScope.of(context);
  final initialIndex = _indexForSelected(items, selected);
  final rootContext = rootNavigatorKey.currentContext ?? context;

  return showGeneralDialog<String>(
    context: rootContext,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(rootContext).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return DashboardScaleScope(
        data: scale,
        child: _AppWheelPickerOverlay(
          animation: animation,
          title: title,
          items: items,
          initialIndex: initialIndex,
          cancelLabel: cancelLabel,
          confirmLabel: confirmLabel,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
  );
}

/// 省份 / 所在地区选择：全 APP 统一入口。
Future<String?> showAppProvincePicker({
  required BuildContext context,
  required List<String> provinces,
  String? selected,
}) {
  return showAppWheelPicker(
    context: context,
    title: '选择地区',
    items: provinces,
    selected: selected,
  );
}

int _indexForSelected(List<String> items, String? selected) {
  final trimmed = selected?.trim() ?? '';
  if (trimmed.isEmpty) return 0;
  final index = items.indexOf(trimmed);
  return index >= 0 ? index : 0;
}

class _AppWheelPickerOverlay extends StatelessWidget {
  const _AppWheelPickerOverlay({
    required this.animation,
    required this.title,
    required this.items,
    required this.initialIndex,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final Animation<double> animation;
  final String title;
  final List<String> items;
  final int initialIndex;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: curved,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: _AppWheelPickerSheet(
                title: title,
                items: items,
                initialIndex: initialIndex,
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppWheelPickerSheet extends StatefulWidget {
  const _AppWheelPickerSheet({
    required this.title,
    required this.items,
    required this.initialIndex,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final List<String> items;
  final int initialIndex;
  final String cancelLabel;
  final String confirmLabel;

  @override
  State<_AppWheelPickerSheet> createState() => _AppWheelPickerSheetState();
}

class _AppWheelPickerSheetState extends State<_AppWheelPickerSheet> {
  late int _selectedIndex = widget.initialIndex;
  late final FixedExtentScrollController _scrollController =
      FixedExtentScrollController(initialItem: widget.initialIndex);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncSelectedFromScroll);
  }

  void _syncSelectedFromScroll() {
    final index = _scrollController.selectedItem;
    if (index == _selectedIndex || !mounted) {
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncSelectedFromScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ui(16))),
      child: ColoredBox(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: ui(44),
                padding: EdgeInsets.symmetric(horizontal: ui(8)),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _kToolbarBorder, width: ui(0.5)),
                  ),
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: ui(8)),
                      minimumSize: Size(ui(56), ui(44)),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        widget.cancelLabel,
                        style: TextStyle(
                          fontSize: ui(16),
                          color: _kPickerMuted,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui(16),
                          color: _kPickerTitle,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: ui(8)),
                      minimumSize: Size(ui(56), ui(44)),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(widget.items[_selectedIndex]),
                      child: Text(
                        widget.confirmLabel,
                        style: TextStyle(
                          fontSize: ui(16),
                          color: _kPickerPrimary,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: ui(216),
                width: double.infinity,
                child: _SilentWheelPicker(
                  scrollController: _scrollController,
                  itemExtent: ui(34),
                  itemCount: widget.items.length,
                  selectedIndex: _selectedIndex,
                  itemLabel: (index) => widget.items[index],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 与 [CupertinoPicker] 相同的滚轮透视/放大镜，但不触发 iOS tick 音效。
class _SilentWheelPicker extends StatelessWidget {
  const _SilentWheelPicker({
    required this.scrollController,
    required this.itemExtent,
    required this.itemCount,
    required this.selectedIndex,
    required this.itemLabel,
  });

  final FixedExtentScrollController scrollController;
  final double itemExtent;
  final int itemCount;
  final int selectedIndex;
  final String Function(int index) itemLabel;

  static const double _diameterRatio = 1.07;
  static const double _magnification = 1.08;
  static const double _squeeze = 1.1;
  static const double _overAndUnderCenterOpacity = 0.447;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final overlayHeight = itemExtent * _magnification;

    return Stack(
      children: [
        ListWheelScrollView.useDelegate(
          controller: scrollController,
          physics: const FixedExtentScrollPhysics(),
          itemExtent: itemExtent,
          diameterRatio: _diameterRatio,
          useMagnifier: true,
          magnification: _magnification,
          squeeze: _squeeze,
          overAndUnderCenterOpacity: _overAndUnderCenterOpacity,
          changeReportingBehavior: ChangeReportingBehavior.onScrollEnd,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (context, index) {
              final selected = index == selectedIndex;
              return Center(
                child: Text(
                  itemLabel(index),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(18),
                    color: selected ? _kPickerPrimary : _kPickerTitle,
                    fontFamily: 'PingFang SC',
                    fontWeight: selected ? AppFont.w500 : AppFont.w400,
                    height: 22 / 18,
                  ),
                ),
              );
            },
          ),
        ),
        IgnorePointer(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints.expand(height: overlayHeight),
              child: const CupertinoPickerDefaultSelectionOverlay(),
            ),
          ),
        ),
      ],
    );
  }
}
