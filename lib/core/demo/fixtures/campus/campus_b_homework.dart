/// 智慧校园作品由作品库中的任务及其当前提交版本生成。
library;

import '../../data/demo_artwork_data.dart';
import '../../data/demo_artwork_store.dart';
import '../../data/demo_campus_data.dart';
import '../../data/demo_marking_data.dart';
import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import 'campus_b_common.dart';

typedef _Row = Map<String, dynamic>;

List<Map<String, dynamic>> studentArtworkHomework(DemoAccount account) {
  final person = account.personIndex;
  if (person == null) return [];
  final classroom = DemoArtworkData.classOf(person);
  final records = _latestSubmissions(person: person);
  return [
    for (final task in DemoArtworkStore.tasks())
      if (cbStrList(task['classIds']).contains(classroom.id))
        {
          ..._taskRow(task, classId: classroom.id),
          ..._studentRecord(task, person, records[(cbStr(task['id']), person)]),
          'id': task['id'],
          'homeworkStudentId': task['id'],
          'className': classroom.name,
          'teacherName': DemoArtworkData.teacherName(cbStr(task['teacherId'])),
          'studentDescription':
              records[(cbStr(task['id']), person)]?['description'] ?? '',
          'description': task['requirement'],
        },
  ];
}

List<Map<String, dynamic>> cbHomework() => [
  for (final task in DemoArtworkStore.tasks()) _taskRow(task),
];

Map<String, dynamic>? cbHomeworkById(Object? rawId) {
  final task = DemoArtworkStore.taskById(cbStr(rawId));
  return task == null ? null : _taskRow(task);
}

List<Map<String, dynamic>> cbRecordsOf(Object? rawId) {
  final id = cbStr(rawId);
  final task = DemoArtworkStore.taskById(id);
  if (task == null) return [];
  final records = _latestSubmissions(taskId: id);
  return [
    for (final student in cbStrList(
      task['classIds'],
    ).expand(cbActiveStudents).toSet())
      if (cbPerson(student) case final person?)
        _studentRecord(task, person.index, records[(id, person.index)]),
  ];
}

Map<(String, int), _Row> _latestSubmissions({int? person, String? taskId}) {
  final result = <(String, int), _Row>{};
  for (final work in DemoArtworkStore.works()) {
    final index = DemoArtworkData.personOf(work);
    final id = cbStr(work['taskId']);
    if (id.isEmpty ||
        (person != null && index != person) ||
        (taskId != null && taskId != id)) {
      continue;
    }
    final key = (id, index);
    final old = result[key];
    if (old == null ||
        DemoArtworkData.versionOf(work) > DemoArtworkData.versionOf(old)) {
      result[key] = work;
    }
  }
  return result;
}

_Row _taskRow(_Row task, {String? classId}) {
  final subject = cbStr(task['subject']);
  return {
    'id': task['id'],
    'title': task['title'],
    'description': task['requirement'],
    'classIds': task['classIds'],
    'classId': classId ?? cbStrList(task['classIds']).firstOrNull ?? '',
    'subjectId': DemoMarkingData.subjectIds[subject],
    'subjectName': subject,
    'teacherUserId': DemoCampusData.staffById(cbStr(task['teacherId']))?.userId,
    'expectedExt': 'image',
    'createTime': task['createTime'],
    'endTime': task['dueTime'],
    'referenceWorkId': task['referenceWorkId'],
  };
}

_Row _studentRecord(_Row task, int person, _Row? work) {
  final review = work == null ? null : DemoArtworkData.reviewOf(work);
  return {
    'id': '${task['id']}:$person',
    'homeworkId': task['id'],
    'studentId': '${900000 + person}',
    'artworkId': work?['id'],
    'status': work == null
        ? 0
        : review == null
        ? 1
        : 2,
    'submitTime': work?['createTime'],
    'studentParam1': work == null
        ? ''
        : DemoArtworkData.imagesOf(work).firstOrNull?['ref'] ?? '',
    'studentParam2': work == null ? '' : '${work['title']}.jpg',
    'description': work?['description'],
    'score': work == null ? null : DemoArtworkData.finalScoreOf(work),
    'feedback': review?['content'],
    'teacherParam1': review?['voiceRef'],
    'teacherParam2': review?['voiceSeconds'],
    'correctTime': review?['reviewedTime'],
  };
}

Future<List<String>> cbCreateHomework(
  DemoRequest request, {
  required List<String> classIds,
  required String subject,
}) async {
  const path = '/school/teacher/tasks';
  final endpoint = DemoBackend.marking.match('POST', path)!;
  final result = await endpoint.handler(
    DemoRequest(
      method: 'POST',
      path: path,
      query: const {},
      body: {
        'classIds': classIds,
        'subject': subject,
        'title': request.str('title'),
        'requirement': request.str('description'),
        'dueTime': request.str('endTime'),
        'referenceWorkId': request.str('referenceWorkId'),
      },
      headers: request.headers,
    ),
  );
  return [cbStr(result)];
}

