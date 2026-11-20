import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_identity.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/state/checklist_controller.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/state/score_controller.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/ui/tools/score_tool.dart';
import 'package:the_road_of_art_flutter/features/shell/data/shell_repository.dart';
import 'package:the_road_of_art_flutter/features/shell/state/shell_controller.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/countdown_repository.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/score_form_repository.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/exam_checklist.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/value_order_records.dart';

class _ShellRepository extends Fake implements ShellRepository {
  final pending = <Completer<ApiResponse>>[];

  @override
  Future<ApiResponse> getMyInfo() {
    final response = Completer<ApiResponse>();
    pending.add(response);
    return response.future;
  }

  void respond(String id) => pending
      .removeAt(0)
      .complete(
        ApiResponse(
          code: 0,
          msg: 'ok',
          data: {
            'user': {'id': id},
          },
        ),
      );

  @override
  Future<ApiResponse> getSchoolInfo() async => ApiResponse.failure('无测试学校数据');

  @override
  Future<ApiResponse> getUnreadCount() async => ApiResponse.failure('无测试消息');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('挂载中的分数表单会按已确认的账号重新加载输入', (tester) async {
    const first = 'user:1880000000000001001';
    const second = 'user:1880000000000001002';
    await ScoreFormRepository(
      ownerKey: first,
    ).save(const ScoreFormData(culture: '584'));
    await ScoreFormRepository(
      ownerKey: second,
    ).save(const ScoreFormData(culture: '411'));
    final owner = StateProvider<String?>((_) => null);
    final container = ProviderContainer(
      overrides: [toolboxOwnerProvider.overrideWith((ref) => ref.watch(owner))],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: ScoreTool(onBack: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('当前输入不保存'), findsOneWidget);

    container.read(owner.notifier).state = first;
    await tester.pumpAndSettle();
    expect(find.text('584'), findsOneWidget);
    container.read(owner.notifier).state = second;
    await tester.pumpAndSettle();
    expect(find.text('584'), findsNothing);
    expect(find.text('411'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('同号正式账号按已认证用户隔离，晚到身份不会接管挂载中的工具', () async {
    const phone = '13800000001';
    const studentId = '1880000000000001001';
    const staffId = '1880000000000001002';
    final storage = await AppStorage.create();
    await storage.saveToken('example-student-token');
    await storage.saveMobile(phone);
    final legacy = ScoreFormRepository(ownerKey: 'account:$phone');
    await legacy.save(const ScoreFormData(culture: '997'));
    final shellRepo = _ShellRepository();
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        shellRepositoryProvider.overrideWithValue(shellRepo),
      ],
    );
    addTearDown(container.dispose);
    final scoreWatch = container.listen(scoreFormControllerProvider, (_, _) {});
    final checklistWatch = container.listen(
      examChecklistControllerProvider,
      (_, _) {},
    );
    addTearDown(scoreWatch.close);
    addTearDown(checklistWatch.close);
    final shell = container.read(shellControllerProvider.notifier);
    Future<void> flush() async {
      await Future<void>.delayed(Duration.zero);
      await container.pump();
    }

    String score() => scoreWatch.read().data.culture;
    Future<void> toggleChecklist() => container
        .read(examChecklistControllerProvider.notifier)
        .toggle('doc-id');

    await flush();
    expect(container.read(toolboxOwnerProvider), isNull);
    expect(score(), isEmpty);
    container
        .read(scoreFormControllerProvider.notifier)
        .update((data) => data.copyWith(culture: '111'));
    await toggleChecklist();
    shellRepo.respond('0');
    await flush();
    expect(container.read(toolboxOwnerProvider), isNull);
    final fresh = shell.refreshUserAndSchool();
    shellRepo.respond(studentId);
    await fresh;
    await flush();
    expect(container.read(toolboxOwnerProvider), 'user:$studentId');
    expect(score(), isEmpty);
    expect(checklistWatch.read().checklist.checked, isEmpty);
    container
        .read(scoreFormControllerProvider.notifier)
        .update((data) => data.copyWith(culture: '500'));
    await toggleChecklist();
    await flush();

    final stale = shell.refreshUserAndSchool();
    await storage.saveToken('example-staff-token');
    await storage.saveMobile(phone);
    expect(storage.mobile, phone);
    await flush();
    expect(container.read(toolboxOwnerProvider), isNull);
    expect(score(), isEmpty);
    expect(checklistWatch.read().checklist.checked, isEmpty);
    final active = shell.refreshUserAndSchool();
    shellRepo.respond(studentId);
    await stale;
    expect(container.read(toolboxOwnerProvider), isNull);
    shellRepo.respond(staffId);
    await active;
    await flush();
    expect(container.read(toolboxOwnerProvider), 'user:$staffId');
    expect(score(), isEmpty);
    expect(checklistWatch.read().checklist.checked, isEmpty);
    expect((await legacy.load()).culture, '997');
    expect(
      (await ScoreFormRepository(ownerKey: 'user:$studentId').load()).culture,
      '500',
    );
    expect(
      (await ExamChecklistRepository(
        ownerKey: 'user:$studentId',
      ).load()).checked,
      {'doc-id'},
    );
  });

  test('演示用户继续读取原有演示资料和通用清单模板', () async {
    final storage = await AppStorage.create();
    final demo = DemoAccounts.student;
    await storage.saveToken(demo.token);
    final owner = 'demo:${demo.userId}';
    await ScoreFormRepository(
      ownerKey: owner,
    ).save(const ScoreFormData(culture: '290'));
    final container = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    expect(container.read(toolboxOwnerProvider), owner);
    expect(
      (await container.read(scoreFormRepositoryProvider).load()).culture,
      '290',
    );
    expect(
      (await container.read(examChecklistRepositoryProvider).load()).checked,
      isEmpty,
    );
    expect(
      (await container.read(examChecklistRepositoryProvider).load()).items,
      isNotEmpty,
    );
  });

  test(
    'personal tables are isolated and delayed writes retain original owner',
    () async {
      final a = ScoreFormRepository(ownerKey: 'account:a');
      final b = ScoreFormRepository(ownerKey: 'account:b');
      await a.save(const ScoreFormData(culture: '500'));
      expect((await b.load()).culture, isEmpty);
      expect((await a.load()).culture, '500');
      await ValueOrderRecordRepository(
        ownerKey: 'account:a',
      ).save({'best': 50});
      expect(
        await ValueOrderRecordRepository(ownerKey: 'account:b').load(),
        isEmpty,
      );
      expect(await ValueOrderRecordRepository(ownerKey: 'account:a').load(), {
        'best': 50,
      });
      final checklist = ExamChecklistRepository(ownerKey: 'account:a');
      await checklist.save(const ExamChecklist(checked: {'doc-id'}));
      expect(
        (await ExamChecklistRepository(ownerKey: 'account:b').load()).checked,
        isEmpty,
      );
    },
  );
  test(
    'real countdown starts empty; demo defaults and existing legacy data survive',
    () async {
      expect(await CountdownRepository(ownerKey: 'account:a').load(), isEmpty);
      final demo = CountdownRepository(ownerKey: 'demo:a');
      expect(await demo.load(), hasLength(2));
      await CountdownRepository(ownerKey: 'account:a').save([
        ExamCountdown(id: 'personal', name: '个人考试', date: DateTime(2027, 1, 1)),
      ]);
      expect(await CountdownRepository(ownerKey: 'account:b').load(), isEmpty);
      expect(
        (await CountdownRepository(ownerKey: 'account:a').load()).single.id,
        'personal',
      );
      expect(
        await CountdownRepository(ownerKey: 'demo:a').load(),
        hasLength(2),
      );
    },
  );
}
