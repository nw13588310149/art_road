import '../data/demo_campus_data.dart';
import '../demo_accounts.dart';
import '../demo_backend.dart';
import 'content_common.dart';

/// 轮播图：contentType 0 首页 / 校园页，1 视频中心；带 schoolId 时为校园专属。
List<(String, String)> _bannerSet({
  required int contentType,
  required bool school,
}) {
  if (contentType == 1) {
    return school
        ? [
            ('九月月考素描讲评', ContentDemo.art('sketch-still-3')),
            ('色彩写生周现场', ContentDemo.art('color-landscape-1')),
            ('速写晚自习', ContentDemo.art('speed-group-1')),
          ]
        : [
            ('素描专题：石膏几何体', ContentDemo.art('sketch-still-1')),
            ('色彩专题：静物冷暖', ContentDemo.art('color-still-2')),
            ('速写专题：场景与人物', ContentDemo.art('speed-scene-1')),
          ];
  }
  return school
      ? [
          ('示范画室作品墙', ContentDemo.scene('studio-wall')),
          ('11 月月考安排', ContentDemo.scene('exam-hall')),
          ('城东校区色彩写生周', ContentDemo.art('color-landscape-1')),
        ]
      : [
          ('联考冲刺季', ContentDemo.scene('studio-wall')),
          ('考场实景：提前熟悉考试环境', ContentDemo.scene('exam-hall')),
          ('秋季写生作品展', ContentDemo.art('color-still-5')),
        ];
}

/// 学习进度：三科课时（completeCount / allCount）与百分比。
Map<String, dynamic> _progress({required bool school}) {
  Map<String, dynamic> entry(int done, int all) => <String, dynamic>{
    'completeCount': done,
    'allCount': all,
    'progress': all == 0 ? 0 : (done * 100 / all).round(),
  };
  return school
      ? <String, dynamic>{
          'sketch': entry(128, 160),
          'color': entry(98, 140),
          'speed': entry(100, 100),
        }
      : <String, dynamic>{
          'sketch': entry(36, 60),
          'color': entry(22, 48),
          'speed': entry(30, 40),
        };
}

const _courseColors = <String, String>{
  '素描': '#C9C2FF',
  '色彩': '#FED7AA',
  '速写': '#BBF7D0',
  '美术常识': '#BAE6FD',
  '文化课': '#FBCFE8',
  '模拟考试': '#FECACA',
  '色彩写生': '#FDE68A',
};

/// 当前账号的下一组课程：今天还有未结束的课取今天，否则顺延到下一个有课的日子。
List<Map<String, dynamic>> _nextCourses(DemoAccount account) {
  final staff = DemoCampusData.staffByUserId(account.userId);
  DemoCampusClass klass;
  if (account.role == DemoRole.student) {
    klass = DemoCampusData.classOfPerson(account.personIndex ?? 1);
  } else if (staff != null && staff.classIds.isNotEmpty) {
    klass =
        DemoCampusData.classById(staff.classIds.first) ??
        DemoCampusData.classes.first;
  } else {
    klass = DemoCampusData.classes.first;
  }
  final teacherId = staff != null && staff.subject.isNotEmpty ? staff.id : '';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String clock(DateTime t) => ContentDemo.dateTime(t).substring(11, 16);
  final nowClock = clock(now);

  for (var offset = 0; offset < 7; offset++) {
    final day = today.add(Duration(days: offset));
    var slots = DemoCampusData.timetableTemplate
        .where((s) => s.weekday == day.weekday)
        .toList();
    if (teacherId.isNotEmpty) {
      final mine = slots.where((s) => s.teacherId == teacherId).toList();
      if (mine.isNotEmpty) {
        slots = mine;
      }
    }
    if (slots.isEmpty) {
      continue;
    }
    if (offset == 0 && slots.every((s) => s.end.compareTo(nowClock) <= 0)) {
      continue;
    }
    final date = ContentDemo.date(day);
    return <Map<String, dynamic>>[
      for (var i = 0; i < slots.length; i++)
        <String, dynamic>{
          'id': '${klass.id}-${date.replaceAll('-', '')}-${i + 1}',
          'date': date,
          'timeBegin': '${slots[i].start}:00',
          'timeEnd': '${slots[i].end}:00',
          'room': slots[i].room,
          'color': _courseColors[slots[i].courseName] ?? '#E0DEFF',
          'type': 0,
          'subject': <String, dynamic>{'name': slots[i].courseName},
          'teacher': <String, dynamic>{
            'id': slots[i].teacherId,
            'realname':
                DemoCampusData.staffById(slots[i].teacherId)?.name ?? '任课老师',
            'headUrl': '',
          },
          'schoolClass': <String, dynamic>{
            'id': klass.id,
            'name': klass.name,
            'logo': ContentDemo.url(ContentDemo.schoolLogo),
          },
        },
    ];
  }
  return const <Map<String, dynamic>>[];
}

void registerContentHomeFixtures(DemoRouter r) {
  r.any('/app/user/bannerList', (req) {
    final schoolId = req.str('schoolId');
    final school = schoolId.isNotEmpty && schoolId != '0';
    final contentType = req.intOf('contentType');
    final banners = _bannerSet(contentType: contentType, school: school);
    return <Map<String, dynamic>>[
      for (var i = 0; i < banners.length; i++)
        <String, dynamic>{
          'id': contentType * 100 + (school ? 50 : 0) + i + 1,
          'title': banners[i].$1,
          'img': ContentDemo.url(banners[i].$2),
          'contentType': contentType,
          'schoolId': school ? schoolId : '0',
          'sort': i + 1,
        },
    ];
  });

  r.any('/app/user/homeLearningProgress', (req) => _progress(school: false));
  r.any(
    '/app/user/schoolHomeLearningProgress',
    (req) => _progress(school: true),
  );

  r.any('/app/user/nextSchoolCourse', (req) => _nextCourses(req.account));
}
