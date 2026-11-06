/// 智慧校园演示数据：学生档案（名册行 / 详情）、班主任备注标签、人脸库、
/// 考试成绩（来自阅卷演示数据，老师在考评管理里的打分优先）。
library;

import '../../data/demo_campus_data.dart';
import '../../data/demo_marking_data.dart';
import '../../demo_store.dart';
import 'campus_b_common.dart';

// ── 班主任备注与标签 ──────────────────────────────────────────────────

const String cbProfilesKey = 'campus_b:student_profiles';

Map<String, dynamic> _seedProfiles() => <String, dynamic>{
  '900001': {'tags': '素描尖子', 'remark': '素描结构扎实，色彩冷暖关系还需加强；目标西安美院油画系。'},
  '900002': {'tags': '色彩稳定', 'remark': '速写手部刻画偏弱，周末加练手部速写。'},
  '900003': {'tags': '班长,色彩薄弱', 'remark': '色彩画面偏灰，已安排每周两张小色稿加练。'},
  '900006': {'tags': '学习委员', 'remark': '作业完成度高，可协助老师收发作业。'},
  '900009': {'tags': '画室管理员,住校适应期', 'remark': '刚从外地转来，晚上偶尔想家，班主任每周谈心一次。'},
  '900012': {'tags': '宣传委员,速写进步快', 'remark': ''},
  '900015': {'tags': '文化课薄弱', 'remark': '英语成绩偏低，已请孙磊老师晚自习辅导。'},
  '900038': {
    'tags': '休学',
    'remark': '10 月底手腕骨折办理休学，预计 12 月复课。',
    'lastChange': '2026-10-28 办理休学',
  },
};

Map<String, dynamic> _profiles() => DemoStore.map(cbProfilesKey, _seedProfiles);

Map<String, dynamic> cbProfileOf(String studentId) {
  final raw = _profiles()[studentId];
  return raw is Map ? raw.map((k, v) => MapEntry(k.toString(), v)) : {};
}

void cbUpdateProfile(String studentId, Map<String, dynamic> changes) {
  final store = _profiles();
  final current = cbProfileOf(studentId)..addAll(changes);
  store[studentId] = current;
  DemoStore.save(cbProfilesKey);
}

// ── 学生档案 ──────────────────────────────────────────────────────────

/// 目标院校与班级职务和学生端资料保持一致。
const List<String> _targetSchools = [
  '中国美术学院',
  '西安美术学院',
  '四川美术学院',
  '中央美术学院',
  '广州美术学院',
  '湖北美术学院',
  '鲁迅美术学院',
  '天津美术学院',
  '西北师范大学美术学院',
  '清华大学美术学院',
];

const Map<int, String> _classRoles = {
  3: '班长',
  6: '学习委员',
  9: '画室管理员',
  12: '宣传委员',
  4: '班长',
  7: '学习委员',
  5: '班长',
  8: '画室管理员',
};

String cbTargetSchool(DemoPerson p) => p.index == 1
    ? '西安美术学院'
    : _targetSchools[(p.index * 3) % _targetSchools.length];

/// 最近一次有成绩的考试里得分最高的科目。
String cbStrongSubject(DemoPerson p) {
  final entries = DemoMarkingData.instance
      .entriesOf(p.index)
      .where((e) => e.scored);
  if (entries.isEmpty) {
    return '素描';
  }
  final latest = entries.last;
  DemoSubjectScore? best;
  for (final s in latest.subjects!) {
    if (best == null || s.score > best.score) {
      best = s;
    }
  }
  return best?.def.subjectName ?? '素描';
}

