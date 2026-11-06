import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';

/// 智慧校园双列列表网格：按行排列，适配纵向可滚动的页面内容区。
class SmartCampusEqualHeightGrid extends StatelessWidget {
  const SmartCampusEqualHeightGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.columns = 2,
    this.compactBreakpoint = 720,
    this.spacing = 10,
    this.runSpacing,
  });

  final int itemCount;
  final int columns;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// 视口宽度小于 [ui(compactBreakpoint)] 时降为 1 列；为 null 时不降列。
  final double? compactBreakpoint;

  /// 设计稿基准间距（会通过 [DashboardScaleScope.ui] 缩放）。
  final double spacing;
  final double? runSpacing;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (itemCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        var cols = columns;
        if (compactBreakpoint != null &&
            constraints.maxWidth < ui(compactBreakpoint!)) {
          cols = 1;
        }

        final gap = ui(spacing);
        final rowGap = ui(runSpacing ?? spacing);

        final rows = <List<int>>[];
        for (var i = 0; i < itemCount; i += cols) {
          rows.add([
            for (var j = i; j < i + cols && j < itemCount; j++) j,
          ]);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) SizedBox(height: rowGap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < cols; c++) ...[
                      if (c > 0) SizedBox(width: gap),
                      Expanded(
                        child: c < rows[r].length
                            ? itemBuilder(context, rows[r][c])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
