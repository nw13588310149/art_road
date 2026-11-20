import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/snowflake_id.dart';
import '../../../core/providers/app_providers.dart';

/// 任课老师端相关接口的 Repository。
///
/// 全部为 `POST /app/school/v2/teacher/*`，对应后端 Swagger 中的
/// **v2 智慧校园-任课老师端 (App School V2 Teacher Controller)**。
/// 头部 `app-token` / `schoolId` 由 [ApiClient] 注入。
///
/// 与教师视图相关的几个核心接口：
///   - [headTeacherIndex]                班主任班级工作台首页聚合
///   - [classList]                       我教的班级列表
///   - [classroomList]                   教室下拉列表
///   - [courseList]                      我的课表（按 begin/end 日期过滤）
///   - [courseTeacherNoticeList]         任课老师首页通知列表
///   - [headTeacherNoticeList]           班主任首页通知列表
///   - [noticeDetail]                    校级通知详情
final teacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return TeacherRepository(client: client);
});

class TeacherRepository {
  TeacherRepository({required this.client});

  final ApiClient client;

  static const _base = '/app/school/v2/teacher';

  // ============== 教师身份 ==============

  /// 教师在校内的多重身份记录（`AppSchoolTeacher` 列表）。
  ///
  /// 后端字段示意：
  /// ```json
  /// {
  ///   "code": 0,
  ///   "data": [{
  ///     "campusId": 1,
  ///     "roles": "head_teacher,course_teacher",  // CSV
  ///     "schoolId": 1, "teacherId": "...", ...
  ///   }]
  /// }
  /// ```
  /// `roles` 取值集合：`headmaster` 校长 / `manager` 教务管理员 /
  /// `dormitory` 宿管 / `head_teacher` 班主任 / `course_teacher` 任课老师。
  ///
  /// 当 `myInfo.role == 'teacher'` 时，智慧校园 dashboard 用本接口结果决定
  /// 同一位教师可切换的身份集合（管理员看 5 端，普通老师看自己拥有的）。
  Future<ApiResponse> teacherRole() {
    return client.post('$_base/teacherRole');
  }

  // ============== 班主任 · 班级工作台首页 ==============

  /// 班主任班级工作台首页聚合数据。
  ///
  /// 返回 `HeadTeacherIndexRes`：家校未读/待回复、管辖班级列表、待审批假条/
  /// 补卡数、今日宿舍异常数等。
  Future<ApiResponse> headTeacherIndex() {
    return client.post('$_base/headTeacherIndex');
  }

  /// 班主任班级工作台综合统计。
  Future<ApiResponse> headTeacherClassOverview({required String classId}) {
    return client.post(
      '$_base/headTeacherClassOverview',
      data: <String, dynamic>{'classId': readSnowflakeId(classId) ?? classId},
    );
  }

  /// 班主任班级工作台 · 成绩页聚合（折线趋势 / 考试 tab / 学生卡片分页）。
  Future<ApiResponse> headTeacherClassScoreOverview({
    required String classId,
    String? examId,
    int? subjectId,
    String keyword = '',
    int pageNum = 1,
    int pageSize = 10,
  }) {
    final body = <String, dynamic>{
      'classId': readSnowflakeId(classId) ?? classId,
      'pageNum': pageNum,
      'pageSize': pageSize,
    };
    if (examId != null && examId.isNotEmpty) {
      body['examId'] = readSnowflakeId(examId) ?? examId;
    }
    if (subjectId != null) body['subjectId'] = subjectId;
    if (keyword.trim().isNotEmpty) body['keyword'] = keyword.trim();
    return client.post('$_base/headTeacherClassScoreOverview', data: body);
  }

  /// 班主任 · 寝室考勤每日正常人数统计（班级工作台「七日查寝」）。
  ///
  /// `beginDate` / `endDate` 格式 `yyyy-MM-dd`。
  Future<ApiResponse> dormNormalStat({
    required String beginDate,
    required String endDate,
  }) {
    return client.post(
      '$_base/dormNormalStat',
      data: <String, dynamic>{'beginDate': beginDate, 'endDate': endDate},
    );
  }