Map<String, dynamic> cbStudentRow(DemoPerson p) {
  final home = cbHomeClassOf(p);
  final profile = cbProfileOf(p.archiveId);
  final parents = cbParentsOf(p);
  final bedInfo = cbBedInfo(p);
  final face = cbLatestFace(cbStudentUserId(p));
  final route = cbStr(home?['id']) == '503' ? '校考' : '联考';
  final target = cbTargetSchool(p);
  final className = cbStr(home?['name']);
  final classRole = _classRoles[p.index];
  return <String, dynamic>{
    'id': p.archiveId,
    'studentId': p.archiveId,
    'archiveId': p.archiveId,
    'userId': cbStudentUserId(p),
    'realname': p.name,
    'nickname': p.name,
    'no': cbStudentNo(p),
    'studentNo': cbStudentNo(p),
    'gender': p.gender,
    'mobile': p.phone,
    'phone': p.phone,
    'idCard': p.idCardMasked,
    'headUrl': cbUrl(p.avatarRef),
    'classId': cbStr(home?['id']),
    'className': className,
    'bigClass': <String, dynamic>{'id': cbStr(home?['id']), 'name': className},
    'classRole': ?classRole,
    'campusName': p.organizationName,
    'bedId': cbBedId(p),
    'bedInfo': bedInfo,
    'dormitory': bedInfo,
    'parentName': parents.first['name'],
    'parentRelation': parents.first['relation'],
    'parentMobile': parents.first['mobile'],
    'parentPhone': parents.first['mobile'],
    'guardianName': parents.first['name'],
    'guardianMobile': parents.first['mobile'],
    'studentStatus': cbStudentStatus(p),
    'tags': cbStr(profile['tags']),
    'remark': cbStr(profile['remark']),
    'lastChange': cbStr(profile['lastChange'], '无'),
    'majorName': '美术',
    'major': '美术$route',
    'directionName': '$route · ${cbStrongSubject(p)}见长',
    'fullMajor': '美术$route · ${p.organizationName}',
    'introduce': '目标院校：$target',
    'targetSchool': target,
    'faceImg': face == null ? '' : cbUrl(cbStr(face['faceImg'])),
  };
}

/// 学生详情：同时给出嵌套结构（user / schoolStudent / dormitoryUser /
/// parents）与扁平字段，班主任工作台、学生名册与管理员学籍档案各取所需。
Map<String, dynamic> cbStudentDetail(DemoPerson p) {
  final row = cbStudentRow(p);
  final parents = cbParentsOf(p);
  return <String, dynamic>{
    ...row,
    'user': <String, dynamic>{
      'id': cbStudentUserId(p),
      'realname': p.name,
      'nickname': p.name,
      'gender': p.gender,
      'mobile': p.phone,
      'headUrl': row['headUrl'],
      'targetSchool': row['targetSchool'],
      'introduce': row['introduce'],
    },
    'schoolStudent': <String, dynamic>{
      'id': p.archiveId,
      'no': row['no'],
      'studentNo': row['no'],
      'tags': row['tags'],
      'remark': row['remark'],
      'studentStatus': row['studentStatus'],
      'gender': p.gender,
      'classId': row['classId'],
    },
    'schoolClass': <String, dynamic>{
      'id': row['classId'],
      'name': row['className'],
    },
    'dormitoryUser': <String, dynamic>{
      'bedId': row['bedId'],
      'bedInfo': row['bedInfo'],
    },
    'parents': [
      for (final parent in parents)
        <String, dynamic>{
          'nickname': parent['name'],
          'realname': parent['name'],
          'relation': parent['relation'],
          'mobile': parent['mobile'],
        },
    ],
    'guardian2Name': parents.last['name'],
    'guardian2Relation': parents.last['relation'],
    'guardian2Mobile': parents.last['mobile'],
    'emergencyContact': '${parents.first['name']} ${parents.first['mobile']}',
  };
}

// ── 人脸库 ────────────────────────────────────────────────────────────

const String cbFacesKey = 'campus_b:faces';

const Set<int> _faceMissing = {7, 22, 35, 40};
const Set<int> _facePending = {5, 14, 27};
const Map<int, String> _faceRejected = {
  11: '照片模糊，请在光线充足处重新拍摄正脸照',
  33: '佩戴帽子遮挡额头，请摘帽后重拍',
};

