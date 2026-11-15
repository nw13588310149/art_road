import 'smart_campus_controller.dart';
import 'smart_campus_state.dart';

/// 智慧校园里可以从首页、今日等页面直达的视图。
///
/// 调用方先用 [CampusEntryNavigation.openEntry] 切到对应视图，再进入
/// `RoutePaths.smartCampus`。
enum CampusEntry {
  groupChat,
  schoolCircle,
  principalMailbox,

  /// 学生：我的作品、请假、课堂签到、查寝打卡。
  myHomework,
  studentLeave,
  checkIn,
  dormCheck,

  /// 任课老师、班主任：课堂签课、作品批改、班级工作台、学生请假审批、查寝动态、
  /// 学生补卡审核、家校沟通、本人请假。
  classAttendance,
  homeworkReview,
  classWorkbench,
  leaveApproval,
  dormDynamic,
  dormPunchAudit,
  homeSchool,
  myLeave,

  /// 宿管：按宿舍查寝、查寝历史、补卡审核、到岗打卡。
  dormCheckByRoom,
  dormHistory,
  dormMakeupAudit,
  dormCheckIn,

  /// 管理员、校长：教务管理与教职工请假审批。
  studentManagement,
  teacherManagement,
  classManagement,
  scheduleManagement,
  signManagement,
  teacherLeaveApproval,
  faceLibrary,
  notificationManagement,
}

extension CampusEntryNavigation on SmartCampusController {
  void openEntry(CampusEntry entry) {
    switch (entry) {
      case CampusEntry.groupChat:
        openGroupChat();
      case CampusEntry.schoolCircle:
        openSchoolCircle();
      case CampusEntry.principalMailbox:
        openPrincipalMailbox();
      case CampusEntry.myHomework:
        openMyHomework();
      case CampusEntry.studentLeave:
        openLeaveManagement();
      case CampusEntry.checkIn:
        openCheckIn();
      case CampusEntry.dormCheck:
        openDormCheck();
      case CampusEntry.classAttendance:
        openClassAttendance();
      case CampusEntry.homeworkReview:
        openHomeworkReview();
      case CampusEntry.classWorkbench:
        openClassWorkbench();
      case CampusEntry.leaveApproval:
        openLeaveApproval();
      case CampusEntry.dormDynamic:
        openDormDynamic();
      case CampusEntry.dormPunchAudit:
        openDormDynamic(initialTab: TeacherDormDynamicInitialTab.punchAudit);
      case CampusEntry.homeSchool:
        openHomeSchoolCommunication();
      case CampusEntry.myLeave:
        openMyTeacherLeave();
      case CampusEntry.dormCheckByRoom:
        openDormCheckByRoom();
      case CampusEntry.dormHistory:
        openDormHistory();
      case CampusEntry.dormMakeupAudit:
        openDormMakeupAudit();
      case CampusEntry.dormCheckIn:
        openDormCheckInManagement();
      case CampusEntry.studentManagement:
        openStudentManagement();
      case CampusEntry.teacherManagement:
        openTeacherManagement();
      case CampusEntry.classManagement:
        openClassManagement();
      case CampusEntry.scheduleManagement:
        openScheduleManagement();
      case CampusEntry.signManagement:
        openSignManagement();
      case CampusEntry.teacherLeaveApproval:
        openDormLeaveApproval();
      case CampusEntry.faceLibrary:
        openFaceLibrary();
      case CampusEntry.notificationManagement:
        openNotificationManagement();
    }
  }
}
