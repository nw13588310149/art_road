/// 手机号脱敏：11 位号码显示为「138****0001」，其他长度只保留首尾。
String maskMobile(String raw) {
  final value = raw.trim();
  if (value.length == 11) {
    return '${value.substring(0, 3)}****${value.substring(7)}';
  }
  if (value.length > 4) {
    return '${value.substring(0, 2)}****${value.substring(value.length - 2)}';
  }
  return value;
}

/// 日期统一为 YYYY-MM-DD；无法解析时原样返回去掉时间的部分。
String formatProfileDate(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) {
    return '';
  }
  final parsed = DateTime.tryParse(text);
  if (parsed == null) {
    return text.split(' ').first;
  }
  String two(int v) => v.toString().padLeft(2, '0');
  return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)}';
}

/// 身份标签：按接口 role 映射，未知 role 返回 null。
String? identityLabelOf(Object? role) {
  switch (role?.toString().trim().toLowerCase()) {
    case 'tourist':
      return '游客';
    case 'student':
      return '学生';
    case 'teacher':
      return '老师';
    default:
      return null;
  }
}
