import '../../data/demo_artwork_data.dart';
import '../../data/demo_artwork_store.dart';
import '../../data/demo_campus_data.dart';
import '../../data/demo_marking_data.dart';
import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import '../../../../features/study_center/data/composite_estimate.dart';
import 'campus_b_common.dart';
import 'campus_b_courses.dart';

typedef _Row = Map<String, dynamic>;

void registerTeachingOverviewFixtures(DemoRouter router) {
  router.get('/app/study/goal', (request) {
    final person = _goalPerson(request);
    return DemoStore.map(_goalKey(person), () => {});
  });
  router.post('/app/study/goal', (request) {
    final person = _goalPerson(request);
    final form = CompositeEstimateForm.fromJson(request.bodyMap);
    final store = DemoStore.map(_goalKey(person), () => {});
    store
      ..clear()
      ..addAll(form.toJson());
    DemoStore.save(_goalKey(person));
    return true;
  });
  router.get('/school/principal/overview', (request) {
    _requirePrincipal(request);
    return _Overview(request).summary();
  });
  router.get('/school/principal/trend', (request) {
    _requirePrincipal(request);
    return _Overview(request).trend(
      request.str('metric', 'submissions'),
      request.intOf('days', 7).clamp(1, 30),
    );
  });
  router.get('/school/principal/teachers', (request) {
    _requirePrincipal(request);
    final rows = _Overview(request).teachers(subject: request.str('subject'));
    final sort = request.str('sort');
    if (const {
      'timely',
      'quality',
      'punctual',
      'taskCount',
      'taskReviewRate',
      'scoreChange',
      'adjustRate',
    }.contains(sort)) {
      rows.sort(
        (a, b) => ((b[sort] as num?) ?? -1).compareTo((a[sort] as num?) ?? -1),
      );
    }
    return rows;
  });
  router.get('/school/principal/teachers/{id}', (request) {
    _requirePrincipal(request);
    return _Overview(request).teacherDetail(request.param('id'));
  });
  router.get('/school/teacher/performance', (request) {
    _requireTeacher(request);
    return _Overview(request).teacherDetail(request.account.teacherId ?? '');
  });
  router.get('/school/leader/teachers', (request) {
    if (!request.account.isGroupLeader) {
      throw const DemoApiException('仅教学组长可以查看本组履职', code: 403);
    }
    return _Overview(
      request,
    ).teachers(subjects: request.account.groupLeaderSubjects);
  });
  router.get('/school/principal/classes', (request) {
    _requirePrincipal(request);
    return _Overview(request).classResults();
  });
  router.get('/school/principal/attention-students', (request) {
    _requirePrincipal(request);
    return _Overview(request).attention();
  });
  router.get('/school/teacher/attention-students', (request) {
    _requireTeacher(request);
    return _Overview(request).attention(teacherId: request.account.teacherId);
  });
  router.get('/school/principal/review-chain', (request) {
    _requirePrincipal(request);
    return _Overview(request).reviewChain(
      date: request.str('date'),
      filter: request.str('filter'),
      teacherId: request.str('teacherId'),
    );
  });
  router.get('/school/leader/classes', (request) {
    if (!request.account.isGroupLeader) {
      throw const DemoApiException('仅教学组长可以查看本组学情', code: 403);
    }
    return _Overview(request).classResults(
      subjects: request.account.groupLeaderSubjects,
      includeStudents: false,
    );
  });
  router.get('/school/teacher/students', (request) {
    _requireTeacher(request);
    return _Overview(request).teacherStudents(request.account.teacherId!);
  });
  router.post('/school/teaching/students/{id}/follow-up', (request) {
    final overview = _Overview(request);
    final person = overview.students
        .where((p) => p.archiveId == request.param('id'))
        .firstOrNull;
    if (person == null) throw const DemoApiException('学生不存在', code: 404);
    if (request.account.role != DemoRole.principal) {
      _requireTeacher(request);
      if (!overview
          .teacherStudents(request.account.teacherId!)
          .any((r) => r['id'] == person.archiveId)) {
        throw const DemoApiException('只能跟进本人所带班级的学生', code: 403);
      }
    }
    final status = request.str('status');
    final note = request.str('note');
    if (!['pending', 'following', 'resolved'].contains(status)) {
      throw const DemoApiException('请选择跟进状态');
    }
    if (note.runes.length < 5 || note.runes.length > 500) {
      throw const DemoApiException('跟进记录须为 5 至 500 字');
    }
    final key = 'teaching:follow-up:${person.archiveId}';
    final row = DemoStore.map(key, () => {});
    final record = {
      'status': status,
      'note': note,
      'owner': request.account.name,
      'updatedAt': DemoArtworkData.fmt(DemoArtworkStore.now()),
    };
    final history = [
      record,
      ...DemoArtworkData.mapsOf(row['history']),
    ].take(20).toList();
    row.addAll({...record, 'history': history});
    DemoStore.save(key);
    return row;
  });
  router.get('/school/principal/attendance', (request) {
    _requirePrincipal(request);
    return _Overview(request).attendance();
  });
}