List<Map<String, dynamic>> _seedFaces() {
  final result = <Map<String, dynamic>>[];
  var seq = 1;
  for (final p in cbPersons) {
    if (_faceMissing.contains(p.index)) {
      continue;
    }
    final pending = _facePending.contains(p.index);
    final rejected = _faceRejected[p.index];
    final status = pending ? 0 : (rejected != null ? 2 : 1);
    final created = pending
        ? cbRel(-(p.index % 2), '16:${cbTwo(10 + p.index)}')
        : cbRel(-(66 - p.index), '15:${cbTwo(p.index)}');
    result.add(<String, dynamic>{
      'id': '38${seq.toString().padLeft(5, '0')}',
      'userId': cbStudentUserId(p),
      'userType': 'student',
      'faceImg': p.gender == '女'
          ? 'asset:assets/demo/avatars/student_female.png'
          : 'asset:assets/demo/avatars/student_male.png',
      'status': status,
      'reason': rejected ?? (status == 1 ? '通过' : ''),
      'createTime': cbDateTime(created),
      'updateTime': cbDateTime(created),
      'auditTime': status == 0
          ? null
          : cbDateTime(created.add(const Duration(hours: 20))),
      'auditUserName': status == 0 ? null : '王敏',
    });
    seq++;
  }
  for (final (staffId, status) in const [
    ('t-1', 1),
    ('t-3', 1),
    ('t-4', 1),
    ('t-5', 1),
    ('d-1', 1),
    ('t-2', 0),
  ]) {
    final staff = DemoCampusData.staffById(staffId)!;
    final created = status == 0 ? cbRel(0, '09:12') : cbRel(-58, '11:30');
    result.add(<String, dynamic>{
      'id': '38${seq.toString().padLeft(5, '0')}',
      'userId': staff.userId,
      'userType': 'teacher',
      'faceImg': staff.gender == '女'
          ? 'asset:assets/demo/avatars/student_female.png'
          : 'asset:assets/demo/avatars/student_male.png',
      'status': status,
      'reason': status == 1 ? '通过' : '',
      'createTime': cbDateTime(created),
      'updateTime': cbDateTime(created),
      'auditTime': status == 0
          ? null
          : cbDateTime(created.add(const Duration(hours: 3))),
      'auditUserName': status == 0 ? null : '王敏',
    });
    seq++;
  }
  return result;
}

List<Map<String, dynamic>> cbFaces() => DemoStore.list(cbFacesKey, _seedFaces);

void cbSaveFaces() => DemoStore.save(cbFacesKey);

/// 用户最新一条人脸记录（同一用户以最近提交为准）。
Map<String, dynamic>? cbLatestFace(String userId) {
  Map<String, dynamic>? latest;
  for (final f in cbFaces()) {
    if (cbStr(f['userId']) != userId) {
      continue;
    }
    if (latest == null ||
        cbStr(f['updateTime']).compareTo(cbStr(latest['updateTime'])) > 0) {
      latest = f;
    }
  }
  return latest;
}

Map<String, dynamic> cbFaceJson(Map<String, dynamic> record) {
  final userId = cbStr(record['userId']);
  final student = cbPerson(userId);
  final staff = student == null ? cbStaff(userId) : null;
  return <String, dynamic>{
    ...record,
    'faceImg': cbUrl(cbStr(record['faceImg'])),
    'realname': student?.name ?? staff?.name ?? '未命名',
    'nickname': student?.name ?? staff?.name ?? '',
    'no': student != null
        ? cbStudentNo(student)
        : (staff == null ? '' : cbStaffNo(staff)),
    'className': student != null
        ? cbStr(cbHomeClassOf(student)?['name'], '未分班')
        : '教职工',
    'studentStatus': student != null ? cbStudentStatus(student) : '在职',
    'gender': student?.gender ?? staff?.gender ?? '',
    'headUrl': student == null ? '' : cbUrl(student.avatarRef),
  };
}

/// 尚未录入人脸的在籍学生数。
int cbFaceMissingCount() {
  final recorded = {for (final f in cbFaces()) cbStr(f['userId'])};
  return cbPersons
      .where((p) => cbIsActive(p) && !recorded.contains(cbStudentUserId(p)))
      .length;
}

// ── 考试成绩 ──────────────────────────────────────────────────────────

const String cbExamScoresKey = 'campus_b:exam_scores';

Map<String, dynamic> _examScores() =>
    DemoStore.map(cbExamScoresKey, () => <String, dynamic>{});

