import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/features/smart_campus/data/principal_inbox_data.dart';

void main() {
  test('counts pending from headmaster list array data', () {
    const response = {
      'code': 0,
      'msg': 'ok',
      'data': [
        {
          'id': '28',
          'schoolId': '2066563244679475201',
          'userId': '2066705433485066242',
          'msgType': '建议',
          'isAnonymous': 1,
          'content': '2212',
          'attachments': '',
          'status': 0,
          'createTime': '2026-06-29 23:33:12',
        },
      ],
    };

    expect(parsePrincipalInboxPendingCount(response), 1);
    expect(parsePrincipalInboxList(response), hasLength(1));
    expect(parsePrincipalInboxList(response).first.msgType, '建议');
  });

  test('parses non-anonymous submitter from nested user object', () {
    const response = {
      'data': [
        {
          'id': '29',
          'msgType': '举报',
          'isAnonymous': 0,
          'content': '测试',
          'status': 0,
          'createTime': '2026-07-02 23:25:29',
          'user': {
            'id': '2067581104570699778',
            'headUrl':
                'app/upload/2067581104570699778/2026-07-02/2072697923631542274.jpeg',
            'nickname': '季栋',
            'realname': null,
          },
        },
      ],
    };

    final item = parsePrincipalInboxList(response).first;
    expect(item.isAnonymous, isFalse);
    expect(item.submitterName, '季栋');
    expect(item.submitterLabel, '季栋');
    expect(item.submitterHeadUrl, isNotEmpty);
    expect(item.submitterHeadUrl, contains('2072697923631542274.jpeg'));
  });
}