String _goalKey(int person) => 'study_goal:v3:$person';

int _goalPerson(DemoRequest request) {
  final person = request.account.personIndex;
  if (person == null) {
    throw const DemoApiException('仅学生可以设置自己的目标', code: 403);
  }
  return person;
}

void _requirePrincipal(DemoRequest request) {
  if (request.account.role != DemoRole.principal) {
    throw const DemoApiException('仅校长可以查看全校概览', code: 403);
  }
}

void _requireTeacher(DemoRequest request) {
  if (!request.account.role.teaches || request.account.teacherId == null) {
    throw const DemoApiException('仅任课老师可以查看', code: 403);
  }
}

class _Overview {
  _Overview(this.request);

  final DemoRequest request;
  late final DateTime now = DemoArtworkStore.now();
  late final DateTime today = cbDay(now);
  late final settings = DemoArtworkStore.settings();
  final marking = DemoMarkingData.instance;
  late final String campusId = request.str('campusId');
  late final classes = DemoCampusData.classes
      .where(
        (c) =>
            campusId.isEmpty ||
            campusId == c.id ||
            campusId == c.organizationName,
      )
      .toList();
  late final classIds = classes.map((c) => c.id).toSet();
  late final students = classes
      .expand((c) => c.students)
      .where(cbIsActive)
      .toList();
  late final people = {for (final person in students) person.index: person};
  late final works = DemoArtworkStore.works()
      .where((work) => people.containsKey(DemoArtworkData.personOf(work)))
      .toList();
  late final tasks = DemoArtworkStore.tasks()
      .where((task) => cbStrList(task['classIds']).any(classIds.contains))
      .toList();
  late final courses = cbCoursesBetween(cbAddDays(today, -29), today)
      .where(
        (course) =>
            !course.startAt.isAfter(now) && classIds.contains(course.classId),
      )
      .toList();
  final _signs = <String, _Row>{};

  bool _hasStudent(String id) =>
      people.containsKey((int.tryParse(id) ?? 0) - 900000);

  _Row _sign(CbCourse course) =>
      _signs.putIfAbsent(course.id, () => cbSignOf(course));

  _Row _studentSigns(CbCourse course) =>
      DemoArtworkData.mapOf(_sign(course)['students']) ?? const {};

  List<_Row> _submittedOn(DateTime day) =>
      works.where((work) => _date(work['createTime']) == cbDate(day)).toList();

  bool _recent(Object? time, int days) {
    final parsed = DemoArtworkData.parseTime(time);
    return parsed != null &&
        !parsed.isBefore(cbAddDays(today, 1 - days)) &&
        !parsed.isAfter(now);
  }

  bool _onTime(_Row work) {
    final created = DemoArtworkData.parseTime(work['createTime']);
    final reviewed = DemoArtworkData.parseTime(
      DemoArtworkData.reviewOf(work)?['reviewedTime'],
    );
    return created != null &&
        reviewed != null &&
        !reviewed.isAfter(
          DemoArtworkData.deadline(created, settings.reviewHours),
        );
  }

  bool _dueOrReviewed(_Row work) =>
      DemoArtworkData.isReviewed(work) ||
      DemoArtworkData.isOverdue(work, now, settings);

  double? _timely(Iterable<_Row> source) {
    final due = source.where(_dueOrReviewed).toList();
    return _rate(due.where(_onTime).length, due.length);
  }

  bool _overdue(_Row work) => DemoArtworkData.isOverdue(work, now, settings);
  bool _leadOverdue(_Row work) =>
      DemoArtworkData.isLeadOverdue(work, now, settings);

