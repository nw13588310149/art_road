import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppNetworkState {
  const AppNetworkState({
    this.hasConnection = true,
    this.offlineUseAcknowledged = false,
  });

  final bool hasConnection;
  final bool offlineUseAcknowledged;

  AppNetworkState copyWith({
    bool? hasConnection,
    bool? offlineUseAcknowledged,
  }) {
    return AppNetworkState(
      hasConnection: hasConnection ?? this.hasConnection,
      offlineUseAcknowledged:
          offlineUseAcknowledged ?? this.offlineUseAcknowledged,
    );
  }
}

final appNetworkMonitorProvider =
    NotifierProvider<AppNetworkMonitor, AppNetworkState>(AppNetworkMonitor.new);

class AppNetworkMonitor extends Notifier<AppNetworkState> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final Connectivity _connectivity = Connectivity();

  @override
  AppNetworkState build() {
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
    });
    _subscription = _connectivity.onConnectivityChanged.listen(_applyResults);
    unawaited(_syncInitial());
    return const AppNetworkState();
  }

  static bool resultsHaveConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> _syncInitial() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _applyResults(results);
    } catch (_) {
      // 平台插件异常时保持乐观在线，避免误弹离线阻断弹窗。
    }
  }

  void _applyResults(List<ConnectivityResult> results) {
    final connected = resultsHaveConnection(results);
    if (connected) {
      if (state.hasConnection && !state.offlineUseAcknowledged) {
        return;
      }
      state = const AppNetworkState(hasConnection: true);
      return;
    }

    if (!state.hasConnection) {
      return;
    }
    state = const AppNetworkState(hasConnection: false);
  }

  void acknowledgeOfflineUse() {
    if (state.offlineUseAcknowledged) {
      return;
    }
    state = state.copyWith(offlineUseAcknowledged: true);
  }
}
