import '../data/admin_home_data.dart';

class AdminHomeState {
  const AdminHomeState({
    this.summary = const AdminHomeSummary(),
    this.loginChart = const AdminHomeLoginChart(),
    this.notices = const [],
    this.workReminders = const [],
    this.actionBadgeCounts = const AdminHomeActionBadgeCounts(),
    this.loading = false,
    this.summaryError = '',
    this.loginChartError = '',
    this.noticeError = '',
    this.workRemindersError = '',
  });

  final AdminHomeSummary summary;
  final AdminHomeLoginChart loginChart;
  final List<AdminHomeNotice> notices;
  final List<AdminHomeWorkReminder> workReminders;
  final AdminHomeActionBadgeCounts actionBadgeCounts;
  final bool loading;
  final String summaryError;
  final String loginChartError;
  final String noticeError;
  final String workRemindersError;

  AdminHomeState copyWith({
    AdminHomeSummary? summary,
    AdminHomeLoginChart? loginChart,
    List<AdminHomeNotice>? notices,
    List<AdminHomeWorkReminder>? workReminders,
    AdminHomeActionBadgeCounts? actionBadgeCounts,
    bool? loading,
    String? summaryError,
    String? loginChartError,
    String? noticeError,
    String? workRemindersError,
  }) {
    return AdminHomeState(
      summary: summary ?? this.summary,
      loginChart: loginChart ?? this.loginChart,
      notices: notices ?? this.notices,
      workReminders: workReminders ?? this.workReminders,
      actionBadgeCounts: actionBadgeCounts ?? this.actionBadgeCounts,
      loading: loading ?? this.loading,
      summaryError: summaryError ?? this.summaryError,
      loginChartError: loginChartError ?? this.loginChartError,
      noticeError: noticeError ?? this.noticeError,
      workRemindersError: workRemindersError ?? this.workRemindersError,
    );
  }
}