Map<String, dynamic>? cbExamOverride(
  String examId,
  String subjectId,
  String studentId,
) {
  final raw = _examScores()['$examId|$subjectId|$studentId'];
  return raw is Map ? raw.map((k, v) => MapEntry(k.toString(), v)) : null;
}

void cbSetExamScore({
  required String examId,
  required String subjectId,
  required String studentId,
  required num score,
  String comment = '',
  String path = '',
}) {
  _examScores()['$examId|$subjectId|$studentId'] = <String, dynamic>{
    'score': score,
    'comment': comment,
    'path': path,
    'time': cbDateTime(DateTime.now()),
  };
  DemoStore.save(cbExamScoresKey);
}

/// 科目最终分：考评管理里的打分优先，其次阅卷演示数据；无成绩返回 null。
double? cbSubjectScore(DemoExamEntry entry, DemoSubjectDef def) {
  final override = cbExamOverride(
    entry.exam.examId,
    def.subjectId,
    entry.person.archiveId,
  );
  if (override != null) {
    return cbNum(override['score']);
  }
  return entry.subject(def.subjectId)?.score;
}

String cbSubjectComment(DemoExamEntry entry, DemoSubjectDef def) {
  final override = cbExamOverride(
    entry.exam.examId,
    def.subjectId,
    entry.person.archiveId,
  );
  final overrideComment = cbStr(override?['comment']);
  if (overrideComment.isNotEmpty) {
    return overrideComment;
  }
  final result = entry.subject(def.subjectId)?.result;
  if (result == null) {
    return '';
  }
  if (result.comments.isNotEmpty) {
    return result.comments.join('；');
  }
  return DemoMarkingData.commentFor(def.subjectName, entry.person.index, 0);
}

/// 学生历次考试成绩（新到旧），班主任 / 任课老师 / 管理员共用。
List<Map<String, dynamic>> cbStudentExamRecords(DemoPerson p) {
  final home = cbHomeClassOf(p);
  final result = <Map<String, dynamic>>[];
  for (final entry in DemoMarkingData.instance.entriesOf(p.index).reversed) {
    final subjects = <Map<String, dynamic>>[];
    var total = 0.0;
    var pass = 0;
    var excellent = 0;
    for (final def in entry.exam.subjects) {
      final score = cbSubjectScore(entry, def);
      if (score == null) {
        continue;
      }
      final s = entry.subject(def.subjectId);
      total += score;
      if (score >= 60) {
        pass++;
      }
      if (score >= 85) {
        excellent++;
      }
      final teacher = cbSubjectTeacherOf(home?['id'], def.subjectName);
      subjects.add(<String, dynamic>{
        'subjectId': int.parse(def.subjectId),
        'subjectName': def.subjectName,
        'score': score,
        'fullScore': def.fullScore,
        'grade':
            s?.grade ??
            DemoMarkingData.gradeOf(score, DemoMarkingData.bandsFor(def)),
        'classRank': s?.organizationRanking ?? 0,
        'schoolRank': s?.ranking ?? 0,
        'comment': cbSubjectComment(entry, def),
        'path': cbUrl(
          DemoMarkingData.paperRef(def.subjectName, p.index, entry.exam.examId),
        ),
        'headUrl': '',
        'nickname': teacher,
        'teacherName': teacher,
      });
    }
    if (subjects.isEmpty) {
      continue;
    }
    result.add(<String, dynamic>{
      'examId': entry.exam.examId,
      'examName': entry.exam.examName,
      'examDate': entry.exam.examDate,
      'totalScore': cbRoundTo(total, 2),
      'fullScore': entry.exam.fullScore,
      'passSubjectCount': pass,
      'excellentSubjectCount': excellent,
      'classRank': entry.organizationRanking ?? 0,
      'schoolRank': entry.totalRanking ?? 0,
      'classTotal': DemoMarkingData.instance.participantCount(
        entry.exam.examId,
        p.organizationName,
      ),
      'schoolTotal': DemoMarkingData.instance.participantCount(
        entry.exam.examId,
      ),
      'teacherNames': [
        for (final s in subjects) '${s['teacherName']}（${s['subjectName']}）',
      ].join('、'),
      'subjectScores': subjects,
    });
  }
  return result;
}
