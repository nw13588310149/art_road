import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_config.dart';
import 'package:the_road_of_art_flutter/core/network/api_client.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/artwork_upload_dialog.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/student_my_homework_view.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/teacher_homework_review_view.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/teacher_home_school_view.dart';

// All clients are replaced: this suite must never depend on an external server.
class _OfflineClient implements ApiClient {
  final calls = <String>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final path = invocation.positionalArguments.first.toString();
    calls.add(path);
    dynamic data = <String, dynamic>{};
    if (path.endsWith('studentHomeworkList')) {
      data = {
        'records': [
          {
            'id': '901',
            'homeworkStudentId': '901',
            'title': '静物练习',
            'subjectName': '素描',
            'status': 0,
            'endTime': '2099-12-31 18:00:00',
          },
        ],
        'total': 1,
      };
    } else if (path.endsWith('chatConversationList')) {
      data = {
        'records': [
          {
            'id': '81',
            'studentId': '82',
            'studentName': '测试学生',
            'parentName': '测试家长',
            'lastMessage': '历史沟通记录',
          },
        ],
      };
    } else if (path.endsWith('classList')) {
      data = [
        {'id': '31', 'name': '联考班'},
      ];
    } else if (path.endsWith('subjectList')) {
      data = [
        {'id': 1, 'name': '素描'},
      ];
    } else if (path.contains('List') ||
        path.contains('tasks') ||
        path.contains('teachers')) {
      data = <dynamic>[];
    }
    return Future<ApiResponse>.value(
      ApiResponse(code: 0, msg: 'ok', data: data),
    );
  }
}

Future<_OfflineClient> _mount(WidgetTester tester, Widget page) async {
  SharedPreferences.setMockInitialValues({
    'token': 'test-token',
    'schoolId': '1',
  });
  final storage = AppStorage(await SharedPreferences.getInstance());
  final client = _OfflineClient();
  tester.view.physicalSize = const Size(1180, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        apiClientProvider.overrideWithValue(client),
        markingApiClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: page),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return client;
}

void main() {
  testWidgets('提交作品打开图片作品链并保留作业 taskId', (tester) async {
    final client = await _mount(tester, StudentMyHomeworkView(onBack: () {}));
    await tester.tap(find.text('提交作品').first);
    await tester.pumpAndSettle();
    final dialog = tester.widget<ArtworkUploadDialog>(
      find.byType(ArtworkUploadDialog),
    );
    expect(dialog.taskId, '901');
    expect(dialog.initialTitle, '静物练习');
    expect(
      client.calls.any((p) => p.endsWith('studentHomeworkSubmit')),
      isFalse,
    );
  });

  testWidgets('教师发布固定图片且开放参考范画', (tester) async {
    await _mount(tester, TeacherHomeworkReviewView(onBack: () {}));
    await tester.tap(find.text('发布作品').first);
    await tester.pumpAndSettle();
    expect(find.text('图片'), findsWidgets);
    expect(find.text('参考范画（选填）'), findsOneWidget);
    expect(find.text('选择参考范画'), findsOneWidget);
    expect(find.text('视频'), findsNothing);
    expect(find.text('文档'), findsNothing);
  });

  testWidgets('正式模式家长消息未开通且没有发送控件', (tester) async {
    final client = await _mount(tester, TeacherHomeSchoolView(onBack: () {}));
    expect(find.text('家长消息尚未开通，目前仅可查看沟通记录'), findsOneWidget);
    await tester.tap(find.text('测试学生').first);
    await tester.pumpAndSettle();
    expect(find.text('家长消息尚未开通，暂时无法发送。'), findsOneWidget);
    expect(find.text('发送'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(client.calls.any((p) => p.contains('Send')), isFalse);
  }, skip: kDemoMode);
}
