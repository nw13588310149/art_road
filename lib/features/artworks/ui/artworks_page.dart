import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_accounts.dart';
import '../../../core/providers/app_providers.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/state/shell_state.dart';
import '../../shell/ui/shell_layout.dart';
import 'student_artworks_view.dart';
import 'teacher_artworks_view.dart';

/// 作品档案（学生）/ 作品点评（教职）。
///
/// 路由参数（可选）：`{'artworkId': String}` 直接打开该作品的详情 / 点评工作台。
class ArtworksPage extends ConsumerStatefulWidget {
  const ArtworksPage({super.key});

  @override
  ConsumerState<ArtworksPage> createState() => _ArtworksPageState();
}

class _ArtworksPageState extends ConsumerState<ArtworksPage> {
  String? _initialArtworkId;
  bool _argsRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) {
      return;
    }
    _argsRead = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final id = args['artworkId']?.toString().trim() ?? '';
      _initialArtworkId = id.isEmpty ? null : id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(shellControllerProvider.select((s) => s.user.role));
    final resolvedRole = role.trim().isNotEmpty
        ? role
        : DemoAccounts.fromToken(ref.read(appStorageProvider).token).roleKey;
    final staff = isStaffRole(resolvedRole);
    return ShellPageSurface(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ShellLayoutSpec.panelRadius),
        child: staff
            ? TeacherArtworksView(
                key: const ValueKey('artworks-teacher'),
                initialArtworkId: _initialArtworkId,
              )
            : StudentArtworksView(
                key: const ValueKey('artworks-student'),
                initialArtworkId: _initialArtworkId,
              ),
      ),
    );
  }
}
