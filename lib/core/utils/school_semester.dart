/// 8 月至次年 1 月为秋季学期，2 月至 7 月为春季学期。
/// 连续序号便于取上一学期，规则与服务端 termOf 一致。
int schoolSemesterIndex(DateTime date) {
  if (date.month >= 8) return date.year * 2 + 1;
  if (date.month == 1) return (date.year - 1) * 2 + 1;
  return date.year * 2;
}
