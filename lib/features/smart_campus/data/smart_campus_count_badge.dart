/// 智慧校园数字角标文案：10 以内显示数字，大于 10 显示 9+；0 不展示。
String? smartCampusCountBadgeLabel(int count) {
  if (count <= 0) return null;
  if (count > 10) return '9+';
  return '$count';
}
