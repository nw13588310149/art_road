/// 群聊富内容分享（`sendMsg` type=3）的 param1 / content 约定。
abstract final class ChatShareParam1 {
  static const book = 'book';
  static const kj = 'kj';
  static const video = 'video';
  static const news = 'news';
  static const voice = 'voice';
  static const file = 'file';
}

/// 课程 / 教材分享（param1=book）。
Map<String, dynamic> buildBookShareContent({
  required int id,
  required String title,
  required int type,
  String coverUrl = '',
  String subtitle = '',
}) {
  return <String, dynamic>{
    'id': id,
    'title': title,
    'type': type,
    'shortText3': coverUrl,
    'subtitle': subtitle,
  };
}

/// 资讯分享（param1=news）。
Map<String, dynamic> buildNewsShareContent({
  required int id,
  required String title,
  String coverUrl = '',
  String updateTime = '',
}) {
  return <String, dynamic>{
    'id': id,
    'title': title,
    'shortText3': coverUrl,
    if (updateTime.isNotEmpty) 'updateTime': updateTime,
  };
}

/// musicPlay / answerEnd2 分享时兜底教材 type。
int resolveMusicPlayShareBookType({
  required int detailType,
  int? routeType,
}) {
  if (detailType > 0) return detailType;
  if (routeType == 3) return 1;
  return 0;
}
