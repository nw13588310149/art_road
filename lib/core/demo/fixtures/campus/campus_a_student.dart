import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import 'campus_a_chat.dart';
import 'campus_a_common.dart';
import 'campus_a_leave.dart';
import 'campus_a_sign.dart';
import 'campus_a_study.dart';
import 'campus_b_records.dart';

/// 学生首页与班级：`index` / `mySchoolClass` / `schoolClassNotice/*` /
/// `noticeList` / `noticeDetail`。
abstract final class CampusAStudent {
  static String _readKey(DemoAccount account) =>
      'campusA:read:${account.userId}';

  // ── 班级通知 ────────────────────────────────────────────────────────

  /// 与班主任「班级工作台」发布的班级通知同一份。
  static List<Map<String, dynamic>> _classNotices() => [
    for (final n in cbClassNotices()) cbClassNoticeJson(n),
  ];

  static List<Map<String, dynamic>> _noticesOf(DemoAccount account) {
    final classId = CampusA.classOf(CampusA.personIndexOf(account)).id;
    return [
      for (final n in _classNotices())
        if (n['classId'] == classId) n,
    ]..sort(CampusA.compareTimeDesc);
  }

  static Map<String, dynamic> _readMap(DemoAccount account) =>
      DemoStore.map(_readKey(account), () {
        final notices = _noticesOf(account);
        return <String, dynamic>{
          for (final n in notices.skip(2)) 'classNotice:${n['id']}': true,
        };
      });

  static int unreadClassNotices(DemoAccount account) {
    final read = _readMap(account);
    return _noticesOf(
      account,
    ).where((n) => read['classNotice:${n['id']}'] != true).length;
  }

  // ── 我的班级 ────────────────────────────────────────────────────────

  static const _classrooms = <String, String>{
    '501': '城东校区 · 3 楼素描教室 A',
    '502': '城西校区 · 2 楼联考画室',
    '503': '安宁校区 · 校考创作室',
  };

  static Map<String, dynamic> _mySchoolClass(DemoAccount account) {
    final index = CampusA.personIndexOf(account);
    final c = CampusA.classOf(index);
    final head = CampusA.headTeacherOf(c);
    final teachers = CampusA.teachersOf(c).where((s) => s.id != head.id);
    final students = c.students;
    int countOf(String gender) => students.where((p) => p.gender == gender).length;
    return <String, dynamic>{
      'schoolClass': <String, dynamic>{
        'id': c.id,
        'name': c.name,
        'groupName': c.name,
        'type': 0,
        'grade': c.grade,
        'description':
            '${c.grade} · ${c.organizationName} · ${c.id == '503' ? '校考提高方向' : '联考冲刺方向'}',
        'announcement': CampusAChat.announcementOf(c.id),
        'headTeacherId': head.userId,
        'logo': CampusA.media('asset:assets/demo/brand/school_logo.png'),
      },
      'schoolClassroom': <String, dynamic>{
        'id': '${c.id}01',
        'name': _classrooms[c.id] ?? '${c.organizationName} · 画室',
      },
      'headTeacher': CampusA.staffUser(head),
      'dormitoryTeacherList': [CampusA.staffUser(CampusA.staff('d-1'))],
      'teacherList': [for (final s in teachers) CampusA.staffUser(s)],
      'studentInfoList': [
        for (final p in students)
          <String, dynamic>{
            'id': CampusA.studentUserId(p.index),
            'realname': p.name,
            'nickname': p.name,
            'gender': p.gender,
            'studentNo': CampusA.studentNo(p.index),
            'targetSchool': CampusA.targetSchool(p.index),
            'headUrl': CampusA.avatarUrl(p.index),
            'role': CampusA.classRole(p.index),
          },
      ],
      'genderCountList': [
        <String, dynamic>{'gender': '男', 'count': countOf('男')},
        <String, dynamic>{'gender': '女', 'count': countOf('女')},
      ],
    };
  }

  // ── 接口 ────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    const base = '/app/school/v2/student';

    r.post('$base/index', (req) {
      final account = req.account;
      return <String, dynamic>{
        'todayCourseCount': CampusASign.todayCourseCount(account),
        'homeworkCount': CampusAStudy.pendingHomeworkCount(account),
        'avgScore': CampusAStudy.semesterAverage(account),
        'classNoticeCount': unreadClassNotices(account),
        'monthlyExamDate': CampusA.date(CampusA.nextMonthlyExamDay()),
        'unifiedExamDate': CampusA.date(CampusA.unifiedExamDay()),
        'examCount': CampusAStudy.pendingExamCount(account),
        'leaveCount': CampusALeaves.pendingCount(account),
      };
    });

    r.post('$base/mySchoolClass', (req) => _mySchoolClass(req.account));

    r.post('$base/schoolClassNotice/list', (req) {
      final account = req.account;
      final read = _readMap(account);
      final list = [
        for (final n in _noticesOf(account))
          <String, dynamic>{
            ...n,
            'readStatus': read['classNotice:${n['id']}'] == true ? 1 : 0,
          },
      ];
      return CampusA.page(list, req);
    });

    r.post('$base/schoolClassNotice/detail', (req) {
      final account = req.account;
      final notice = CampusA.findById(_classNotices(), req.str('id'));
      if (notice == null) {
        throw const DemoApiException('通知不存在或已撤回');
      }
      _readMap(account)['classNotice:${notice['id']}'] = true;
      DemoStore.save(_readKey(account));
      return <String, dynamic>{...notice, 'readStatus': 1};
    });

    r.post('$base/noticeList', (req) {
      return CampusA.page(
        [for (final n in CampusANotices.forScope('student')) CampusANotices.row(n)],
        req,
      );
    });

    r.post('$base/noticeDetail', (req) {
      final notice = CampusA.findById(CampusANotices.all(), req.str('id'));
      if (notice == null) {
        throw const DemoApiException('通知不存在或已撤回');
      }
      return CampusANotices.row(notice);
    });
  }
}
