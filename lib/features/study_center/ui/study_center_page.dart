import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_accounts.dart';
import '../../../core/providers/app_providers.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/state/shell_state.dart';
import '../state/study_center_args.dart';
import 'staff/staff_study_view.dart';
import 'student/student_study_view.dart';
import '../../teaching_overview/ui/principal_overview.dart';

/// 学情中心（`/study`）：学生「学情」，教职角色「班级学情」，校长「全校学情」。
///
/// 路由参数见 [StudyCenterArgs]。
class StudyCenterPage extends ConsumerStatefulWidget {
  const StudyCenterPage({super.key});

  @override
  ConsumerState<StudyCenterPage> createState() => _StudyCenterPageState();
}

class _StudyCenterPageState extends ConsumerState<StudyCenterPage> {
  StudyCenterArgs? _args;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args ??= StudyCenterArgs.parse(ModalRoute.of(context)?.settings.arguments);
  }

  @override
  Widget build(BuildContext context) {
    final args = _args ?? const StudyCenterArgs();
    final role = ref.watch(shellControllerProvider.select((s) => s.user.role));
    // myInfo 回包前角色为空，先按登录 token 还原的身份渲染，避免闪一下学生视图。
    final storage = ref.read(appStorageProvider);
    final resolvedRole = role.trim().isNotEmpty
        ? role
        : storage.isDemoSession ? DemoAccounts.fromToken(storage.token).roleKey : '';
    if (resolvedRole.isEmpty) {
      return Center(child: TextButton(
        onPressed: ref.read(shellControllerProvider.notifier).refreshUserAndSchool,
        child: const Text('正在确认账号身份，点击可重试'),
      ));
    }
    // 校长的全校学情从教学指标、趋势与报表入口开始；带考试 id 时直接看那场考试。
    if (resolvedRole == 'principal' && args.examId.isEmpty) {
      return PrincipalOverview(
        name: ref.watch(
          shellControllerProvider.select((s) => s.user.displayName),
        ),
      );
    }
    return isStaffRole(resolvedRole)
        ? StaffStudyView(key: const ValueKey<String>('study-staff'), args: args)
        : StudentStudyView(
            key: const ValueKey<String>('study-student'),
            args: args,
          );
  }
}
