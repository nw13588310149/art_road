import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../state/student_study_controller.dart';
import '../../state/study_center_args.dart';
import 'student_artwork_growth_view.dart';
import 'student_growth_view.dart';
import 'student_overview.dart';
import 'student_report_view.dart';
import 'student_study_parts.dart';

/// 「学情」：总览 / 成长曲线 / 作品成长三个视图在页头切换，成绩报告是从总览点进去的
/// 详情。切换立即生效。
class StudentStudyView extends ConsumerWidget {
  const StudentStudyView({required this.args, super.key});

  final StudyCenterArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = studentStudyControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen<StudentStudyState>(provider, (previous, next) {
      final message = next.errorMessage;
      if (message.isEmpty || message == previous?.errorMessage) {
        return;
      }
      AppToast.showError(context, message);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) {
          controller.clearError();
        }
      });
    });

    void selectTab(StudentStudyTab tab) {
      switch (tab) {
        case StudentStudyTab.overview:
          if (state.section != StudentStudySection.overview) {
            // 成长曲线从报告进来时 back 回到报告，所以先离开成长曲线再回总览。
            if (state.section == StudentStudySection.growth) {
              controller.openArtworkGrowth();
            }
            controller.back();
          }
        case StudentStudyTab.growth:
          controller.openGrowth();
        case StudentStudyTab.artwork:
          controller.openArtworkGrowth();
      }
    }

    return switch (state.section) {
      StudentStudySection.overview => StudentOverview(
        key: const ValueKey<String>('study-overview'),
        state: state,
        controller: controller,
        onSelectTab: selectTab,
      ),
      StudentStudySection.report => StudentReportView(
        key: ValueKey<String>('study-report-${state.reportExamId}'),
        examId: state.reportExamId,
        onBack: controller.back,
        onOpenTrend: controller.openGrowth,
        initialAction: state.pendingAction,
        initialSubjectId: state.pendingSubjectId,
        onInitialActionHandled: controller.consumePendingAction,
      ),
      StudentStudySection.growth => StudentGrowthView(
        key: const ValueKey<String>('study-growth'),
        onSelectTab: selectTab,
        onBack: state.growthFromReport ? controller.back : null,
      ),
      StudentStudySection.artworkGrowth => StudentArtworkGrowthView(
        key: const ValueKey<String>('study-artwork-growth'),
        onSelectTab: selectTab,
      ),
    };
  }
}
