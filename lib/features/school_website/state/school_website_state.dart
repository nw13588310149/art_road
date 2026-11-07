class SchoolWebsiteState {
  const SchoolWebsiteState({
    this.loading = true,
    this.htmlContent = '',
    this.errorMessage = '',
    this.title = '',
  });

  final bool loading;
  final String htmlContent;
  final String errorMessage;

  /// 接口返回的官网名称（如「示范画室官网」），为空时页面用默认标题。
  final String title;

  SchoolWebsiteState copyWith({
    bool? loading,
    String? htmlContent,
    String? errorMessage,
    String? title,
  }) {
    return SchoolWebsiteState(
      loading: loading ?? this.loading,
      htmlContent: htmlContent ?? this.htmlContent,
      errorMessage: errorMessage ?? this.errorMessage,
      title: title ?? this.title,
    );
  }
}

/// 从 `/app/school/v2/user/homePage` 的 `data` 字段解析 HTML 正文。
String? parseSchoolHomePageHtml(dynamic data) {
  if (data == null) return null;
  if (data is String) {
    final text = data.trim();
    return text.isEmpty ? null : text;
  }
  if (data is Map) {
    const keys = <String>[
      'html',
      'content',
      'homePage',
      'pageContent',
      'htmlContent',
      'body',
    ];
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
  }
  return null;
}
