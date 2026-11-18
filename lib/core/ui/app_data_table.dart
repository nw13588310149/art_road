import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_rule.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// [AppDataTable] 的一列。
class AppTableColumn {
  const AppTableColumn(
    this.label, {
    this.flex = 1,
    this.width,
    this.numeric = false,
  });

  final String label;

  /// 按比例分宽；给了 [width] 时用固定宽度。
  final int flex;
  final double? width;

  /// 数字列：右对齐，用数字字体。
  final bool numeric;
}

/// [AppDataTable] 的一行。单元格是字符串或组件。
class AppTableRow {
  const AppTableRow(this.cells, {this.onTap, this.emphasis = false});

  final List<Object> cells;

  /// 整行可点（打开详情）时给出；行尾会多一个浅灰箭头。
  final VoidCallback? onTap;

  /// 需要读者先看的一行（本人、当前考试）：文字加粗。不换底色。
  final bool emphasis;
}

/// 新页面的表格：没有外框和底色，表头是一行 12 号的三级文字，行与行之间一条细线。
///
/// 成绩表、科目表、名单都用它。数字列右对齐、用数字字体，同一列的数字对齐。
/// 行高不小于 48；整行可点的表格每行末尾一个浅灰箭头。
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    required this.columns,
    required this.rows,
    this.semanticLabel,
    super.key,
  });

  final List<AppTableColumn> columns;
  final List<AppTableRow> rows;

  /// 读屏时整张表的名称。
  final String? semanticLabel;

  static const double headerHeight = 36;
  static const double rowHeight = 48;

  @override
  Widget build(BuildContext context) {
    final tappable = rows.any((row) => row.onTap != null);
    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: headerHeight,
          child: _line([
            for (final column in columns)
              Text(
                column.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: column.numeric ? TextAlign.right : TextAlign.left,
                style: AppText.caption12,
              ),
          ], trailing: tappable ? const SizedBox(width: 24) : null),
        ),
        const AppRule(),
        for (final row in rows) ...[_row(row, tappable), const AppRule()],
      ],
    );
    final label = semanticLabel;
    return label == null
        ? table
        : Semantics(container: true, label: label, child: table);
  }

  Widget _row(AppTableRow row, bool tappable) {
    final cells = <Widget>[
      for (final (index, column) in columns.indexed)
        _cell(index < row.cells.length ? row.cells[index] : '', column, row),
    ];
    final line = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: rowHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        child: _line(
          cells,
          trailing: tappable
              ? SizedBox(
                  width: 24,
                  child: row.onTap == null
                      ? null
                      : const Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.textPlaceholder,
                          ),
                        ),
                )
              : null,
        ),
      ),
    );
    final onTap = row.onTap;
    return onTap == null ? line : AppPressable(onTap: onTap, child: line);
  }

  Widget _cell(Object value, AppTableColumn column, AppTableRow row) {
    if (value is Widget) {
      return Align(
        alignment: column.numeric
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: value,
      );
    }
    final text = '$value';
    final style = column.numeric
        ? AppText.number(size: 14)
        : (row.emphasis ? AppText.body14Strong : AppText.body14);
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: column.numeric ? TextAlign.right : TextAlign.left,
      // 数字字体只打包了一种字重，强调行的数字靠同一行加粗的名称带出来。
      style: style,
    );
  }

  Widget _line(List<Widget> cells, {Widget? trailing}) {
    return Row(
      children: [
        for (final (index, column) in columns.indexed) ...[
          if (index > 0) const SizedBox(width: AppSpace.s16),
          if (column.width != null)
            SizedBox(width: column.width, child: cells[index])
          else
            Expanded(flex: column.flex, child: cells[index]),
        ],
        ?trailing,
      ],
    );
  }
}
