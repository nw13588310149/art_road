/// 学情中心入口直达的子视图。
enum StudyCenterInitialView { report, paper, standard, trend }

/// 路由参数：`{'examId': String, 'view': 'report' | 'paper' | 'standard' | 'trend',
/// 'subjectId': String}`，均可省略。
class StudyCenterArgs {
  const StudyCenterArgs({this.examId = '', this.view, this.subjectId = ''});

  final String examId;
  final StudyCenterInitialView? view;

  /// 直达原卷 / 评分标准时定位的科目；为空取第一科。
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
      'standard' => StudyCenterInitialView.standard,
      'trend' || 'growth' => StudyCenterInitialView.trend,
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
