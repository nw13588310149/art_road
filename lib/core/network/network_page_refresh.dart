import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/route_paths.dart';
import '../../features/home/state/home_dashboard_controller.dart';
import '../../features/my_collection/state/my_collection_controller.dart';
import '../../features/my_notes/state/my_notes_controller.dart';
import '../../features/personal_center/state/personal_center_controller.dart';
import '../../features/recording_system/state/recording_system_controller.dart';
import '../../features/school/state/school_page_controller.dart';
import '../../features/shell/state/school_binding_controller.dart';
import '../../features/shell/state/shell_controller.dart';
import '../../features/courseware/state/cloud_drive_controller.dart';

/// 网络恢复后刷新 Shell 公共数据与当前页业务数据。
Future<void> refreshAfterNetworkRestore(WidgetRef ref, String route) async {
  if (ref.exists(shellControllerProvider)) {
    final shell = ref.read(shellControllerProvider.notifier);
    unawaited(shell.refreshUserAndSchool());
    unawaited(shell.refreshNoticeData());
  }
  if (ref.exists(schoolBindingControllerProvider)) {
    ref.read(schoolBindingControllerProvider.notifier).refresh();
  }

  switch (route) {
    case RoutePaths.home:
      if (ref.exists(homeDashboardControllerProvider)) {
        await ref.read(homeDashboardControllerProvider.notifier).refresh();
      }
    case RoutePaths.courseware:
      if (ref.exists(cloudDriveControllerProvider)) {
        await ref.read(cloudDriveControllerProvider.notifier).refresh();
      }
    case RoutePaths.myNotes:
      if (ref.exists(myNotesControllerProvider)) {
        await ref.read(myNotesControllerProvider.notifier).refresh();
      }
    case RoutePaths.myCollection:
      if (ref.exists(myCollectionControllerProvider)) {
        await ref.read(myCollectionControllerProvider.notifier).refresh();
      }
    case RoutePaths.personalCenter:
      if (ref.exists(personalCenterControllerProvider)) {
        await ref.read(personalCenterControllerProvider.notifier).refresh();
      }
    case RoutePaths.recording:
      if (ref.exists(recordingSystemControllerProvider)) {
        await ref.read(recordingSystemControllerProvider.notifier).refresh();
      }
    case RoutePaths.school:
      if (ref.exists(schoolPageControllerProvider)) {
        await ref.read(schoolPageControllerProvider.notifier).refresh();
      }
    default:
      break;
  }
}