  /// 添加重点关注学生。
  Future<ApiResponse> focusStudentAdd({
    required String studentId,
    required String classId,
    required String tag,
    required String reason,
  }) {
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{
        'studentId': studentId,
        'classId': classId,
        'tag': tag,
        'reason': reason,
      },
      numericIdKeys: const {'studentId', 'classId'},
    );
    if (body == null) {
      return Future.value(ApiResponse.failure('学生或班级 id 格式错误'));
    }
    return client.post('$_base/focusStudentAdd', data: body);
  }

  /// 取消重点关注。`id` 为学生 id（studentId）。
  Future<ApiResponse> focusStudentRemove({required String id}) {
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{'id': id},
      numericIdKeys: const {'id'},
    );
    if (body == null) {
      return Future.value(ApiResponse.failure('学生 id 格式错误'));
    }
    return client.post('$_base/focusStudentRemove', data: body);
  }

  /// 当前老师的重点关注学生列表。
  Future<ApiResponse> focusStudentList() {
    return client.post('$_base/focusStudentList');
  }

  // ============== 班主任 · 宿舍动态 / 历史 ==============

  /// 班级学生最新查寝状态。
  Future<ApiResponse> classDormitoryDynamicList({
    required String classId,
    String? status,
    int current = 1,
    int size = 200,
  }) {
    return client.post(
      '$_base/classDormitoryDynamicList',
      data: <String, dynamic>{
        'classId': readSnowflakeId(classId) ?? classId,
        'current': current,
        'size': size,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }

  /// 班级历史查寝记录。
  Future<ApiResponse> classDormitoryCheckHistory({
    required String classId,
    String? beginDate,
    String? endDate,
    String? status,
    String? studentId,
    int current = 1,
    int size = 200,
  }) {
    return client.post(
      '$_base/classDormitoryCheckHistory',
      data: <String, dynamic>{
        'classId': readSnowflakeId(classId) ?? classId,
        'current': current,
        'size': size,
        if (beginDate != null && beginDate.isNotEmpty) 'beginDate': beginDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (status != null && status.isNotEmpty) 'status': status,
        if (studentId != null && studentId.isNotEmpty)
          'studentId': readSnowflakeId(studentId) ?? studentId,
      },
    );
  }

  /// 班级查寝统计。
  Future<ApiResponse> classDormitoryCheckStat({
    required String classId,
    String? beginDate,
    String? endDate,
  }) {
    return client.post(
      '$_base/classDormitoryCheckStat',
      data: <String, dynamic>{
        'classId': readSnowflakeId(classId) ?? classId,
        if (beginDate != null && beginDate.isNotEmpty) 'beginDate': beginDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      },
    );
  }

  /// 单次查寝详情。
  Future<ApiResponse> classDormitoryCheckDetail({required String id}) {
    return client.post(
      '$_base/classDormitoryCheckDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 班级补卡申请列表。
  Future<ApiResponse> classDormitoryMakeupList({
    required String classId,
    int? status,
    int current = 1,
    int size = 200,
  }) {
    return client.post(
      '$_base/classDormitoryMakeupList',
      data: <String, dynamic>{
        'classId': readSnowflakeId(classId) ?? classId,
        'current': current,
        'size': size,
        'status': ?status,
      },
    );
  }

  /// 补卡申请详情。
  Future<ApiResponse> classDormitoryMakeupDetail({required String id}) {
    return client.post(
      '$_base/classDormitoryMakeupDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 审批补卡申请。`status`: 1-通过 / 2-拒绝。
  Future<ApiResponse> classDormitoryMakeupAudit({
    required String id,
    required int status,
    String auditReason = '',
  }) {
    return client.post(
      '$_base/classDormitoryMakeupAudit',
      data: <String, dynamic>{
        'id': readSnowflakeId(id) ?? id,
        'status': status,
        if (auditReason.isNotEmpty) 'auditReason': auditReason,
      },
    );
  }

  // ============== 班级 / 课表 ==============

  /// 任课老师"我教的班级"列表。后端基于 token 自动过滤为当前老师任教
  /// 或担任班主任的班级。
  ///
  /// - `isClassTeacher`: 是不是任课老师。任课老师端（授课课表 / 签课 / 学生名册 /
  ///   作品批改 / 考评管理等）调用统一传 `1`，让后端按"我任教的班级"过滤。
  /// - `isHeadTeacher`: 是不是班主任。班主任端调用本接口时传 `1`，让后端按
  ///   "我担任班主任的班级"过滤；不传 = 不按该字段过滤。
  Future<ApiResponse> classList({
    int? isClassTeacher,
    int? isHeadTeacher,
    bool isDormManager = false,
  }) {
    final body = <String, dynamic>{};
    if (isClassTeacher != null) body['isClassTeacher'] = isClassTeacher;
    if (isHeadTeacher != null) body['isHeadTeacher'] = isHeadTeacher;
    if (isDormManager) body['isDormManager'] = 1;
    return client.post('$_base/classList', data: body);
  }

  /// 任课老师端教室下拉列表。
  Future<ApiResponse> classroomList() {
    return client.post('$_base/classroomList');
  }

  /// 任课老师"我的课表"。后端会基于 token 自动定位到当前老师的全部排课。
  /// `beginDate` / `endDate` 为 `yyyy-MM-dd` 字符串（与 admin courseList 一致），
  /// 不传时返回全量。
  Future<ApiResponse> courseList({String? beginDate, String? endDate}) {
    final body = <String, dynamic>{};
    if (beginDate != null && beginDate.isNotEmpty) {
      body['beginDate'] = beginDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      body['endDate'] = endDate;
    }
    return client.post('$_base/courseList', data: body);
  }

  /// 任课老师首页工作台聚合数据。
  Future<ApiResponse> courseTeacherIndex() {
    return client.post('$_base/courseTeacherIndex');
  }

  /// 课堂考勤统计。任课老师一般传 [courseId]，班主任可传 [classId]。
  Future<ApiResponse> courseAttendanceStat({
    String? classId,
    String? courseId,
    String? beginDate,
    String? endDate,
  }) {
    return client.post(
      '$_base/courseAttendanceStat',
      data: <String, dynamic>{
        if (classId != null && classId.isNotEmpty) 'classId': classId,
        if (courseId != null && courseId.isNotEmpty) 'courseId': courseId,
        if (beginDate != null && beginDate.isNotEmpty) 'beginDate': beginDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      },
    );
  }

  /// 课堂考勤最近记录，最多返回 50 条。
  Future<ApiResponse> courseAttendanceRecentList({
    String? classId,
    String? courseId,
    int size = 10,
  }) {
    return client.post(
      '$_base/courseAttendanceRecentList',
      data: <String, dynamic>{
        if (classId != null && classId.isNotEmpty) 'classId': classId,
        if (courseId != null && courseId.isNotEmpty) 'courseId': courseId,
        'size': size.clamp(1, 50),
      },
    );
  }

  /// 课堂考勤历史记录。
  Future<ApiResponse> courseAttendanceHistory({
    String? classId,
    String? courseId,
    String? beginDate,
    String? endDate,
    int? status,
    int current = 1,
    int size = 20,
  }) {
    return client.post(
      '$_base/courseAttendanceHistory',
      data: <String, dynamic>{
        if (classId != null && classId.isNotEmpty) 'classId': classId,
        if (courseId != null && courseId.isNotEmpty) 'courseId': courseId,
        if (beginDate != null && beginDate.isNotEmpty) 'beginDate': beginDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        'status': ?status,
        'current': current,
        'size': size,
      },
    );
  }

  /// 一节课的签课详情，包含学生名单与当前签到状态。
  Future<ApiResponse> courseClassSignDetail({required String courseId}) {
    return client.post(
      '$_base/courseClassSignDetail',
      data: <String, dynamic>{
        'courseId': readSnowflakeId(courseId) ?? courseId,
      },
    );
  }

  /// 全班一键签课。每名学生可分别指定 0-出勤 / 1-缺勤 / 2-迟到 / 3-请假。
  Future<ApiResponse> courseClassSignAll({
    required String courseId,
    required List<Map<String, dynamic>> students,
  }) {
    return client.post(
      '$_base/courseClassSignAll',
      data: <String, dynamic>{
        'courseId': readSnowflakeId(courseId) ?? courseId,
        'students': students,
      },
    );
  }

  /// 修改单个学生的签到状态。
  Future<ApiResponse> courseClassStudentSignUpdate({
    required String courseId,
    required String studentId,
    required int signStatus,
    String remark = '',
  }) {
    return client.post(
      '$_base/courseClassStudentSignUpdate',
      data: <String, dynamic>{
        'courseId': readSnowflakeId(courseId) ?? courseId,
        'studentId': readSnowflakeId(studentId) ?? studentId,
        'signStatus': signStatus,
        if (remark.isNotEmpty) 'remark': remark,
      },
    );
  }

  /// 教师签课历史列表。
  Future<ApiResponse> courseTeacherSignHistory({
    String? beginDate,
    String? endDate,
    int current = 1,
    int size = 20,
  }) {
    return client.post(
      '$_base/courseTeacherSignHistory',
      data: <String, dynamic>{
        if (beginDate != null && beginDate.isNotEmpty) 'beginDate': beginDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        'current': current,
        'size': size,
      },
    );
  }

  /// 班主任编辑班级群资料。当前用于更新群聊名称与头像。
  Future<ApiResponse> classUpdate(Map<String, dynamic> body) {
    return client.post('$_base/classUpdate', data: body);
  }

  // ============== 班级通知（班主任端） ==============

  /// 班级通知列表。分页，默认第 1 页、每页 10 条。
  Future<ApiResponse> schoolClassNoticeList({
    required String classId,
    int current = 1,
    int size = 10,
  }) {
    return client.post(
      '$_base/schoolClassNoticeList',
      data: <String, dynamic>{
        'classId': classId,
        'current': current,
        'size': size,
      },
    );
  }

  /// 新增班级通知。`title` 为通知标题，`content` 为正文。
  Future<ApiResponse> schoolClassNoticeSave({
    required String classId,
    required String title,
    required String content,
  }) {
    return client.post(
      '$_base/schoolClassNoticeSave',
      data: <String, dynamic>{
        'classId': classId,
        'title': title,
        'content': content,
      },
    );
  }

  /// 删除班级通知。`id` 为通知主键。
  Future<ApiResponse> schoolClassNoticeDel({required String id}) {
    return client.post(
      '$_base/schoolClassNoticeDel',
      data: <String, dynamic>{'id': id},
    );
  }

  // ============== 校级通知（任课老师端） ==============

  /// 任课老师首页通知列表。
  Future<ApiResponse> courseTeacherNoticeList({
    int current = 1,
    int size = 20,
  }) {
    return client.post(
      '$_base/courseTeacherNoticeList',
      data: <String, dynamic>{'current': current, 'size': size},
    );
  }

  /// 班主任首页通知列表。
  Future<ApiResponse> headTeacherNoticeList({int current = 1, int size = 20}) {
    return client.post(
      '$_base/headTeacherNoticeList',
      data: <String, dynamic>{'current': current, 'size': size},
    );
  }

  /// 校级通知详情。`id` 为雪花 long 字符串。
  Future<ApiResponse> noticeDetail({required String id}) {
    return client.post(
      '$_base/noticeDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  // ============== 家校沟通 ==============

  /// 家校沟通统计。
  Future<ApiResponse> chatStat() {
    return client.post('$_base/chatStat');
  }

  /// 家校沟通会话列表。
  Future<ApiResponse> chatConversationList({
    int current = 1,
    int size = 50,
    String tab = 'all',
    String keyword = '',
  }) {
    final body = <String, dynamic>{
      'current': current,
      'size': size,
      'tab': tab,
    };
    if (keyword.trim().isNotEmpty) body['keyword'] = keyword.trim();
    return client.post('$_base/chatConversationList', data: body);
  }

  /// 家校沟通消息列表。
  Future<ApiResponse> chatMessageList({
    required String conversationId,
    int current = 1,
    int size = 100,
  }) {
    return client.post(
      '$_base/chatMessageList',
      data: <String, dynamic>{
        'conversationId': readSnowflakeId(conversationId) ?? conversationId,
        'current': current,
        'size': size,
      },
    );
  }

  /// 班主任发送家校沟通消息。
  Future<ApiResponse> chatSend({
    required String studentId,
    required String parentId,
    required String content,
  }) {
    return client.post(
      '$_base/chatSend',
      data: <String, dynamic>{
        'studentId': readSnowflakeId(studentId) ?? studentId,
        'parentId': readSnowflakeId(parentId) ?? parentId,
        'content': content,
      },
    );
  }

  // ============== 学生管理（班主任端） ==============

  /// 班级学生列表（分页）。`classId` 为空串表示全部班级；具体班级传雪花 **字符串**。
  ///
  /// 请求体：`archiveId`、`classId`（全部时为 `""`）、`current`、`keyword`、`size`、
  /// `studentStatus`、`type`。
  Future<ApiResponse> studentList({
    String classId = '',
    int current = 1,
    int size = 10,
    String keyword = '',
    String studentStatus = '',
    int type = 0,
    int archiveId = 0,
  }) {
    final normalized = classId.trim();
    final classIdBody = (normalized.isEmpty || normalized == '0')
        ? ''
        : normalized;
    final body = <String, dynamic>{
      'archiveId': archiveId,
      'classId': classIdBody,
      'current': current,
      'keyword': keyword,
      'size': size,
      'studentStatus': studentStatus,
      'type': type,
    };
    return client.post('$_base/studentList', data: body);
  }

  /// 编辑学生信息。仅允许班主任修改 `remark`（备注）和 `tags`（标签，逗号分隔）。
  /// `studentId` 为雪花 long，须以字符串传入并由 [encodeNumericIdRequestBody]
  /// 写入请求体，避免 Web 端 JS Number 精度丢失。
  Future<ApiResponse> studentUpdate({
    required String studentId,
    String remark = '',
    String tags = '',
  }) {
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{'studentId': studentId, 'remark': remark, 'tags': tags},
      numericIdKeys: const {'studentId'},
    );
    if (body == null) {
      return Future.value(ApiResponse.failure('学生 id 格式错误'));
    }
    return client.post('$_base/studentUpdate', data: body);
  }

  /// 学生详情。`id` 为学生主键（雪花 long 请用 String 传入，避免 Web 端精度丢失）。
  Future<ApiResponse> studentDetail({required Object id}) {
    final sid = id is String ? id : id.toString();
    return client.post(
      '$_base/studentDetail',
      data: <String, dynamic>{'id': sid},
    );
  }

  /// 学生考试成绩详情。
  Future<ApiResponse> studentExamRecordList({required String studentId}) {
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{'studentId': studentId},
      numericIdKeys: const {'studentId'},
    );
    if (body == null) {
      return Future.value(ApiResponse.failure('学生 id 格式错误'));
    }
    return client.post('$_base/studentExamRecordList', data: body);
  }

  // ============== 考评管理 ==============

  /// 当前老师有权批改的考试列表。`classId` 不传时查询全部有权批改的考试。
  Future<ApiResponse> examList({String? classId, bool includeStat = false}) {
    if (classId == null || classId.trim().isEmpty) {
      return client.post(
        '$_base/examList',
        data: includeStat ? {'includeStat': true} : null,
      );
    }
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{
        'classId': classId,
        if (includeStat) 'includeStat': true,
      },
      numericIdKeys: const {'classId'},
    );
    if (body == null) return Future.value(ApiResponse.failure('班级 id 格式错误'));
    return client.post('$_base/examList', data: body);
  }

  /// 考试考生列表。`scoreStatus`: 0 未打分、1 已打分；不传查询全部。
  /// `classId` 不传时返回老师任教的全部班级。
  Future<ApiResponse> examStudentList({
    required String examId,
    required int subjectId,
    int? scoreStatus,
    String? classId,
  }) {
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{
        'examId': examId,
        'subjectId': subjectId,
        'scoreStatus': scoreStatus,
        if (classId != null && classId.isNotEmpty) 'classId': classId,
      },
      numericIdKeys: const {'examId'},
    );
    if (body == null) return Future.value(ApiResponse.failure('考试 id 格式错误'));
    return client.post('$_base/examStudentList', data: body);
  }

  /// 考试打分。请求体字段与老师端 Swagger 保持一致。
  Future<ApiResponse> examStudentScore({
    required String examId,
    required int subjectId,
    required String studentId,
    required num score,
    String? comment,
    String? path,
  }) {
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{
        'examId': examId,
        'subjectId': subjectId,
        'studentId': studentId,
        'score': score,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (path != null && path.isNotEmpty) 'path': path,
      },
      numericIdKeys: const {'examId', 'studentId'},
    );
    if (body == null) {
      return Future.value(ApiResponse.failure('考试或学生 id 格式错误'));
    }
    return client.post('$_base/examStudentScore', data: body);
  }

  /// 考试打分统计；`classId` 不传时统计老师任教的全部班级。
  Future<ApiResponse> examStudentStat({
    required String examId,
    required int subjectId,
    String? classId,
  }) {
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{
        'examId': examId,
        'subjectId': subjectId,
        if (classId != null && classId.isNotEmpty) 'classId': classId,
      },
      numericIdKeys: const {'examId'},
    );
    if (body == null) return Future.value(ApiResponse.failure('考试 id 格式错误'));
    return client.post('$_base/examStudentStat', data: body);
  }

  /// 向尚未提交考试的学生发送催交提醒。
  Future<ApiResponse> examStudentRemind({
    required String examId,
    required int subjectId,
    required List<String> studentIds,
  }) {
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{
        'examId': examId,
        'subjectId': subjectId,
        'studentIds': studentIds,
      },
      numericIdKeys: const {'examId'},
      numericIdArrayKeys: const {'studentIds'},
    );
    if (body == null) {
      return Future.value(ApiResponse.failure('考试或学生 id 格式错误'));
    }
    return client.post('$_base/examStudentRemind', data: body);
  }

  /// 考试完整详情（含全部学生考场座位）。`examId` 为考试雪花 id。
  /// 返回 `data` 为 `TeacherExamFullDetailRes`（`exam` + `seats[]`）。
  Future<ApiResponse> examFullDetail({required String examId}) {
    final body = encodeNumericIdRequestBody(
      <String, dynamic>{'id': examId},
      numericIdKeys: const {'id'},
    );
    if (body == null) return Future.value(ApiResponse.failure('考试 id 格式错误'));
    return client.post('$_base/examFullDetail', data: body);
  }

  // ============== 作品管理（任课老师端） ==============

  /// 作品数据汇总。`data` 字段示例：
  /// `homeworkCount` 发布作品数、`status1Count` 待批改人次、
  /// `status2Count` 已评阅人次、`completeRate` 完成率、
  /// `avgScore` / `maxScore` / `minScore` 已评分数统计，
  /// `homeworkStatus0Count` / `homeworkStatus1Count` 进行中 / 已截止作品数。
  ///
  /// `beginDate` / `endDate` 格式 `yyyy-MM-dd`；`classId` 为 `"0"` 表示全部班级。
  /// 班级 id 须用 **字符串**（雪花 id），勿用 int 以免 Web/JSON 精度丢失。
  Future<ApiResponse> teacherHomeworkSum({
    required String classId,
    required String beginDate,
    required String endDate,
  }) {
    return client.post(
      '$_base/teacherHomeworkSum',
      data: <String, dynamic>{
        'classId': classId,
        'beginDate': beginDate,
        'endDate': endDate,
      },
    );
  }

  /// 作品列表（分页）。
  ///
  /// `status`：`0` 进行中、`1` 已完成、`2` 待我批改；**空字符串 `''` 表示全部**
  ///（与后端约定：全部时传入 `""`，勿省略字段）。
  Future<ApiResponse> teacherHomeworkList({
    String classId = '0',
    int current = 1,
    int size = 20,
    String keyword = '',
    Object? status,
  }) {
    final body = <String, dynamic>{
      'classId': classId,
      'current': current,
      'size': size,
      'status': status ?? '',
    };
    if (keyword.isNotEmpty) body['keyword'] = keyword;
    return client.post('$_base/teacherHomeworkList', data: body);
  }

  /// 发布作品。`classIds` 为目标班级 ID 列表，`endTime` 格式 `yyyy-MM-dd HH:mm:ss`
  ///（例 `2026-05-19 17:11:00`），`expectedExt` 为期望格式标识（如 "audio"/"video"/"doc"/"image"）。
  /// `classIds` 每项为字符串雪花 id，勿用 int。
  Future<ApiResponse> teacherHomeworkSave({
    required List<String> classIds,
    required String title,
    required String description,
    required String endTime,
    required int subjectId,
    String expectedExt = '',
    String referenceWorkId = '',
  }) {
    return client.post(
      '$_base/teacherHomeworkSave',
      data: <String, dynamic>{
        'classIds': classIds,
        'title': title,
        'description': description,
        'endTime': endTime,
        'subjectId': subjectId,
        if (expectedExt.isNotEmpty) 'expectedExt': expectedExt,
        if (referenceWorkId.isNotEmpty) 'referenceWorkId': referenceWorkId,
      },
    );
  }

  /// 作品详情（包含学生提交列表）。
  Future<ApiResponse> teacherHomeworkDetail({required String id}) {
    return client.post(
      '$_base/teacherHomeworkDetail',
      data: <String, dynamic>{'id': id},
    );
  }

  /// 批改作品。`id` 为学生作品记录 ID（studentHomeworkDetail 返回的 id），
  /// `score` 为分数（0-100），`feedback` 为文字评语。
  ///
  /// 语音点评约定（与学生端解析对齐）：
  ///   - `teacherParam1`：语音文件相对路径（fileUpload 返回的 `path`）；
  ///   - `teacherParam2`：语音时长（秒，字符串）。
  Future<ApiResponse> teacherHomeworkCorrect({
    required String id,
    required int score,
    String feedback = '',
    String teacherParam1 = '',
    String teacherParam2 = '',
    String teacherParam3 = '',
  }) {
    return client.post(
      '$_base/teacherHomeworkCorrect',
      data: <String, dynamic>{
        'id': id,
        'score': score,
        'feedback': feedback,
        if (teacherParam1.isNotEmpty) 'teacherParam1': teacherParam1,
        if (teacherParam2.isNotEmpty) 'teacherParam2': teacherParam2,
        if (teacherParam3.isNotEmpty) 'teacherParam3': teacherParam3,
      },
    );
  }

  /// 上传语音点评文件，返回上传结果（`data.path` / `data.url`）。
  ///
  /// 复用全局文件上传端点 `/app/common/v2/fileUpload`，与群聊语音、录音系统
  /// 一致；调用方拿到 `path` 后写入 [teacherHomeworkCorrect] 的 `teacherParam1`。
  Future<ApiResponse> uploadHomeworkVoice({
    required Uint8List bytes,
    required String filename,
  }) {
    final lower = filename.toLowerCase();
    final DioMediaType mime;
    if (lower.endsWith('.webm')) {
      mime = DioMediaType('audio', 'webm');
    } else if (lower.endsWith('.wav')) {
      mime = DioMediaType('audio', 'wav');
    } else {
      mime = DioMediaType('audio', 'mp4'); // .m4a / .aac
    }
    final form = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: mime,
      ),
    });
    return client.postFormData('/app/common/v2/fileUpload', data: form);
  }

  /// 删除作品。
  Future<ApiResponse> teacherHomeworkDelete({required String id}) {
    return client.post(
      '$_base/teacherHomeworkDelete',
      data: <String, dynamic>{'id': id},
    );
  }

  /// 某个学生的作品详情（提交内容、文件、状态等）。
  Future<ApiResponse> studentHomeworkDetail({required String id}) {
    return client.post(
      '$_base/studentHomeworkDetail',
      data: <String, dynamic>{'id': id},
    );
  }

  // ============== 班主任 · 学生请假审批 ==============

  /// 学生请假列表（`AppSchoolStudentLeaveTeacherListBO`）。
  ///
  /// `status`: 0-待家长审批 / 1-家长同意 / 2-家长拒绝 / 3-老师同意 /
  /// 4-老师拒绝；**空字符串 `''` 表示全部**（与后端约定：全部时传入 `""`，
  /// 勿省略字段）。
  ///
  /// `statusList` 与 `status` 二选一；传入 `statusList` 时不再发送 `status`。
  Future<ApiResponse> headTeacherStudentLeaveList({
    int current = 1,
    int size = 200,
    Object? status,
    List<int>? statusList,
  }) {
    final data = <String, dynamic>{'current': current, 'size': size};
    if (statusList != null) {
      data['statusList'] = statusList;
    } else {
      data['status'] = status ?? '';
    }
    return client.post('$_base/headTeacherStudentLeaveList', data: data);
  }

  /// 学生请假审批：`status` 3=同意 / 4=拒绝。
  Future<ApiResponse> headTeacherStudentLeaveAudit({
    required String id,
    required int status,
    String? teacherAuditReason,
  }) {
    return client.post(
      '$_base/headTeacherStudentLeaveAudit',
      data: <String, dynamic>{
        'id': readSnowflakeId(id) ?? id,
        'status': status,
        if (teacherAuditReason != null && teacherAuditReason.isNotEmpty)
          'teacherAuditReason': teacherAuditReason,
      },
    );
  }

  /// 班主任查看学生请假记录详情。
  Future<ApiResponse> headTeacherStudentLeaveDetail({required String id}) {
    return client.post(
      '$_base/headTeacherStudentLeaveDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  // ============== 教师请假（任课老师 / 班主任 · 我的请假） ==============

  /// 我的请假列表。
  ///
  /// `POST /app/school/v2/teacher/teacherLeaveList`
  ///
  /// 请求体 `AppSchoolTeacherLeaveListBO`：
  /// - `current` / `size`：分页
  /// - `status`：0-待审批 / 1-已批准 / 2-已拒绝；不传 = 全部
  ///
  /// 返回 `BasePageResponse<AppSchoolTeacherLeave>`（`records` + `total` +
  /// `pages`），单条字段含 `type` / `startTime` / `endTime` / `leaveDuration` /
  /// `leaveReason` / `shiftHandover` / `status` / `auditReason` / `auditTime` /
  /// `createTime` / 嵌套 `teacher`（`UserInfoRes`）等。
  Future<ApiResponse> teacherLeaveList({
    int current = 1,
    int size = 200,
    int? status,
  }) {
    final body = <String, dynamic>{'current': current, 'size': size};
    if (status != null) body['status'] = status;
    return client.post('$_base/teacherLeaveList', data: body);
  }

  /// 发起请假申请。
  ///
  /// `POST /app/school/v2/teacher/teacherLeaveSave`
  ///
  /// 请求体 `AppSchoolTeacherLeaveSaveBO`：
  /// - `type`：0-病假 / 1-事假
  /// - `startTime` / `endTime`：`date-time`，提交格式 `yyyy-MM-dd HH:mm:ss`
  /// - `leaveDuration`：请假时长（字符串，如 `"2"` 或 `"2天"`）
  /// - `leaveReason`：请假原因
  /// - `shiftHandover`：交接班说明
  Future<ApiResponse> teacherLeaveSave({
    required int type,
    required String startTime,
    required String endTime,
    required String leaveDuration,
    required String leaveReason,
    String shiftHandover = '',
  }) {
    return client.post(
      '$_base/teacherLeaveSave',
      data: <String, dynamic>{
        'type': type,
        'startTime': startTime,
        'endTime': endTime,
        'leaveDuration': leaveDuration,
        'leaveReason': leaveReason,
        'shiftHandover': shiftHandover,
      },
    );
  }

  /// 老师查看本人请假记录详情。
  Future<ApiResponse> teacherLeaveDetail({required String id}) {
    return client.post(
      '$_base/teacherLeaveDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }

  /// 班级公告详情。
  Future<ApiResponse> schoolClassNoticeDetail({required String id}) {
    return client.post(
      '$_base/schoolClassNoticeDetail',
      data: <String, dynamic>{'id': readSnowflakeId(id) ?? id},
    );
  }
}
