import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/snowflake_id.dart';
import '../../../core/providers/app_providers.dart';
import '../../video_tutorial/state/video_tutorial_state.dart';
import '../../video_tutorial/ui/video_tutorial_page.dart';
import '../state/school_page_controller.dart';

/// 校园视频页 — 复用公开视频中心 UI，接口走校区端点。
class SchoolVideoTutorialPage extends ConsumerWidget {
  const SchoolVideoTutorialPage({super.key});

  String _resolveSchoolId(BuildContext context, WidgetRef ref) {
    final fromPage = ref.watch(schoolPageControllerProvider).schoolId;
    if (fromPage != '0' && fromPage.isNotEmpty) {
      return fromPage;
    }

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is Map) {
      final school = readSnowflakeId(routeArgs['school']);
      if (school != null && school != '0') {
        return school;
      }
    }

    final stored = ref.watch(appStorageProvider).schoolId;
    return stored != '0' && stored.isNotEmpty ? stored : '0';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = _resolveSchoolId(context, ref);
    return VideoTutorialV2Page(
      args: VideoTutorialPageArgs(schoolMode: true, schoolId: schoolId),
    );
  }
}
