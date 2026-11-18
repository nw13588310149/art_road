/// 学情中心入口直达的子视图。`critique` 和 `paper` 一样打开原卷，只是直接进讲评。
enum StudyCenterInitialView {
  report,
  paper,
  critique,
  standard,
  trend,
  artworkGrowth,
}

/// 路由参数：`{'examId': String, 'view': 'report' | 'paper' | 'critique' |
/// 'standard' | 'trend', 'subjectId': String}`，均可省略。
class StudyCenterArgs {
  const StudyCenterArgs({this.examId = '', this.view, this.subjectId = ''});

  final String examId;
  final StudyCenterInitialView? view;

  /// 直达原卷 / 讲评 / 评分标准时定位的科目；为空取第一科（讲评取第一科有讲评的）。
  final String subjectId;

  static StudyCenterArgs parse(Object? raw) {
    if (raw is StudyCenterArgs) return raw;
    if (raw is! Map) return const StudyCenterArgs();
    String read(String key) {
      final text = raw[key]?.toString().trim() ?? '';
      return text == 'null' ? '' : text;
    }

    final view = switch (read('view').toLowerCase()) {
      'report' => StudyCenterInitialView.report,
      'paper' => StudyCenterInitialView.paper,
      'critique' => StudyCenterInitialView.critique,
      'standard' => StudyCenterInitialView.standard,
      'trend' || 'growth' => StudyCenterInitialView.trend,
      'artworkgrowth' => StudyCenterInitialView.artworkGrowth,
      _ => null,
    };
    return StudyCenterArgs(
      examId: read('examId'),
      view: view,
      subjectId: read('subjectId'),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyCenterArgs &&
          examId == other.examId &&
          view == other.view &&
          subjectId == other.subjectId;

  @override
  int get hashCode => Object.hash(examId, view, subjectId);
}
