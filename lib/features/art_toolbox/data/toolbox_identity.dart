import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_accounts.dart';
import '../../../core/providers/app_providers.dart';
import '../../shell/state/shell_controller.dart';

final toolboxOwnerProvider = Provider<String?>((ref) {
  final storage = ref.watch(appStorageProvider);
  final session = storage.sessionToken;
  session.addListener(ref.invalidateSelf);
  ref.onDispose(() => session.removeListener(ref.invalidateSelf));

  if (storage.isDemoSession) {
    return 'demo:${DemoAccounts.fromToken(storage.token).userId}';
  }
  if (storage.token.isEmpty || storage.isGuestSession) return null;

  // myInfo belongs to one authenticated session. Until it is ready, personal
  // tools may run in memory; they must never save under a shared phone number.
  ref.watch(shellControllerProvider);
  final id = ref
      .read(shellControllerProvider.notifier)
      .authenticatedUserId
      .trim();
  return RegExp(r'^[1-9][0-9]*$').hasMatch(id) ? 'user:$id' : null;
});

String toolboxStorageKey(String base, String? owner) =>
    owner == 'legacy-demo' ? base : '$base:$owner';
bool toolboxDemoOwner(String? owner) =>
    owner == 'legacy-demo' || (owner?.startsWith('demo:') ?? false);
