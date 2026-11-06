import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_home_data.dart';
import '../data/admin_repository.dart';
import '../data/principal_inbox_data.dart';
import '../data/principal_mailbox_repository.dart';
import '../data/teacher_notice_data.dart';
import 'admin_home_state.dart';
import 'smart_campus_state.dart';

final adminHomeControllerProvider =
    StateNotifierProvider.autoDispose<AdminHomeController, AdminHomeState>(
      (ref) => AdminHomeController(
        repository: ref.watch(adminRepositoryProvider),
        principalMailboxRepository: ref.watch(
          principalMailboxRepositoryProvider,
        ),
      ),
    );

class AdminHomeController extends StateNotifier<AdminHomeState> {
  AdminHomeController({
    required AdminRepository repository,
    required PrincipalMailboxRepository principalMailboxRepository,
  }) : _repository = repository,
       _principalMailboxRepository = principalMailboxRepository,
       super(const AdminHomeState());

  final AdminRepository _repository;
  final PrincipalMailboxRepository _principalMailboxRepository;
  SmartCampusRole _role = SmartCampusRole.admin;
  int _refreshGeneration = 0;

  Future<void> initialize(SmartCampusRole role) async {
    _role = role;
    await refresh(role: role);
  }

  Future<void> refresh({SmartCampusRole? role}) async {
    final roleChanged = role != null && role != _role;
    if (role != null) {
      _role = role;
    }
    if (state.loading && !roleChanged) return;
    final generation = ++_refreshGeneration;
    final activeRole = _role;
    state = state.copyWith(
      loading: true,
      summaryError: '',
      loginChartError: '',
      noticeError: '',
      workRemindersError: '',
    );
    final loginChartRange = adminHomeLast7DaysDateRange();
    final commonResponses = Future.wait([
      _repository.indexSum(),
      _repository.websocketLoginCount(
        startDate: loginChartRange.startDate,
        endDate: loginChartRange.endDate,
      ),
      _repository.noticeManageList(current: 1, size: 20, status: 1),
      _repository.workReminders(),
      _repository.schoolSmallCourseApplyList(current: 1, size: 1, status: 0),
      _repository.schoolUserFaceSum(),
    ]);
    final principalMailboxResponse = activeRole == SmartCampusRole.principal
        ? _principalMailboxRepository.headmasterPrincipalMailboxList(
            current: 1,
            size: 100,
            status: PrincipalInboxStatus.sent.apiCode,
          )
        : null;
    final responses = await commonResponses;
    final mailboxResponse = principalMailboxResponse == null
        ? null
        : await principalMailboxResponse;
    if (generation != _refreshGeneration) return;

    final summaryResponse = responses[0];
    final loginChartResponse = responses[1];
    final noticeResponse = responses[2];
    final workRemindersResponse = responses[3];
    final smallCourseApplyResponse = responses[4];
    final faceSumResponse = responses[5];

    final summary = summaryResponse.isSuccess
        ? AdminHomeSummary.fromJson(summaryResponse.data)
        : state.summary;
    final scheduleApply = smallCourseApplyResponse.isSuccess
        ? parseAdminListPendingTotal(smallCourseApplyResponse.data)
        : state.actionBadgeCounts.scheduleApply;
    final faceAudit = faceSumResponse.isSuccess
        ? parseAdminFaceSumPendingCount(faceSumResponse.data)
        : state.actionBadgeCounts.faceAudit;
    final principalMailboxPending = activeRole == SmartCampusRole.principal
        ? mailboxResponse?.isSuccess == true
              ? parsePrincipalInboxPendingCount(mailboxResponse?.data)
              : state.actionBadgeCounts.principalMailboxPending
        : 0;

    state = state.copyWith(
      loading: false,
      summary: summary,
      loginChart: loginChartResponse.isSuccess
          ? parseAdminHomeLoginChart(
              loginChartResponse.data,
              startDate: loginChartRange.startDate,
              endDate: loginChartRange.endDate,
            )
          : state.loginChart,
      notices: noticeResponse.isSuccess
          ? parseAdminHomeNotices(noticeResponse.data)
          : state.notices,
      workReminders: workRemindersResponse.isSuccess
          ? parseAdminHomeWorkReminders(workRemindersResponse.data)
          : state.workReminders,
      actionBadgeCounts: AdminHomeActionBadgeCounts.fromSummary(
        summary: summary,
        scheduleApply: scheduleApply,
        faceAudit: faceAudit,
        principalMailboxPending: principalMailboxPending,
      ),
      summaryError: summaryResponse.isSuccess ? '' : summaryResponse.displayMsg,
      loginChartError: loginChartResponse.isSuccess
          ? ''
          : loginChartResponse.displayMsg,
      noticeError: noticeResponse.isSuccess ? '' : noticeResponse.displayMsg,
      workRemindersError: workRemindersResponse.isSuccess
          ? ''
          : workRemindersResponse.displayMsg,
    );
  }

  Future<TeacherNoticeListItem?> loadNoticeDetail(String id) async {
    if (id.isEmpty) return null;
    final response = await _repository.noticeDetail(id: id);
    if (!response.isSuccess) {
      state = state.copyWith(noticeError: response.displayMsg);
      return null;
    }
    return parseTeacherNoticeDetail(response.data);
  }
}