void cbDeleteHomework(String id) => DemoArtworkStore.deleteTask(id);

Map<String, dynamic>? cbRecordById(Object? rawId) {
  final id = cbStr(rawId);
  final separator = id.lastIndexOf(':');
  if (separator < 0) return null;
  return cbRecordsOf(
    id.substring(0, separator),
  ).where((record) => record['id'] == id).firstOrNull;
}

int cbHomeworkStatus(Map<String, dynamic> hw) {
  final end = cbParse(hw['endTime']);
  return end != null && end.isAfter(DemoArtworkStore.now()) ? 0 : 1;
}

({int unsubmitted, int pending, int reviewed}) cbHomeworkCounts(
  Map<String, dynamic> hw,
) {
  var unsubmitted = 0;
  var pending = 0;
  var reviewed = 0;
  for (final r in cbRecordsOf(hw['id'])) {
    switch (cbInt(r['status'])) {
      case 1:
        pending++;
      case 2:
        reviewed++;
      default:
        unsubmitted++;
    }
  }
  return (unsubmitted: unsubmitted, pending: pending, reviewed: reviewed);
}

Map<String, dynamic> cbRecordJson(
  Map<String, dynamic> record,
  Map<String, dynamic> hw,
) {
  final p = cbPerson(record['studentId']);
  final file = cbStr(record['studentParam1']);
  final voice = cbStr(record['teacherParam1']);
  return <String, dynamic>{
    'id': cbStr(record['id']),
    'homeworkId': cbStr(record['homeworkId']),
    'artworkId': record['artworkId'],
    'studentId': cbStr(record['studentId']),
    'status': cbInt(record['status']),
    'studentInfo': <String, dynamic>{
      'id': cbStr(record['studentId']),
      'realname': p?.name ?? '',
      'nickname': p?.name ?? '',
      'headUrl': p == null ? '' : cbUrl(p.avatarRef),
      'studentNo': p == null ? '' : cbStudentNo(p),
    },
    'realname': p?.name ?? '',
    'submitTime': record['submitTime'],
    'createTime': hw['createTime'],
    'expectedExt': hw['expectedExt'],
    'subjectName': hw['subjectName'],
    if (file.isNotEmpty) 'fileUrl': cbUrl(file),
    if (file.isNotEmpty) 'studentParam1': cbUrl(file),
    if (file.isNotEmpty) 'fileName': record['studentParam2'],
    'studentParam2': cbStr(record['studentParam2']),
    'studentParam3': cbStr(record['studentParam3']),
    'description': cbStr(record['description']),
    'fileSize': record['fileSize'],
    'score': record['score'],
    'feedback': record['feedback'],
    'teacherParam1': voice.isEmpty ? '' : cbUrl(voice),
    'teacherParam2': cbStr(record['teacherParam2']),
    'teacherParam3': cbStr(record['teacherParam3']),
    'correctTime': record['correctTime'],
  };
}

Map<String, dynamic> cbHomeworkJson(
  Map<String, dynamic> hw, {
  bool withStudents = false,
}) {
  final counts = cbHomeworkCounts(hw);
  final total = counts.unsubmitted + counts.pending + counts.reviewed;
  final classId = cbStr(hw['classId']);
  final className = cbClassName(classId);
  final teacherName = cbStaffName(hw['teacherUserId']);
  final result = <String, dynamic>{
    'id': cbStr(hw['id']),
    'title': cbStr(hw['title']),
    'description': cbStr(hw['description']),
    'classId': classId,
    'classIds': hw['classIds'],
    'className': className,
    'classInfo': <String, dynamic>{'id': classId, 'name': className},
    'subjectId': cbInt(hw['subjectId'], 38),
    'subjectName': cbStr(hw['subjectName']),
    'expectedExt': cbStr(hw['expectedExt']),
    'referenceWorkId': hw['referenceWorkId'],
    'teacherId': cbStr(hw['teacherUserId']),
    'teacherName': teacherName,
    'createTime': hw['createTime'],
    'endTime': hw['endTime'],
    'status': cbHomeworkStatus(hw),
    'homeworkCount': <String, dynamic>{
      'status0': counts.unsubmitted,
      'status1': counts.pending,
      'status2': counts.reviewed,
    },
    'totalCount': total,
    'submitCount': counts.pending + counts.reviewed,
    'pendingCount': counts.pending,
    'reviewedCount': counts.reviewed,
  };
  if (withStudents) {
    const order = {1: 0, 2: 1, 0: 2};
    final records = [...cbRecordsOf(hw['id'])]
      ..sort((a, b) {
        final byStatus = (order[cbInt(a['status'])] ?? 3).compareTo(
          order[cbInt(b['status'])] ?? 3,
        );
        if (byStatus != 0) {
          return byStatus;
        }
        return cbStr(a['submitTime']).compareTo(cbStr(b['submitTime']));
      });
    result['studentList'] = [for (final r in records) cbRecordJson(r, hw)];
  }
  return result;
}
