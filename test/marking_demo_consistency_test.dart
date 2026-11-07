import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_campus_data.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_marking_data.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/marking_artwork_fixtures.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/marking_gallery_fixtures.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/marking_study_fixtures.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_models.dart';
import 'package:the_road_of_art_flutter/features/gallery/data/gallery_models.dart';
import 'package:the_road_of_art_flutter/features/study_center/data/study_logic.dart';
import 'package:the_road_of_art_flutter/features/study_center/data/study_models.dart';

/// 学情中心、作品点评、范画库三处演示数据同源：同一学生、考试、分数在各页对得上。
void main() {
  late DemoRouter router;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await DemoStore.init();
    await DemoStore.reset();
    router = DemoRouter('marking-consistency-test');
    registerMarkingStudyFixtures(router);
    registerMarkingArtworkFixtures(router);
    registerMarkingGalleryFixtures(router);
  });

  Future<Object?> get(
    String path, {
    DemoAccount account = DemoAccounts.student,
    Map<String, dynamic> query = const <String, dynamic>{},
  }) async {
    final match = router.match('GET', path);
    expect(match, isNotNull, reason: path);
    return match!.handler(
      DemoRequest(
        method: 'GET',
        path: path,
        query: query,
        body: null,
        headers: <String, dynamic>{'app-token': account.token},
        pathParams: match.params,
      ),
    );
  }

  test('学情页头显示学号，超过百分比能用名次与参考人数核对', () async {
    final overview = StudyOverview.fromJson(await get('/app/study/overview'));
    expect(overview.profile.studentNo, '2027001');
    final exam = overview.recentStage!.exam;
    expect(exam.examName, '2026 年 9 月月考');
    expect(exam.totalRanking, 7);
    expect(exam.participantCount, 38);

    final report = StudyExamReport.fromJson(await get('/app/study/exams/26'));
    expect(
      report.surpassedPercent,
      surpassedPercentOf(exam.totalRanking, exam.participantCount),
    );
    expect(report.surpassedPercent, 82);
  });

  test('85 分的色彩在学情中是 B 档，与档位表一致', () async {
    final report = StudyExamReport.fromJson(await get('/app/study/exams/26'));
    final color = report.subjects.firstWhere((s) => s.subjectName == '色彩');
    expect(color.score, 85);
    expect(color.grade, 'B');
    final bands = DemoMarkingData.bands('色彩', 100);
    expect(DemoMarkingData.gradeOf(85, bands), 'B');
  });

  test('10 月月考仍在阅卷中，各处都按阅卷中展示', () async {
    final exams = await get('/app/study/exams') as Map;
    final october = (exams['records'] as List).cast<Map>().firstWhere(
      (e) => e['examId'] == '27',
    );
    expect(october['status'], 'MARKING');
    expect(october['totalScore'], isNull);
  });

  test('作品点评对老师显示学号，与学生名册同一规则', () async {
    final page = ArtworkPage.fromJson(
      await get(
        '/school/teacher/artworks',
        account: DemoAccounts.teacher,
        query: <String, dynamic>{'status': 'ALL', 'size': 50},
      ),
    );
    final person = DemoMarkingData.instance.person(30);
    final row = page.records.firstWhere((r) => r.studentName == person.name);
    expect(row.studentNo, '2027030');
  });

  test('作品档案的得分最高科目与学情一致（素描）', () async {
    final insights = ArtworkInsights.fromJson(
      await get('/app/artworks/insights'),
    );
    expect(insights.bestSubject, '素描');
    expect(insights.weakestSubject, '色彩');
  });

  test('范画库每张图只出现一次，作者都是画室在册老师，浏览量拉开量级', () async {
    final page = GalleryWorksPage.fromJson(
      await get('/app/gallery/works', query: <String, dynamic>{'size': 100}),
    );
    final works = page.records;
    expect(works, isNotEmpty);
    expect(works.map((w) => w.imageUrl).toSet(), hasLength(works.length));

    final roster = {
      for (final staff in DemoCampusData.staff) staff.name: staff.subject,
    };
    for (final work in works.where((w) => w.source == GallerySource.master)) {
      expect(roster[work.author], work.subject, reason: work.title);
      expect(
        work.title.contains('·') ? work.title.contains(' · ') : true,
        isTrue,
      );
    }

    final views = works.map((w) => w.views).toList()..sort();
    expect(views.last - views.first, greaterThan(3000));

    final examTop = works.where((w) => w.source == GallerySource.examTop);
    expect(examTop, hasLength(3));
    for (final work in examTop) {
      expect(work.examName, '2026 年 9 月月考');
      final bands = DemoMarkingData.bands(work.subject, 100);
      expect(work.grade, DemoMarkingData.gradeOf(work.score!, bands));
    }
  });
}
