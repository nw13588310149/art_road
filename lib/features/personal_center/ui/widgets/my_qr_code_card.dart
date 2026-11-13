import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/ui.dart';
import '../../data/qr_image_saver.dart';
import '../../state/profile_format.dart';

/// 我的二维码内容：头像 + 姓名 + 脱敏手机号 + 紫渐变框二维码 + 说明。
///
/// 个人中心的弹窗与 `/qrcode` 页面共用；版式对齐原版弹窗内卡（380×294 量级）。
class MyQrCodeCard extends StatelessWidget {
  const MyQrCodeCard({
    required this.nickname,
    required this.mobile,
    required this.avatarUrl,
    required this.imageUrl,
    this.qrSize = 122,
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
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppAvatar(name: nickname, url: avatarUrl, size: 44),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF0B081A),
                        fontSize: 16,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: Color(0xFF6D6B75),
                          fontSize: 14,
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: 152,
            height: 154,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF2EAFF), Color(0x00F2EAFF)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 15),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: qrSize,
                height: qrSize,
                child: MyQrImage(url: imageUrl),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '快来与我一起在美育集学习吧～',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF0B081A),
              fontSize: 16,
              fontFamily: 'PingFang SC',
              height: 20 / 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '好友可直接通过扫描二维码下载美育集并添加你为好友',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFCECED1),
              fontSize: 12,
              fontFamily: 'PingFang SC',
              height: 1.4,
            ),
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
      color: Colors.white,
      child: Center(
        child: Icon(
          icon,
          color: icon == Icons.qr_code_2_rounded
              ? AppColors.brand
              : const Color(0xFFCECED1),
        ),
      ),
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
    AppToast.showError(context, '二维码暂不支持保存，请截屏');
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
