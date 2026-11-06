import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/core/network/snowflake_id.dart';

void main() {
  test('encodes selected int64 ids as numeric JSON literals', () {
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{
        'examId': '2065017767469707300',
        'subjectId': 3,
        'studentIds': ['1795667363756507137', '1795667363756507138'],
        'comment': '稳定',
      },
      numericIdKeys: const {'examId'},
      numericIdArrayKeys: const {'studentIds'},
    );

    expect(
      body,
      '{"examId":2065017767469707300,"subjectId":3,'
      '"studentIds":[1795667363756507137,1795667363756507138],'
      '"comment":"稳定"}',
    );
  });

  test('encodes class mutation ids as quoted JSON strings', () {
    const classId = '1798658711795392514';
    const classroomId = '2066711506812092417';
    const studentId = '1795667363756507137';
    final body = encodeClassMutationRequestBody(
      <String, dynamic>{
        'id': classId,
        'classroomId': classroomId,
        'headTeacherId': '1788178798952914945',
        'campusId': 0,
        'studentIds': [studentId],
        'name': '一班',
      },
    );

    expect(body, isNotNull);
    expect(body!, contains('"id":"$classId"'));
    expect(body, contains('"classroomId":"$classroomId"'));
    expect(body, contains('"studentIds":["$studentId"]'));
    expect(body, isNot(contains('2066711506812092400')));
    expect(body, isNot(contains('"id":$classId')));
  });

  test('preserves 19-digit schoolId digits in numeric JSON literal', () {
    const schoolId = '2066563244679475201';
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{
        'schoolId': schoolId,
        'content': 'test',
      },
      numericIdKeys: const {'schoolId'},
    );

    expect(body, isNotNull);
    expect(body!, contains('"schoolId":$schoolId'));
    expect(body, isNot(contains('2066563244679475200')));
  });

  test('rejects invalid numeric id fields', () {
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{'examId': 'not-an-id'},
      numericIdKeys: const {'examId'},
    );

    expect(body, isNull);
  });
}
