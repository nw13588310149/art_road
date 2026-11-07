import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/qr_image_saver.dart';
import '../../state/profile_format.dart';

/// 我的二维码内容：头像 + 姓名 + 脱敏手机号 + 二维码 + 说明。
///
/// 个人中心的弹窗与 `/qrcode` 页面共用。
class MyQrCodeCard extends StatelessWidget {
  const MyQrCodeCard({
    required this.nickname,
    required this.mobile,
    required this.avatarUrl,
    required this.imageUrl,
    this.qrSize = 168,
    super.key,
  });

  final String nickname;
  final String mobile;
  final String avatarUrl;
  final String imageUrl;
  final double qrSize;

  @override
  Widget build(BuildContext context) {
    final phone = maskMobile(mobile);
    return Container(
      padding: const EdgeInsets.all(AppSpace.s20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppAvatar(name: nickname, url: avatarUrl, size: 44),
              const SizedBox(width: AppSpace.s12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title16,
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: AppText.number(
                          size: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          Container(
            padding: const EdgeInsets.all(AppSpace.s12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.br12,
            ),
            child: SizedBox.square(
              dimension: qrSize,
              child: MyQrImage(url: imageUrl),
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            '扫码下载美术之路，和我一起学画',
            textAlign: TextAlign.center,
            style: AppText.body14Strong,
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            '好友扫描二维码即可下载美术之路并添加你为好友',
            textAlign: TextAlign.center,
            style: AppText.caption12,
          ),
        ],
      ),
    );
  }
}

/// 二维码图片：兼容 http(s) 地址与 `data:image/...;base64,` 内联图。
class MyQrImage extends StatelessWidget {
  const MyQrImage({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    final value = url.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return AppImage(src: value, fit: BoxFit.contain);
    }
    final bytes = decodeQrImage(value);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _fallback(Icons.broken_image_outlined),
      );
    }
    return _fallback(Icons.qr_code_2_rounded);
  }

  static Widget _fallback(IconData icon) {
    return ColoredBox(
      color: AppColors.surface,
      child: Center(child: Icon(icon, color: AppColors.textPlaceholder)),
    );
  }
}

/// 解析 `data:image/png;base64,xxx` 或纯 base64 串；失败返回 null。
Uint8List? decodeQrImage(String raw) {
  if (raw.isEmpty) {
    return null;
  }
  var payload = raw;
  if (payload.startsWith('data:')) {
    final comma = payload.indexOf(',');
    if (comma < 0) {
      return null;
    }
    payload = payload.substring(comma + 1);
  }
  payload = payload.replaceAll(RegExp(r'\s'), '');
  if (payload.isEmpty) {
    return null;
  }
  try {
    return base64Decode(payload);
  } catch (_) {
    return null;
  }
}

/// 保存二维码图片并给出结果提示；保存成功返回 true。
Future<bool> saveMyQrCode(
  BuildContext context, {
  required String imageUrl,
  required String nickname,
}) async {
  final bytes = decodeQrImage(imageUrl.trim());
  if (bytes == null) {
    AppToast.showError(context, '暂不支持直接保存，请截屏保存');
    return false;
  }
  final safe = nickname.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_');
  final result = await saveQrImageBytes(
    bytes: bytes,
    suggestedName: safe.isEmpty ? 'qrcode.png' : '${safe}_qrcode.png',
  );
  if (!context.mounted) {
    return false;
  }
  if (result.ok) {
    AppToast.showSuccess(context, kIsWeb ? '已开始下载二维码' : '二维码已保存');
    return true;
  }
  if (!result.cancelled) {
    AppToast.showError(context, result.error ?? '保存失败，请截屏保存');
  }
  return false;
}
