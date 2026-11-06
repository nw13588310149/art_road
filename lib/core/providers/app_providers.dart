import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/api_unauthorized_handler.dart';
import '../network/chat_socket_service.dart';
import '../storage/app_storage.dart';
import '../../features/shell/state/school_binding_controller.dart';
import '../../features/shell/state/shell_controller.dart';
import '../../features/smart_campus/state/smart_campus_controller.dart';
import '../../features/ai_chat/state/ai_chat_controller.dart';

final appStorageProvider = Provider<AppStorage>((ref) {
  throw UnimplementedError('AppStorage provider must be overridden in main().');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(appStorageProvider);
  return ApiClient(storage: storage);
});

/// 在 [MyApp] 挂载后绑定一次，避免 [apiClientProvider] 与 shell 模块循环依赖。
void bindApiUnauthorizedSessionCleanup(WidgetRef ref) {
  ApiUnauthorizedHandler.instance.bindSessionCleared(() {
    ref.read(chatSocketServiceProvider).disconnect();
    if (ref.exists(shellControllerProvider)) {
      ref.read(shellControllerProvider.notifier).pausePolling();
    }
    if (ref.exists(schoolBindingControllerProvider)) {
      ref.invalidate(schoolBindingControllerProvider);
    }
    if (ref.exists(smartCampusControllerProvider)) {
      ref.invalidate(smartCampusControllerProvider);
    }
    if (ref.exists(aiChatControllerProvider)) {
      ref.invalidate(aiChatControllerProvider);
    }
  });
}
