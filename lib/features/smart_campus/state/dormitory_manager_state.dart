import '../data/dormitory_check_data.dart';
import '../data/teacher_notice_data.dart';

class DormitoryManagerState {
  const DormitoryManagerState({
    this.loadingHome = false,
    this.loadingBuildings = false,
    this.loadingFloors = false,
    this.loadingRoomChecks = false,
    this.loadingNotices = false,
    this.loadingHistory = false,
    this.loadingMakeup = false,
    this.exporting = false,
    this.error = '',
    this.roomCheckError = '',
    this.noticeError = '',
    this.index = DormitoryIndexOverview.zero,
    this.managedBuildings = const [DormitoryBuildingOption.all],
    this.floorOptions = const [DormitoryFloorOption.all],
    this.roomCheckStat = DormitoryCheckStat.zero,
    this.roomChecks = const [],
    this.notices = const [],
    this.historyItems = const [],
    this.historyStat = DormitoryCheckStat.zero,
    this.makeupItems = const [],
    this.makeupBuildingId,
    this.makeupStatus = 0,
    this.submittingRoomIds = const {},
    this.submittingStudentIds = const {},
    this.submittingMakeupIds = const {},
    this.submittingExceptionIds = const {},
    this.teacherLeavePendingCount = 0,
  });

  final bool loadingHome;
  final bool loadingBuildings;
  final bool loadingFloors;
  final bool loadingRoomChecks;
  final bool loadingNotices;
  final bool loadingHistory;
  final bool loadingMakeup;
  final bool exporting;
  final String error;
  final String roomCheckError;
  final String noticeError;
  final DormitoryIndexOverview index;
  final List<DormitoryBuildingOption> managedBuildings;
  final List<DormitoryFloorOption> floorOptions;
  final DormitoryCheckStat roomCheckStat;
  final List<DormitoryRoomCheck> roomChecks;
  final List<TeacherNoticeListItem> notices;
  final List<DormitoryCheckHistoryItem> historyItems;
  final DormitoryCheckStat historyStat;
  final List<DormitoryMakeupItem> makeupItems;
  final String? makeupBuildingId;
  final int? makeupStatus;
  final Set<String> submittingRoomIds;
  final Set<String> submittingStudentIds;
  final Set<String> submittingMakeupIds;
  final Set<String> submittingExceptionIds;

  /// 「宿管请假」待审批条数（`teacherLeaveList` · `status: 0`）。
  final int teacherLeavePendingCount;

  DormitoryManagerState copyWith({
    bool? loadingHome,
    bool? loadingBuildings,
    bool? loadingFloors,
    bool? loadingRoomChecks,
    bool? loadingNotices,
    bool? loadingHistory,
    bool? loadingMakeup,
    bool? exporting,
    String? error,
    String? roomCheckError,
    String? noticeError,
    DormitoryIndexOverview? index,
    List<DormitoryBuildingOption>? managedBuildings,
    List<DormitoryFloorOption>? floorOptions,
    DormitoryCheckStat? roomCheckStat,
    List<DormitoryRoomCheck>? roomChecks,
    List<TeacherNoticeListItem>? notices,
    List<DormitoryCheckHistoryItem>? historyItems,
    DormitoryCheckStat? historyStat,
    List<DormitoryMakeupItem>? makeupItems,
    String? makeupBuildingId,
    bool clearMakeupBuildingId = false,
    int? makeupStatus,
    bool clearMakeupStatus = false,
    Set<String>? submittingRoomIds,
    Set<String>? submittingStudentIds,
    Set<String>? submittingMakeupIds,
    Set<String>? submittingExceptionIds,
    int? teacherLeavePendingCount,
  }) {
    return DormitoryManagerState(
      loadingHome: loadingHome ?? this.loadingHome,
      loadingBuildings: loadingBuildings ?? this.loadingBuildings,
      loadingFloors: loadingFloors ?? this.loadingFloors,
      loadingRoomChecks: loadingRoomChecks ?? this.loadingRoomChecks,
      loadingNotices: loadingNotices ?? this.loadingNotices,
      loadingHistory: loadingHistory ?? this.loadingHistory,
      loadingMakeup: loadingMakeup ?? this.loadingMakeup,
      exporting: exporting ?? this.exporting,
      error: error ?? this.error,
      roomCheckError: roomCheckError ?? this.roomCheckError,
      noticeError: noticeError ?? this.noticeError,
      index: index ?? this.index,
      managedBuildings: managedBuildings ?? this.managedBuildings,
      floorOptions: floorOptions ?? this.floorOptions,
      roomCheckStat: roomCheckStat ?? this.roomCheckStat,
      roomChecks: roomChecks ?? this.roomChecks,
      notices: notices ?? this.notices,
      historyItems: historyItems ?? this.historyItems,
      historyStat: historyStat ?? this.historyStat,
      makeupItems: makeupItems ?? this.makeupItems,
      makeupBuildingId: clearMakeupBuildingId
          ? null
          : makeupBuildingId ?? this.makeupBuildingId,
      makeupStatus: clearMakeupStatus
          ? null
          : makeupStatus ?? this.makeupStatus,
      submittingRoomIds: submittingRoomIds ?? this.submittingRoomIds,
      submittingStudentIds: submittingStudentIds ?? this.submittingStudentIds,
      submittingMakeupIds: submittingMakeupIds ?? this.submittingMakeupIds,
      submittingExceptionIds:
          submittingExceptionIds ?? this.submittingExceptionIds,
      teacherLeavePendingCount:
          teacherLeavePendingCount ?? this.teacherLeavePendingCount,
    );
  }
}
