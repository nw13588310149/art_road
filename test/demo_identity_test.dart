// 身份与组织：七种体验身份、科目组与组长、校长分管范围，以及新身份在首页、
// 智慧校园和新手引导里的落点。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_campus_data.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_b_common.dart';
import 'package:the_road_of_art_flutter/features/help_guide/data/role_guides.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_dashboard_controller.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_dashboard_state.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_sections.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/state/smart_campus_state.dart';

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
        final id = account.teacherId;
        if (id == null) continue;
        final staff = DemoCampusData.staffById(id);
        expect(staff, isNotNull, reason: account.name);
        expect(staff!.userId, account.userId, reason: account.name);
        expect(staff.name, account.name);
        expect(staff.phone, account.mobile);
      }
    });

    test('role groups', () {
      expect(DemoRole.principal.managesSchool, isTrue);
      expect(DemoRole.admin.managesSchool, isTrue);
      expect(DemoRole.subjectLead.managesSchool, isFalse);
      expect(DemoRole.subjectLead.teaches, isTrue);
      expect(DemoRole.principal.teaches, isFalse);
      expect(DemoRole.student.isStaff, isFalse);
    });
  });

  group('subject groups', () {
    test('each art subject has one group led by a teacher of that subject', () {
      expect(DemoCampusData.subjectGroups.map((g) => g.subject), [
        '素描',
        '色彩',
        '速写',
      ]);
      for (final group in DemoCampusData.subjectGroups) {
        final lead = DemoCampusData.staffById(group.leadId);
        expect(lead, isNotNull, reason: group.name);
        expect(lead!.subject, group.subject);
        expect(group.members, contains(lead));
        expect(group.members.length, greaterThan(1), reason: group.name);
        expect(DemoCampusData.groupLedBy(group.leadId), same(group));
        expect(DemoCampusData.leadOfSubject(group.subject), same(lead));
      }
    });

    test('the demo lead reviews the demo teacher', () {
      final group = DemoCampusData.groupLedBy(
        DemoAccounts.subjectLead.teacherId!,
      );
      expect(group?.subject, '素描');
      expect(
        group!.members.map((s) => s.id),
        contains(DemoAccounts.teacher.teacherId),
      );
      expect(
        DemoCampusData.groupLedBy(DemoAccounts.teacher.teacherId!),
        isNull,
      );
    });
  });

  group('principal in charge', () {
    test('campus assignment applies unless the class names its own', () {
      expect(DemoCampusData.principalOfClass('501')?.id, 'p-1');
      expect(DemoCampusData.principalOfClass('502')?.id, 'p-2');
      // 安宁校区归 p-2，校考提高班单独指定给 p-1。
      expect(DemoCampusData.campusPrincipals['安宁校区'], 'p-2');
      expect(DemoCampusData.principalOfClass('503')?.id, 'p-1');
      expect(DemoCampusData.principalOfClass('999'), isNull);
    });

    test('every class has exactly one principal', () {
      final covered = <String>[
        for (final id in const ['p-1', 'p-2'])
          ...DemoCampusData.classesOfPrincipal(id).map((c) => c.id),
      ];
      expect(covered..sort(), ['501', '502', '503']);
      expect(
        DemoCampusData.classesOfPrincipal(
          DemoAccounts.principal.teacherId!,
        ).map((c) => c.id),
        ['501', '503'],
      );
    });
  });

  group('teacherRole tokens', () {
    List<String> tokens(String staffId) =>
        cbStaffRoles(DemoCampusData.staffById(staffId)!).split(',');

    test('leads, principals and admins carry their tokens', () {
      expect(tokens('t-2'), containsAll(['subject_leader', 'course_teacher']));
      expect(tokens('t-1'), ['course_teacher']);
      expect(
        tokens('t-5'),
        containsAll(['subject_leader', 'head_teacher', 'course_teacher']),
      );
      expect(tokens('p-1'), ['headmaster']);
      expect(tokens('t-9'), ['manager']);
      expect(tokens('d-1'), ['dormitory']);
    });
  });

  group('where the new identities land', () {
    test('smart campus', () {
      expect(mapBackendRoleToCampus('subjectLead'), SmartCampusRole.teacher);
      expect(mapBackendRoleToCampus('principal'), SmartCampusRole.principal);
    });

    test('home page', () {
      expect(homeRoleKind('subjectLead'), 'teacher');
      expect(homeRoleKind('principal'), 'admin');
      expect(homeRoleKind('headTeacher'), 'headTeacher');

      final lead = homeSectionsFor('subjectLead');
      expect(lead.studySnapshot && lead.reviewQueue && lead.courses, isTrue);
      final principal = homeSectionsFor('principal');
      expect(principal.sideTodo && principal.studySnapshot, isTrue);
      expect(principal.courses, isFalse);

      expect(homeRoleHasTimetable('subjectLead'), isTrue);
      expect(homeRoleHasTimetable('principal'), isFalse);

      String names(String role) => buildQuickActions(
        isStaff: true,
        role: role,
      ).map((a) => a.name).join();
      expect(names('subjectLead'), names('teacher'));
      expect(names('principal'), names('admin'));
    });

    test('first-login guide', () {
      expect(roleGuideRoles, DemoRole.values.map((r) => r.name));
      expect(roleGuideFor('subjectLead').roleLabel, '科目组长');
      expect(roleGuideFor('principal').roleLabel, '校长');
      expect(
        roleGuideFor('principal').steps.map((s) => s.title),
        contains('校长信箱'),
      );
    });
  });
}
