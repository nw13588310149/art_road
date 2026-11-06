import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/features/school/data/school_config_data.dart';

void main() {
  test('parses flat map evening and morning deadlines', () {
    final config = parseSchoolDormitoryCheckConfig({
      'nightCheckTime': '22:30',
      'morningCheckTime': '07:20',
    });

    expect(config.eveningDeadline, '22:30前');
    expect(config.morningDeadline, '07:20前');
  });

  test('parses configKey/configValue list entries', () {
    final config = parseSchoolDormitoryCheckConfig([
      {'configKey': 'dormitoryNightCheckTime', 'configValue': '21:20'},
      {'configKey': 'dormitoryMorningCheckTime', 'configValue': '07:10前'},
    ]);

    expect(config.eveningDeadline, '21:20前');
    expect(config.morningDeadline, '07:10前');
  });

  test('resolveDormitoryRequiredDeadline prefers record value', () {
    const config = SchoolDormitoryCheckConfig(
      eveningDeadline: '22:30前',
      morningDeadline: '07:20前',
    );

    expect(
      resolveDormitoryRequiredDeadline(
        recordDeadline: '23:00前',
        checkType: '晚查寝',
        config: config,
      ),
      '23:00前',
    );
    expect(
      resolveDormitoryRequiredDeadline(
        recordDeadline: '',
        checkType: '晨查寝',
        config: config,
      ),
      '07:20前',
    );
    expect(
      resolveDormitoryRequiredDeadline(
        recordDeadline: '--',
        checkType: '晚查寝',
        config: config,
      ),
      '22:30前',
    );
  });
}
