import '../../demo_backend.dart';
import 'campus_a_chat.dart';
import 'campus_a_dormitory.dart';
import 'campus_a_leave.dart';
import 'campus_a_mailbox.dart';
import 'campus_a_sign.dart';
import 'campus_a_student.dart';
import 'campus_a_study.dart';

/// 智慧校园演示接口 A 部分：学生端（`/app/school/v2/student/*`）、群聊
/// （`/app/school/v2/chat/*`）、宿管（`/app/school/v2/dormitory/*`）、校长信箱
/// （`/app/school/v2/user/principalMailbox*`、`/app/school/v2/headmaster/*`）、
/// 意见反馈（`/app/user/feedback*`）与节次时间（`schoolTimeConfigList`）。
void registerCampusFixturesPartA(DemoRouter platform) {
  CampusAStudent.register(platform);
  CampusASign.register(platform);
  CampusAStudy.register(platform);
  CampusALeaves.register(platform);
  CampusADorm.register(platform);
  CampusAChat.register(platform);
  CampusAMailbox.register(platform);
}