  _Row summary() {
    final arrivals = attendance();
    final attentionRows = attention();
    final reviewRows = works.where(_overdue).toList();
    final leadRows = works.where(_leadOverdue).toList();
    final todayCount = _submittedOn(today).length;
    final yesterdayCount = _submittedOn(cbAddDays(today, -1)).length;
    final classIdsInScope = people.keys.toSet();
    final exams = _examTrend(classIdsInScope);
    final classWarnings = <_Row>[];
    for (final classroom in classes) {
      final scores = _examTrend(
        classroom.students.map((student) => student.index).toSet(),
      );
      final recent = scores.reversed
          .take(3)
          .map((row) => row['mean'] as double)
          .toList();
      if (recent.length == 3 &&
          recent[0] < recent[1] &&
          recent[1] < recent[2]) {
        classWarnings.add({
          'label': '${classroom.name}连续两次模考均分下降',
          'target': 'classes',
          'id': classroom.id,
        });
      }
    }
    final activity = <_Row>[
      for (final work in works)
        for (final event in DemoArtworkData.timelineOf(work))
          if (event['type'] != 'SUBMIT')
            {
              ...event,
              'artworkId': cbStr(work['id']),
              'title': cbStr(work['title']),
            },
    ]..sort((a, b) => cbStr(b['time']).compareTo(cbStr(a['time'])));
    final latestWorks = DemoArtworkStore.latestVersions(
      works,
    )..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
    final recentSubjects = <String>{};
    final recentArtworks = <_Row>[];
    for (final work in latestWorks) {
      if (recentSubjects.add(cbStr(work['subject']))) {
        recentArtworks.add(
          DemoArtworkStore.projectSummary(work, request.account),
        );
      }
      if (recentArtworks.length == 3) break;
    }
    return {
      'campuses': [
        for (final c in DemoCampusData.classes)
          {'id': c.id, 'name': c.organizationName},
      ],
      'date': cbDate(today),
      'attendance': {
        for (final key in [
          'studentPresent',
          'studentExpected',
          'teacherPresent',
          'teacherExpected',
        ])
          key: arrivals[key],
      },
      'todaySubmissions': todayCount,
      'yesterdaySubmissions': yesterdayCount,
      'overdueReviews': reviewRows.length,
      'timelyReviewRate': _timely(
        works.where((w) => _recent(w['createTime'], 7)),
      ),
      'overdueLeadReviews': leadRows.length,
      'examMean': exams.lastOrNull?['mean'],
      'examChange': exams.length < 2
          ? null
          : (exams.last['mean'] as double) -
                (exams[exams.length - 2]['mean'] as double),
      'attentionCount': attentionRows.length,
      'alerts': [
        ..._overdueAlerts(reviewRows, 'teacherId', 'overdue', '点评'),
        ..._overdueAlerts(leadRows, 'leaderId', 'leadOverdue', '复核'),
        ...classWarnings,
        for (final row in attentionRows.take(5))
          {
            'label': '${row['name']} · ${(row['reasons'] as List).first}',
            'target': 'attention',
            'id': row['id'],
          },
      ],
      'activity': activity.take(8).toList(),
      'recentArtworks': recentArtworks,
    };
  }

