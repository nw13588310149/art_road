import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_accounts.dart';
import '../../../core/providers/app_providers.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/state/shell_state.dart';
import 'student_artworks_view.dart';
import 'student_artwork_detail_view.dart';
import 'teacher_artworks_view.dart';

/// 作品档案（学生）/ 作品点评（教职）。页头与卡片直接排在页面底色上，与学情中心一致。
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
  bool _readOnly = false;
  bool _startReview = false;

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
      _readOnly = args['readOnly'] == true;
      _startReview = args['startReview'] == true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_readOnly && _initialArtworkId != null) {
      return StudentArtworkDetailView(
        artworkId: _initialArtworkId!,
        readOnly: true,
        onBack: () => Navigator.of(context).maybePop(),
      );
    }
    final role = ref.watch(shellControllerProvider.select((s) => s.user.role));
    final resolvedRole = role.trim().isNotEmpty
        ? role
        : DemoAccounts.fromToken(ref.read(appStorageProvider).token).roleKey;
    return isStaffRole(resolvedRole)
        ? TeacherArtworksView(
            key: const ValueKey('artworks-teacher'),
            initialArtworkId: _initialArtworkId,
            startReview: _startReview,
          )
        : StudentArtworksView(
            key: const ValueKey('artworks-student'),
            initialArtworkId: _initialArtworkId,
          );
  }
}
