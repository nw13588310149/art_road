// 体验身份：七个演示账号、教学组长标记、校长的数据范围，以及这两种身份在
// 首页、智慧校园和新手引导里的落点。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_campus_data.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_a_chat.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_b_common.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/interaction_common.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/platform_core_fixtures.dart';
import 'package:the_road_of_art_flutter/features/circle/state/circle_state.dart';
import 'package:the_road_of_art_flutter/features/help_guide/data/role_guides.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_dashboard_controller.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_dashboard_state.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_sections.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_staff_cards.dart';
import 'package:the_road_of_art_flutter/features/shell/state/shell_state.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/state/smart_campus_state.dart';

DemoRequest _requestOf(DemoAccount account) => DemoRequest(
  method: 'POST',
  path: '/',
  query: const <String, dynamic>{},
  body: const <String, dynamic>{},
  headers: <String, dynamic>{'app-token': account.token},
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await DemoStore.init();
    await DemoStore.reset();
  });

  group('demo accounts', () {
    test('seven identities with unique mobiles, ids and tokens', () {
      expect(DemoAccounts.all.map((a) => a.role), DemoRole.values);
      expect(DemoAccounts.all.map((a) => a.mobile).toSet(), hasLength(7));
      expect(DemoAccounts.all.map((a) => a.userId).toSet(), hasLength(7));
      for (final account in DemoAccounts.all) {
        expect(DemoAccounts.byMobile(account.mobile), same(account));
        expect(DemoAccounts.fromToken(account.token), same(account));
      }
    });

    test('staff accounts match the campus roster', () {
      for (final account in DemoAccounts.all) {
        if (account.role == DemoRole.student) continue;
        final staff = DemoCampusData.staffByUserId(account.userId);
        expect(staff, isNotNull, reason: account.name);
        expect(staff!.name, account.name);
        expect(staff.phone, account.mobile);
        final teacherId = account.teacherId;
        if (teacherId != null) {
          expect(staff.id, teacherId, reason: account.name);
        }
        expect(demoCampusOf(account), isNotEmpty, reason: account.name);
      }
    });

    test('role groups', () {
      expect(DemoRole.groupLeader.teaches, isTrue);
      expect(DemoRole.groupLeader.managesSchool, isFalse);
      expect(DemoRole.principal.managesSchool, isTrue);
      expect(DemoRole.principal.teaches, isFalse);
      expect(DemoRole.admin.managesSchool, isTrue);
      expect(DemoRole.headTeacher.teaches, isTrue);
      expect(DemoRole.dormManager.teaches, isFalse);
      expect(DemoRole.student.isStaff, isFalse);
    });
  });

  group('group leader', () {
    const leader = DemoAccounts.groupLeader;

    test('stays a teacher for the backend and carries the subjects led', () {
      expect(leader.roleKey, 'teacher');
      expect(leader.isGroupLeader, isTrue);
      final info = demoUserInfo(leader);
      expect(info['role'], 'teacher');
      expect(info['identity'], '组长');
      expect((info['groupLeader'] as Map)['subjects'], ['素描']);
      expect(info['campus'], '城西校区');

      for (final account in DemoAccounts.all) {
        if (account.role == DemoRole.groupLeader) continue;
        expect(account.isGroupLeader, isFalse, reason: account.name);
        expect(
          demoUserInfo(account).containsKey('groupLeader'),
          isFalse,
          reason: account.name,
        );
      }
    });

    test('the roster marks the same teacher as the leader of that subject', () {
      final staff = DemoCampusData.staffById(leader.teacherId!)!;
      expect(staff.isGroupLeader, isTrue);
      expect(leader.groupLeaderSubjects, [staff.subject]);
      expect(
        DemoCampusData.staffById(DemoAccounts.teacher.teacherId!)!
            .isGroupLeader,
        isFalse,
      );
      // 组长与被复核的演示任课老师同科目、不是同一个人。
      expect(
        DemoCampusData.staffById(DemoAccounts.teacher.teacherId!)!.subject,
        staff.subject,
      );
    });

    test('keeps a teaching scope in smart campus', () {
      final scope = cbScope(_requestOf(leader));
      expect(scope.all, isFalse);
      expect(scope.teachingClassIds, containsAll(['502', '503']));
      expect(scope.examSubjects, ['素描']);
      expect(cbStaffRoles(scope.staff!).split(','), ['course_teacher']);
    });
  });

  group('principal', () {
    const principal = DemoAccounts.principal;

    test('myInfo carries the principal role and a campus', () {
      final info = demoUserInfo(principal);
      expect(info['role'], 'principal');
      expect(info['identity'], '校长');
      expect(info['campus'], isNotEmpty);
    });

    test('sees every class like the admin', () {
      final scope = cbScope(_requestOf(principal));
      final admin = cbScope(_requestOf(DemoAccounts.admin));
      expect(scope.all, isTrue);
      expect(scope.teachingClassIds, admin.teachingClassIds);
      expect(scope.headClassIds, admin.headClassIds);
      expect(scope.examSubjects, ['素描', '色彩', '速写']);
      expect(scope.name, principal.name);
      expect(scope.userId, principal.userId);
    });

    test('is listed in the roster as 校长, not as a teacher', () {
      final staff = DemoCampusData.staffByUserId(principal.userId)!;
      expect(staff.subject, isEmpty);
      expect(cbStaffRoles(staff).split(','), ['headmaster']);
      expect(demoStaffAuthor(staff).identity, startsWith('校长'));
      // 管理员的身份 token 不受影响。
      expect(
        cbStaffRoles(DemoCampusData.staffById('t-9')!).split(','),
        ['manager'],
      );
    });

    test('joins every group chat', () {
      expect(
        CampusAChat.groupsOf(principal).map((g) => g.id),
        CampusAChat.groupsOf(DemoAccounts.admin).map((g) => g.id),
      );
      expect(CampusAChat.groupsOf(principal), isNotEmpty);
    });

    test('governs the school circle', () {
      expect(
        CirclePermissions.shellUserIsAdmin(role: 'principal', identity: ''),
        isTrue,
      );
      expect(
        CirclePermissions.shellUserIsAdmin(role: 'teacher', identity: '组长'),
        isFalse,
      );
    });
  });

  group('where the identities land', () {
    test('smart campus', () {
      expect(mapBackendRoleToCampus('teacher', '组长'), SmartCampusRole.teacher);
      expect(
        mapBackendRoleToCampus('principal', '校长'),
        SmartCampusRole.principal,
      );
    });

    test('home page', () {
      // 组长的 role 是 teacher：与任课老师同一套区块、入口和课表。
      final leader = homeSectionsFor(DemoAccounts.groupLeader.roleKey);
      expect(
        leader.studySnapshot && leader.reviewQueue && leader.courses,
        isTrue,
      );
      expect(homeRoleHasTimetable(DemoAccounts.groupLeader.roleKey), isTrue);

      final principal = homeSectionsFor('principal');
      expect(principal.sideTodo && principal.studySnapshot, isTrue);
      expect(principal.courses, isFalse);
      expect(homeRoleHasTimetable('principal'), isFalse);

      final todos = buildHomeTodos(
        'principal',
        const HomeTodoInput(leaveApprovals: 2, signConfirmations: 1),
      );
      expect(todos.map((t) => t.title), contains('教师请假审批'));

      final names = buildQuickActions(
        isStaff: true,
        role: 'principal',
      ).map((a) => a.name);
      expect(names, contains('全校学情'));
    });

    test('left navigation', () {
      List<String> labels(String role) => [
        for (final item in buildDefaultNavItems(
          schoolCoursewareEnabled: true,
          isStaff: isStaffRole(role),
          role: role,
        ))
          item.label,
      ];
      expect(labels('principal'), contains('全校学情'));
      expect(labels('teacher'), contains('班级学情'));
      expect(labels('student'), contains('我的学情'));
    });

    test('first-login guide', () {
      expect(roleGuideRoles, contains('principal'));
      expect(roleGuideFor('principal').roleLabel, '校长');
      expect(
        roleGuideFor('principal').steps.map((s) => s.title),
        contains('全校学情'),
      );
      // 组长与任课老师共用引导。
      expect(
        roleGuideFor(DemoAccounts.groupLeader.roleKey).roleLabel,
        '任课老师',
      );
    });
  });
}
