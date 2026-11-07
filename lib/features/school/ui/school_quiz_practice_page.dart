import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../quiz_practice/state/quiz_practice_state.dart';
import '../../quiz_practice/ui/quiz_practice_view.dart';
import '../state/school_page_controller.dart';

/// 画室题库：与公开题库同一套界面，接口携带真实 schoolId。
class SchoolQuizPracticePage extends ConsumerWidget {
  const SchoolQuizPracticePage({super.key});

  String _resolveSchoolId(WidgetRef ref) {
    final stored = ref.watch(appStorageProvider).schoolId;
    if (stored != '0' && stored.isNotEmpty) {
      return stored;
    }
    final fromPage = ref.watch(schoolPageControllerProvider).schoolId;
    return fromPage != '0' ? fromPage : kPublicQuizSchoolId;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return QuizPracticeView(
      schoolId: _resolveSchoolId(ref),
      subtitle: '画室老师整理的美术常识题，做错的题会自动收进错题本',
    );
  }
}
