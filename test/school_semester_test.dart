import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/utils/school_semester.dart';

void main() {
  test('8 月开秋季学期，跨年 1 月延续，2 月进入春季', () {
    expect(schoolSemesterIndex(DateTime(2026, 7, 31)), 4052);
    expect(schoolSemesterIndex(DateTime(2026, 8, 1)), 4053);
    expect(schoolSemesterIndex(DateTime(2026, 9, 1)), 4053);
    expect(schoolSemesterIndex(DateTime(2027, 1, 31)), 4053);
    expect(schoolSemesterIndex(DateTime(2027, 2, 1)), 4054);
    expect(schoolSemesterIndex(DateTime(2025, 8, 1)), 4051);
  });
}
