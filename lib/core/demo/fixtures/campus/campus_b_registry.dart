/// 智慧校园演示接口 B 部分：任课老师、班主任（`/app/school/v2/teacher/*`）与
/// 管理员（`/app/school/v2/manager/*`）。
library;

import '../../demo_backend.dart';
import 'campus_b_admin.dart';
import 'campus_b_head_teacher.dart';
import 'campus_b_teacher.dart';

void registerCampusFixturesPartB(DemoRouter platform) {
  registerCampusBTeacher(platform);
  registerCampusBHeadTeacher(platform);
  registerCampusBAdmin(platform);
}
