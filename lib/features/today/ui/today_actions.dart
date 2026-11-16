import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../art_toolbox/data/toolbox_catalog.dart';
import '../../artworks/ui/artwork_upload_dialog.dart';
import '../../shell/state/shell_controller.dart';
import '../../smart_campus/state/campus_entry.dart';
import '../../smart_campus/state/smart_campus_controller.dart';
import '../../teaching_overview/data/teaching_overview_repository.dart';
import '../../teaching_overview/ui/teaching_overview_page.dart';
import '../data/today_models.dart';
import '../state/today_controller.dart';

/// 打开一个动作对应的地方。返回 true 表示在弹窗里完成了提交（上传作品）。
///
/// 不认识的类型不做任何事：接口新增了动作、客户端还没跟上时不至于出错。
Future<bool> openTodayAction(
  BuildContext context,
  WidgetRef ref,
  TodayAction action,
) async {
  final navigator = Navigator.of(context);
  final campus = ref.read(smartCampusControllerProvider.notifier);
  switch (action.type) {
    case 'route':
      await navigator.pushNamed(action.route, arguments: action.arguments);
    case 'campus':
      final entry = CampusEntry.values.asNameMap()[action.entry];
      if (entry == null) return false;
      campus.openEntry(entry);
      await navigator.pushNamed(RoutePaths.smartCampus);
    case 'report':
      final report = TeachingReport.values.asNameMap()[action.report];
      if (report == null) return false;
      await openTeachingReport(
        context,
        report,
        campus: action.campus,
        parameter: action.parameter,
      );
    case 'upload':
      final saved = await showArtworkUploadDialog(
        context,
        taskId: action.taskId,
        parentId: action.parentId,
        title: action.title,
        subject: action.subject,
      );
      return saved == true;
    case 'schedule':
      final user = ref.read(shellControllerProvider).user;
      final role = ref.read(todayRoleProvider);
      if (role == 'admin' || role == 'principal') {
        campus.openEntry(CampusEntry.scheduleManagement);
      } else {
        campus.openMyScheduleForUser(role: role, identity: user.identity);
      }
      await navigator.pushNamed(RoutePaths.smartCampus);
    case 'tool':
      final tool = ArtTool.tryParse(action.tool);
      await navigator.pushNamed(
        RoutePaths.artToolbox,
        arguments: <String, dynamic>{
          if (tool != null) 'tool': tool.key,
          'returnToSource': true,
        },
      );
    case 'gallery':
      await navigator.pushNamed(
        RoutePaths.gallery,
        arguments: <String, dynamic>{
          if (action.subject.isNotEmpty) 'subject': action.subject,
          if (action.keyword.isNotEmpty) 'keyword': action.keyword,
        },
      );
  }
  return false;
}
