import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/smart_campus_controller.dart';

/// 群聊富内容卡片跳转时写入路由 arguments，供详情页返回群聊会话。
abstract final class GroupChatReturnNavigator {
  static const fromGroupChatKey = 'fromGroupChat';
  static const groupChatClassIdKey = 'groupChatClassId';

  static Map<String, dynamic> wrapMap(
    Map<String, dynamic> args, {
    String? classId,
  }) {
    return <String, dynamic>{
      ...args,
      fromGroupChatKey: true,
      if (classId != null && classId.isNotEmpty) groupChatClassIdKey: classId,
    };
  }

  static bool isActive(BuildContext context) {
    final raw = ModalRoute.of(context)?.settings.arguments;
    return raw is Map && raw[fromGroupChatKey] == true;
  }

  static void ensureGroupChat(WidgetRef ref) {
    ref.read(smartCampusControllerProvider.notifier).openGroupChat();
  }

  /// 关闭当前 Shell 路由；若来自群聊分享则先切回智慧校园群聊视图。
  static void pop(BuildContext context, {WidgetRef? ref}) {
    if (isActive(context)) {
      if (ref != null) {
        ensureGroupChat(ref);
      } else {
        ProviderScope.containerOf(
          context,
        ).read(smartCampusControllerProvider.notifier).openGroupChat();
      }
    }
    Navigator.of(context).pop();
  }
}
