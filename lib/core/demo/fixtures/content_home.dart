import '../demo_accounts.dart';
import '../demo_backend.dart';
import 'campus/campus_today_courses.dart';
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

/// 首页「课程」：与智慧校园共用同一份当天课表（[demoTodayCoursesFor]），
/// 首页周条、课程列表、我的课表、课堂签到看到的是同一批课。
/// 今天没有课时顺延到一周内下一个有课的日子；宿管、管理员没有个人课表，返回空列表。
List<Map<String, dynamic>> _upcomingCourses(DemoAccount account) {
  final now = DateTime.now();
  final today = demoTodayCoursesFor(account, now: now);
  if (today.isNotEmpty) {
    return today;
  }
  final midnight = DateTime(now.year, now.month, now.day);
  for (var offset = 1; offset < 7; offset++) {
    final courses = demoTodayCoursesFor(
      account,
      now: midnight.add(Duration(days: offset, hours: 8)),
    );
    if (courses.isNotEmpty) {
      return courses;
    }
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

  r.any('/app/user/nextSchoolCourse', (req) => _upcomingCourses(req.account));
}
