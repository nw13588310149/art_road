import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_clock.dart';

void main() {
  test('daytime keeps the real time', () {
    final real = DateTime(2026, 11, 7, 10, 15);
    expect(DemoClock.now(real), real);
  });

  test('early morning falls back to the previous evening', () {
    expect(DemoClock.now(DateTime(2026, 11, 7, 6, 0)), DateTime(2026, 11, 6, 21, 30));
  });

  test('late night is capped at 21:30 the same day', () {
    expect(DemoClock.now(DateTime(2026, 11, 7, 23, 40)), DateTime(2026, 11, 7, 21, 30));
  });

  test('never returns a time after the real clock', () {
    for (var h = 0; h < 24; h++) {
      final real = DateTime(2026, 11, 7, h, 5);
      expect(DemoClock.now(real).isAfter(real), isFalse, reason: 'hour $h');
    }
  });

  test('ago skips the night and stays in daytime', () {
    final real = DateTime(2026, 11, 7, 9, 0);
    final t = DemoClock.ago(const Duration(hours: 2), real);
    expect(t.isBefore(real), isTrue);
    final minutes = t.hour * 60 + t.minute;
    expect(minutes >= 8 * 60 + 30 && minutes <= 21 * 60 + 30, isTrue, reason: '$t');
  });
}
