import 'package:flutter/material.dart';

/// 收藏页跳转视频中心等 Shell 子路由时写入 arguments，详情关闭后回到收藏。
abstract final class CollectionReturnNavigator {
  static const fromMyCollectionKey = 'fromMyCollection';

  static Map<String, dynamic> wrapVideoArgs(String openVideoId) {
    return <String, dynamic>{
      'openVideoId': openVideoId,
      fromMyCollectionKey: true,
    };
  }

  static bool isActive(BuildContext context) {
    final raw = ModalRoute.of(context)?.settings.arguments;
    return raw is Map && raw[fromMyCollectionKey] == true;
  }

  /// 关闭当前 Shell 子路由（如视频中心），回到收藏页。
  static void pop(BuildContext context) {
    if (isActive(context)) {
      Navigator.of(context).pop();
    }
  }
}