  Iterable<_Row> _overdueAlerts(
    List<_Row> rows,
    String key,
    String target,
    String action,
  ) sync* {
    final counts = <String, int>{};
    for (final work in rows) {
      final lead = DemoArtworkData.leadOf(work);
      final id = cbStr(key == 'leaderId' ? (lead?[key]) : work[key]);
      counts.update(id, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final entry in counts.entries) {
      yield {
        'label':
            '${DemoArtworkData.teacherName(entry.key)}有 ${entry.value} 份作品待$action超时',
        'target': target,
        'id': entry.key,
        'name': DemoArtworkData.teacherName(entry.key),
        'detail': '${entry.value}份作品待$action',
      };
    }
  }

  _Row attendance() {
    final daily = courses.where((course) => course.day == today).toList();
    final expected = <String>{};
    final present = <String>{};
    final expectedTeachers = <String>{};
    final presentTeachers = <String>{};
    for (final course in daily) {
      expectedTeachers.add(course.teacherUserId);
      if (cbStr(_sign(course)['teacherSignInTime']).isNotEmpty) {
        presentTeachers.add(course.teacherUserId);
      }
      for (final id in cbCourseStudents(course)) {
        if (!_hasStudent(id)) continue;
        expected.add(id);
        final status = (_studentSigns(course)[id] as Map?)?['status'];
        if (status == 0 || status == 2) present.add(id);
      }
    }
    return {
      'studentPresent': present.length,
      'studentExpected': expected.length,
      'teacherPresent': presentTeachers.length,
      'teacherExpected': expectedTeachers.length,
      'students': [
        for (final student in students)
          if (expected.contains(student.archiveId) &&
              !present.contains(student.archiveId))
            _studentRow(student),
      ],
      'teachers': [
        for (final staff in DemoCampusData.staff)
          if (expectedTeachers.contains(staff.userId) &&
              !presentTeachers.contains(staff.userId))
            _teacherIdentity(staff),
      ],
    };
  }

  List<_Row> trend(String metric, int days) => [
    for (var i = 1 - days; i <= 0; i++)
      _trendPoint(cbAddDays(today, i), metric),
  ];

  _Row _trendPoint(DateTime day, String metric) {
    final submitted = _submittedOn(day);
    final Object? value;
    switch (metric) {
      case 'timely':
        value = _timely(submitted);
      case 'attendance':
        final expected = <String>{};
        final present = <String>{};
        for (final course in courses.where((course) => course.day == day)) {
          for (final id in cbCourseStudents(course)) {
            if (!_hasStudent(id)) continue;
            expected.add(id);
            final status = (_studentSigns(course)[id] as Map?)?['status'];
            if (status == 0 || status == 2) present.add(id);
          }
        }
        value = _rate(present.length, expected.length);
      default:
        value = submitted.length;
    }
    return {'date': cbDate(day), 'value': value};
  }

  List<_Row> teachers({
    String subject = '',
    List<String> subjects = const [],
  }) => [
    for (final staff in DemoCampusData.staff)
      if (staff.subject.isNotEmpty &&
          staff.classIds.any(classIds.contains) &&
          (subject.isEmpty || staff.subject == subject) &&
          (subjects.isEmpty || subjects.contains(staff.subject)))
        _teacherMetrics(staff),
  ];

  _Row teacherDetail(String id) {
    final staff = DemoCampusData.staffById(id);
    if (staff == null ||
        staff.subject.isEmpty ||
        !staff.classIds.any(classIds.contains)) {
      throw const DemoApiException('没有找到这位老师', code: 404);
    }
    final teacherCourses = courses.where(
      (c) => c.teacherUserId == staff.userId,
    );
    final teacherWorks = _worksForTeacher(staff.id);
    return {
      ..._teacherMetrics(staff),
      'reviews': [
        for (final work
            in teacherWorks.where(DemoArtworkData.isReviewed).take(8))
          DemoArtworkStore.projectSummary(work, request.account),
      ],
      'signs': [
        for (final c in teacherCourses.toList().reversed.take(10))
          {
            'date': c.date,
            'course': c.subjectName,
            'start': c.start,
            'time': _sign(c)['teacherSignInTime'],
          },
      ],
      'trend': [
        for (var i = -6; i <= 0; i++)
          {
            'date': cbDate(cbAddDays(today, i)),
            'value': _timely(
              teacherWorks.where(
                (w) => _date(w['createTime']) == cbDate(cbAddDays(today, i)),
              ),
            ),
          },
      ],
    };
  }

  // 每位任课老师的履职口径只读取其本人的评价，避免合并成绩代替个人完成量。
  List<_Row> _worksForTeacher(String id) => [
    for (final work in works)
      if (DemoArtworkData.assignedTeacherIdsOf(work).contains(id))
        {
          ...work,
          'teacherId': id,
          'teacherIds': [id],
          'review': DemoArtworkData.reviewsOf(
            work,
          ).where((r) => r['teacherId'] == id).firstOrNull,
          'teacherReviews': <_Row>[],
        },
  ];

  _Row _teacherMetrics(DemoCampusStaff staff) {
    final own = _worksForTeacher(staff.id);
    final dueThisWeek = own
        .where((w) => _recent(w['createTime'], 7) && _dueOrReviewed(w))
        .toList();
    final onTimeThisWeek = dueThisWeek.where(_onTime).length;
    final reviewed = own
        .where((w) => _recent(DemoArtworkData.reviewOf(w)?['reviewedTime'], 30))
        .toList();
    final lead = own
        .map(DemoArtworkData.leadOf)
        .whereType<_Row>()
        .where((l) => _recent(l['time'], 30))
        .toList();
    final assigned = tasks
        .where(
          (t) => t['teacherId'] == staff.id && _recent(t['createTime'], 30),
        )
        .toList();
    final assignedIds = assigned.map((t) => t['id']).toSet();
    final submitted = DemoArtworkStore.latestVersions(
      own.where((w) => assignedIds.contains(w['taskId'])).toList(),
    );
    final teacherCourses = courses
        .where((c) => c.teacherUserId == staff.userId)
        .toList();
    final recentCourses = teacherCourses
        .where((c) => _recent(c.startAt, 7))
        .toList();
    final punctual = recentCourses.where((c) {
      final signTime = DemoArtworkData.parseTime(_sign(c)['teacherSignInTime']);
      return signTime != null &&
          !signTime.isAfter(c.startAt.add(const Duration(minutes: 10)));
    }).length;
    final subjectId = DemoMarkingData.subjectIds[staff.subject];
    final classStudents = students
        .where(
          (s) =>
              staff.classIds.contains(DemoCampusData.classOfPerson(s.index).id),
        )
        .map((s) => s.index)
        .toSet();
    final scores = subjectId == null
        ? const <_Row>[]
        : _examTrend(classStudents, subjectId: subjectId);
    return {
      ..._teacherIdentity(staff),
      'timely': _rate(onTimeThisWeek, dueThisWeek.length),
      'dueThisWeek': dueThisWeek.length,
      'onTimeThisWeek': onTimeThisWeek,
      'quality': _mean(
        lead.map((l) => l['qualityStars']).whereType<num>().where((n) => n > 0),
      ),
      'reviewSampleCount': reviewed.length,
      'qualitySampleCount': lead
          .where((l) => (l['qualityStars'] as num? ?? 0) > 0)
          .length,
      'commentLength': _mean(
        reviewed.map(
          (w) => cbStr(DemoArtworkData.reviewOf(w)?['content']).runes.length,
        ),
      ),
      'annotationRate': _rate(
        reviewed
            .where(
              (w) => DemoArtworkStore.hasAnnotations(cbStr(w['id']), staff.id),
            )
            .length,
        reviewed.length,
      ),
      'dimensionRate': _rate(
        reviewed
            .where(
              (w) =>
                  (DemoArtworkData.mapOf(
                        DemoArtworkData.reviewOf(w)?['dimensions'],
                      )?.length ??
                      0) ==
                  4,
            )
            .length,
        reviewed.length,
      ),
      'punctual': _rate(punctual, recentCourses.length),
      'taskCount': subjectId == null ? null : assigned.length,
      'taskReviewRate': _rate(
        submitted.where(DemoArtworkData.isReviewed).length,
        submitted.length,
      ),
      'scoreChange': scores.length < 2
          ? null
          : (scores.last['mean'] as double) -
                (scores[scores.length - 2]['mean'] as double),
      'adjustRate': _rate(
        lead.where((l) => l['action'] == 'ADJUST').length,
        lead.length,
      ),
      'adjustAverage': _mean([
        for (final work in own)
          if (DemoArtworkData.leadOf(work) case final review?
              when review['action'] == 'ADJUST' &&
                  _recent(review['time'], 30) &&
                  DemoArtworkData.reviewOf(work)?['score'] is num &&
                  review['score'] is num)
            (review['score'] as num) -
                (DemoArtworkData.reviewOf(work)!['score'] as num),
      ]),
      'reviewCount': own
          .where(
            (w) => _recent(DemoArtworkData.reviewOf(w)?['reviewedTime'], 7),
          )
          .length,
    };
  }

  List<_Row> _examTrend(Set<int> indices, {String? subjectId}) {
    return [
      for (final exam in marking.exams.where((exam) => exam.reviewed))
        if (_mean(
              marking
                  .entriesOfExam(exam.examId)
                  .where((e) => e.scored && indices.contains(e.person.index))
                  .map(
                    (e) => subjectId == null
                        ? e.total
                        : e.subject(subjectId)?.score,
                  )
                  .whereType<num>(),
            )
            case final mean?)
          {
            'id': exam.examId,
            'name': exam.examName,
            'date': exam.examDate,
            'mean': mean,
          },
    ]..sort((a, b) => cbStr(a['date']).compareTo(cbStr(b['date'])));
  }

  List<_Row> classResults({
    List<String> subjects = const [],
    bool includeStudents = true,
  }) => [
    for (final c in classes)
      {
        'id': c.id,
        'name': c.name,
        'campus': c.organizationName,
        'exams': _examTrend(
          c.students.map((s) => s.index).toSet(),
          subjectId: DemoMarkingData.subjectIds[subjects.firstOrNull],
        ),
        if (includeStudents)
          'students': [
            for (final student in c.students.where(cbIsActive))
              _studentRow(student),
          ],
        'dimensions': DemoArtworkData.insightsOf(
          works
              .where(
                (w) =>
                    (subjects.isEmpty ||
                        subjects.contains(cbStr(w['subject']))) &&
                    c.students.any(
                      (s) => s.index == DemoArtworkData.personOf(w),
                    ),
              )
              .toList(),
          now,
        )['dimensionLevels'],
      },
  ];

  List<_Row> teacherStudents(String id) {
    final teacher = DemoCampusData.staffById(id);
    return [
      for (final student in students)
        if (teacher?.classIds.contains(
              DemoCampusData.classOfPerson(student.index).id,
            ) ==
            true)
          {..._studentRow(student), 'previewSubject': teacher?.subject},
    ];
  }

  List<_Row> attention({String? teacherId}) {
    final result = <_Row>[];
    final previousDays = <String>[];
    for (var day = today; previousDays.length < 3; day = cbAddDays(day, -1)) {
      if (day.weekday != DateTime.sunday && (day != today || now.hour >= 21)) {
        previousDays.add(cbDate(day));
      }
    }
    final absenceCount = <String, int>{};
    for (final course in courses.where((c) => _recent(c.startAt, 7))) {
      for (final entry in _studentSigns(course).entries) {
        if (entry.value is Map && (entry.value as Map)['status'] == 1) {
          absenceCount.update(
            entry.key,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }
    for (final student in students) {
      final classroom = DemoCampusData.classOfPerson(student.index);
      final assigned = DemoCampusData.timetableOf(
        classroom.id,
      ).map((slot) => slot.teacherId).toSet();
      if (teacherId != null && !assigned.contains(teacherId)) continue;
      final studentWorks = works
          .where((work) => DemoArtworkData.personOf(work) == student.index)
          .toList();
      final latest = marking
          .entriesOf(student.index)
          .where((e) => e.totalRanking != null)
          .toList();
      final ranks = latest.length < 2
          ? 0
          : latest.last.totalRanking! - latest[latest.length - 2].totalRanking!;
      final tags = _repeatedProblems(studentWorks);
      final missed = absenceCount[student.archiveId] ?? 0;
      final reasons = <String>[
        if (ranks >= 5) '两次模考之间总排名下降 $ranks 名',
        if (!studentWorks.any(
          (work) => previousDays.contains(_date(work['createTime'])),
        ))
          '连续 3 个在校日未提交作品',
        for (final tag in tags) '「$tag」连续 3 次出现',
        if (missed >= 2) '近 7 天缺勤 $missed 次',
      ];
      if (reasons.isEmpty) continue;
      final responsible = teacherId ?? classroom.headTeacherId;
      result.add({
        ..._studentRow(student),
        'reasons': reasons,
        'teacher': DemoCampusData.staffById(responsible)?.name ?? '',
      });
    }
    return result;
  }

  Set<String> _repeatedProblems(List<_Row> studentWorks) {
    final result = <String>{};
    for (final subject in DemoArtworkData.subjects) {
      final reviews = studentWorks
          .where(
            (w) => w['subject'] == subject && DemoArtworkData.isReviewed(w),
          )
          .take(3)
          .map(DemoArtworkData.reviewOf)
          .whereType<_Row>()
          .toList();
      if (reviews.length != 3) continue;
      Set<String> problems(_Row review) => {
        for (final tag in DemoArtworkData.tagsOf(review))
          if (!DemoArtworkData.isHighlightTag(
            cbStr(tag['name']),
            cbStr(tag['color']),
          ))
            cbStr(tag['name']),
      };
      final fixed = {
        for (final review in reviews)
          for (final resolution in DemoArtworkData.mapsOf(
            review['tagResolutions'],
          ))
            if (resolution['resolved'] == true) cbStr(resolution['tag']),
      };
      result.addAll(
        reviews
            .map(problems)
            .reduce((a, b) => a.intersection(b))
            .difference(fixed),
      );
    }
    return result;
  }

  _Row reviewChain({
    String date = '',
    String filter = '',
    String teacherId = '',
  }) {
    final rows = works.where((work) {
      if (date.isNotEmpty && _date(work['createTime']) != date) return false;
      final responsible = filter == 'leadOverdue'
          ? (DemoArtworkData.leadOf(work)?['leaderId'])
          : work['teacherId'];
      if (teacherId.isNotEmpty && teacherId != responsible) return false;
      return switch (filter) {
        'overdue' => _overdue(work),
        'leadOverdue' => _leadOverdue(work),
        _ => true,
      };
    }).toList();
    final page = request.intOf('current', 1).clamp(1, 1000);
    const size = 24;
    return {
      'date': date,
      'dates': [for (var i = -13; i <= 0; i++) cbDate(cbAddDays(today, i))],
      'total': rows.length,
      'reviewed': rows.where(DemoArtworkData.isReviewed).length,
      'inReview': rows
          .where((w) => DemoArtworkData.leadStatusOf(w) == 'IN_REVIEW')
          .length,
      'done': rows
          .where((w) => DemoArtworkData.leadStatusOf(w) == 'DONE')
          .length,
      'overdue': rows.where(_overdue).length,
      'leadOverdue': rows.where(_leadOverdue).length,
      'current': page,
      'size': size,
      'records': [
        for (final row in rows.skip((page - 1) * size).take(size))
          DemoArtworkStore.projectSummary(row, request.account),
      ],
    };
  }

  _Row _studentRow(DemoPerson person) {
    final classroom = DemoCampusData.classOfPerson(person.index);
    final examRows = marking
        .entriesOf(person.index)
        .where((e) => e.scored)
        .toList();
    final goal = CompositeEstimateForm.fromJson(
      DemoStore.map(_goalKey(person.index), () => {}),
    );
    final latest = examRows.lastOrNull;
    final studentWorks = works
        .where((work) => DemoArtworkData.personOf(work) == person.index)
        .toList();
    final insights = DemoArtworkData.insightsOf(studentWorks, now);
    final estimate = estimateComposite(
      province: goal.province,
      professionalScore: latest?.total,
      professionalFull: latest?.exam.fullScore,
      culture: goal.culture,
      target: goal.target,
    );
    return {
      'id': person.archiveId,
      'name': person.name,
      'className': classroom.name,
      'campus': person.organizationName,
      'exams': [
        for (final entry in examRows)
          {
            'name': entry.exam.examName,
            'date': entry.exam.examDate,
            'mean': entry.total,
            'rank': entry.totalRanking,
          },
      ],
      'workCount': studentWorks.length,
      'latestWork': studentWorks.firstOrNull?['createTime'],
      'latestWorkId': studentWorks.firstOrNull?['id'],
      'followUp': DemoStore.map(
        'teaching:follow-up:${person.archiveId}',
        () => {},
      ),
      'subjectInsights': insights['dimensionLevels'],
      'dimensions': insights['dimensionLevels'],
      'unresolvedCount':
          ((insights['problemTagCount'] as int) -
                  (insights['resolvedTagCount'] as int))
              .clamp(0, 1000000),
      'works': [
        for (final work in studentWorks.take(6))
          if (DemoArtworkData.accessOf(request.account, work).canRead)
            DemoArtworkStore.projectSummary(work, request.account),
      ],
      'goalTarget': estimate.target,
      'goalGap': estimate.gap,
    };
  }
}

_Row _teacherIdentity(DemoCampusStaff staff) => {
  'id': staff.id,
  'name': staff.name,
  'subject': staff.subject,
  'campus': staff.organizationName,
};

String _date(Object? time) {
  final parsed = DemoArtworkData.parseTime(time);
  return parsed == null ? '' : cbDate(parsed);
}

double? _rate(int count, int total) => total == 0 ? null : count * 100 / total;

double? _mean(Iterable<num> values) {
  var total = 0.0;
  var count = 0;
  for (final value in values) {
    total += value;
    count++;
  }
  return count == 0 ? null : total / count;
}
