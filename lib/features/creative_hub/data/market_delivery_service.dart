import 'dart:convert';
import 'dart:typed_data';
import '../../smart_campus/services/group_chat_media_saver.dart';
import 'creative_models.dart';
import 'market_repository.dart';

/// 每次保存前重新校验交付权限，避免退款后仍使用旧页面中的链接。
class MarketDeliveryService {
  MarketDeliveryService(this.repository);
  final MarketRepository repository;
  Future<String> save(String orderId, {int? fileIndex}) async {
    final data = await repository.delivery(orderId);
    final GroupChatMediaSaveResult result;
    if (fileIndex == null) {
      final lines = [
        '美育集 · 数字作品使用许可（演示凭证）',
        '凭证编号：${data['licenseNumber']}',
        '作品：${data['title']}',
        '作者：${data['author']}',
        '购买者：${data['buyer']}',
        '订单：$orderId',
        '交付时间：${data['issuedAt']}',
        '',
        '${data['terms']}',
        '',
        '本凭证来自演示交易，未发生真实付款。',
      ];
      result = await saveGroupChatMediaBytes(
        bytes: Uint8List.fromList(utf8.encode(lines.join('\n'))),
        suggestedFileName: '$orderId-许可凭证.txt',
        kind: GroupChatMediaKind.file,
      );
    } else {
      final files = creativeRows(data['files']);
      if (fileIndex < 0 || fileIndex >= files.length) {
        throw StateError('交付文件已更新，请刷新后重试');
      }
      final file = files[fileIndex];
      final pdf = file['kind'] == 'pdf';
      result = await saveGroupChatMediaItem(
        GroupChatMediaDownloadItem(
          label: '${data['title']}',
          suggestedFileName: '$orderId-${fileIndex + 1}.${pdf ? 'pdf' : 'jpg'}',
          kind: pdf ? GroupChatMediaKind.file : GroupChatMediaKind.image,
          url: creativeText(file['url']),
        ),
      );
    }
    if (result.cancelled) return '已取消保存';
    if (!result.ok) throw StateError(result.error ?? '保存失败，请重试');
    return '文件已交给设备保存';
  }
}
