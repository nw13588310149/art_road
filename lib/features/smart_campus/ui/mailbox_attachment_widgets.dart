import 'package:flutter/material.dart';

import '../../../core/network/media_url.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../courseware/ui/courseware_url_opener.dart';
import '../../shell/ui/shell_layout.dart';

const Color _kBorderDash = Color(0xFFCECED1);
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);

/// 校长信箱附件 chip：图片 / 文件统一样式，点击可预览或打开。
class MailboxAttachmentChip extends StatelessWidget {
  const MailboxAttachmentChip({super.key, required this.url, this.onTap});

  final String url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final name = url.split('/').isNotEmpty ? url.split('/').last : url;
    final isImage = isMailboxImageUrl(url);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(6)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(6)),
        decoration: BoxDecoration(
          color: _kInnerGray,
          borderRadius: BorderRadius.circular(ui(6)),
          border: Border.all(color: _kBorderDash),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isImage ? Icons.image_outlined : Icons.attach_file_rounded,
              size: ui(14),
              color: _kTextHint,
            ),
            SizedBox(width: ui(4)),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ui(160)),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(12),
                  color: _kTextDark,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.2,
                ),
              ),
            ),
            if (onTap != null) ...[
              SizedBox(width: ui(4)),
              Icon(
                isImage
                    ? Icons.zoom_out_map_rounded
                    : Icons.open_in_new_rounded,
                size: ui(12),
                color: _kPurple,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单击附件 chip 时的预览逻辑：
/// - 图片：打开 [showImageGallery]，支持同条记录内多图切换；
/// - 非图片：调用 [openCoursewareUrl] 打开。
void previewMailboxAttachment(
  BuildContext context, {
  required List<String> attachments,
  required int index,
  required String heroTagPrefix,
}) {
  if (index < 0 || index >= attachments.length) return;
  final raw = attachments[index].trim();
  if (raw.isEmpty) return;
  final resolved = MediaUrl.resolve(raw);
  if (isMailboxImageUrl(raw)) {
    final imageUrls = <String>[];
    var initialIndex = 0;
    for (var i = 0; i < attachments.length; i++) {
      final a = attachments[i].trim();
      if (a.isEmpty || !isMailboxImageUrl(a)) continue;
      if (i == index) initialIndex = imageUrls.length;
      imageUrls.add(MediaUrl.resolve(a));
    }
    if (imageUrls.isEmpty) {
      AppToast.show(context, '附件无法预览');
      return;
    }
    showImageGallery(
      context,
      images: imageUrls,
      initialIndex: initialIndex,
      heroTagPrefix: heroTagPrefix,
    );
    return;
  }

  if (resolved.isEmpty) {
    AppToast.show(context, '附件链接无效');
    return;
  }
  openCoursewareUrl(resolved);
}

bool isMailboxImageUrl(String url) {
  final value = url.trim().toLowerCase();
  if (value.isEmpty) return false;
  final cleaned = value.split('?').first.split('#').first;
  final dot = cleaned.lastIndexOf('.');
  if (dot < 0 || dot == cleaned.length - 1) return false;
  final ext = cleaned.substring(dot + 1);
  return const {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'svg',
    'heic',
    'heif',
  }.contains(ext);
}
