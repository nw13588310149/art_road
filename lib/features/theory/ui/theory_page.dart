import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/class_share_drawer.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../shell/ui/shell_layout.dart';
import '../../smart_campus/navigation/group_chat_return.dart';
import '../state/theory_controller.dart';
import '../state/theory_state.dart';
import 'widgets/theory_pdf_view.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

class TheoryPage extends ConsumerStatefulWidget {
  const TheoryPage({super.key});

  @override
  ConsumerState<TheoryPage> createState() => _TheoryPageState();
}

class _TheoryPageState extends ConsumerState<TheoryPage> {
  bool _shareDialogShowing = false;
  bool _imageGalleryOpen = false;

  @override
  Widget build(BuildContext context) {
    final args = TheoryPageArgs.fromRaw(
      ModalRoute.of(context)?.settings.arguments,
    );
    // 分享抽屉勾选班级只改 classList，不应触发整页（尤其 Web PDF iframe /
    // 长 HTML）重建，否则极易卡顿。
    final loading = ref.watch(
      theoryControllerProvider(args).select((s) => s.loading),
    );
    final detail = ref.watch(
      theoryControllerProvider(args).select((s) => s.detail),
    );
    final answerEndMode = ref.watch(
      theoryControllerProvider(args).select((s) => s.args.answerEndMode),
    );
    final controller = ref.read(theoryControllerProvider(args).notifier);
    final ui = DashboardScaleScope.of(context).ui;
    final pdfInteractive = !_imageGalleryOpen && !_shareDialogShowing;

    ref.listen<TheoryState>(theoryControllerProvider(args), (previous, next) {
      final message = next.errorMessage;
      if (message.isNotEmpty && message != previous?.errorMessage) {
        AppToast.show(context, message);
        controller.clearError();
      }

      if (next.shareDialogVisible && !_shareDialogShowing) {
        setState(() => _shareDialogShowing = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showShareDialog(context, args);
        });
      }
    });

    return ShellPageSurface(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      child: loading && detail == null
          ? const Center(child: AppLoadingIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _TheoryHeader(
                  detail: detail,
                  answerEndMode: answerEndMode,
                  onBack: () =>
                      GroupChatReturnNavigator.pop(context, ref: ref),
                  onShare: controller.openShareDialog,
                  onToggleFavorite: controller.toggleFavorite,
                  onOpenAssignment: () {
                    if (detail == null || !detail.hasAssignmentImages) {
                      AppToast.show(context, '暂无课程作业图片');
                      return;
                    }
                    _openImageGallery(
                      images: detail.assignmentImages,
                      heroTagPrefix: 'theory_assignment',
                    );
                  },
                  onOpenAnswer: () {
                    if (detail == null || !detail.hasAnswerImages) {
                      AppToast.show(context, '暂无答案图片');
                      return;
                    }
                    controller.markAnswerOpened();
                    _openImageGallery(
                      images: detail.answerImages,
                      heroTagPrefix: 'theory_answer',
                    );
                  },
                ),
                SizedBox(height: ui(12)),
                Expanded(
                  child: _TheoryContent(
                    detail: detail,
                    answerEndMode: answerEndMode,
                    pdfInteractive: pdfInteractive,
                    onRequestFullscreen: () {
                      if (detail != null) {
                        _openFullscreenPdf(detail);
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _openImageGallery({
    required List<String> images,
    required String heroTagPrefix,
  }) async {
    setState(() => _imageGalleryOpen = true);
    try {
      await showImageGallery(
        context,
        images: images,
        heroTagPrefix: heroTagPrefix,
      );
    } finally {
      if (mounted) {
        setState(() => _imageGalleryOpen = false);
      }
    }
  }

  /// 把当前 PDF 推到根 Navigator 的全屏对话框里铺满整块屏幕。
  /// - 用 `useRootNavigator: true` 跨过 ShellLayout / 左侧导航；
  /// - 浅灰背景 + opaque + fade 过渡；
  /// - 右上角放"退出全屏"按钮（同一颗 [_PdfFullscreenToggle]，状态置为
  ///   `expanded: true`），点击 = `Navigator.maybePop` 关闭对话框；
  /// - PDF 在全屏对话框内是新建的 [TheoryPdfView] 实例（pdfrx 没有跨 widget
  ///   保持滚动位置的便捷 API），首次进入会重新渲染，符合 1.0 中"在新窗口打开"
  ///   的体验。
  Future<void> _openFullscreenPdf(TheoryDetail detail) async {
    if (!detail.hasPdf) {
      AppToast.show(context, 'PDF 尚未加载完成');
      return;
    }
    // Web 端：直接用浏览器 Fullscreen API 把 iframe 撑满整屏。
    // 必须在用户手势事件链路同步触发，所以放在 await 之前。
    if (kIsWeb && tryFullscreenWebPdf()) {
      return;
    }
    final scale = DashboardScaleScope.of(context);
    final token = ref.read(appStorageProvider).token;
    await showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      fullscreenDialog: true,
      barrierColor: kTheoryPdfBackgroundColor,
      barrierDismissible: false,
      barrierLabel: '退出全屏',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, animation, secondary) {
        return DashboardScaleScope(
          data: scale,
          child: _PdfFullscreenView(url: detail.pdfUrl, authToken: token),
        );
      },
      transitionBuilder: (context, animation, secondary, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  Future<void> _showShareDialog(
    BuildContext context,
    TheoryPageArgs args,
  ) async {
    if (!mounted) {
      return;
    }
    await showClassShareDrawer<void>(
      context: context,
      scale: DashboardScaleScope.of(context),
      child: _TheoryShareDrawer(args: args),
    );
    if (mounted) {
      setState(() => _shareDialogShowing = false);
      ref.read(theoryControllerProvider(args).notifier).closeShareDialog();
    }
  }
}

class _TheoryShareDrawer extends ConsumerWidget {
  const _TheoryShareDrawer({required this.args});

  final TheoryPageArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(theoryControllerProvider(args));
    final controller = ref.read(theoryControllerProvider(args).notifier);

    return ClassShareDrawer(
      title: '分享课件',
      targetCard: ShareTargetCard(
        label: '您将分享的课件',
        title: state.detail?.title ?? '',
        placeholderIcon: Icons.menu_book_outlined,
      ),
      classes: state.classList
          .map(
            (cls) => ClassShareItem(
              id: cls.id,
              name: cls.name,
              avatarUrl: cls.avatarUrl,
              checked: cls.checked,
            ),
          )
          .toList(growable: false),
      loading: state.classLoading,
      sending: state.sending,
      onToggleClass: controller.toggleClass,
      onSend: () async {
        final success = await controller.sendShare();
        if (!context.mounted) {
          return;
        }
        if (success) {
          Navigator.of(context).maybePop();
        }
      },
    );
  }
}

class _TheoryHeader extends StatelessWidget {
  const _TheoryHeader({
    required this.detail,
    required this.answerEndMode,
    required this.onBack,
    required this.onShare,
    required this.onToggleFavorite,
    required this.onOpenAssignment,
    required this.onOpenAnswer,
  });

  final TheoryDetail? detail;
  final bool answerEndMode;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenAssignment;
  final VoidCallback onOpenAnswer;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final showAssignmentBtn =
        !answerEndMode && (detail?.showsAssignmentButton ?? true);
    // detail 为空（首屏 loading）时按钮也展示，但 disable 样式由 chip 内部处理。
    final favorite = detail?.favorite ?? false;

    return Row(
      children: <Widget>[
        _GlassIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
        SizedBox(width: ui(12)),
        Expanded(
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: ui(280)),
              height: ui(28),
              padding: EdgeInsets.symmetric(horizontal: ui(18)),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4FF),
                borderRadius: BorderRadius.circular(ui(999)),
              ),
              alignment: Alignment.center,
              child: Text(
                detail?.title ?? '乐理详情',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(13),
                  fontFamily: 'Harmony',
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: ui(8)),
        _FavoriteChipButton(favorite: favorite, onTap: onToggleFavorite),
        SizedBox(width: ui(8)),
        _SecondaryChipButton(
          iconAsset: AppAssets.theoryShareIcon,
          label: '分享',
          onTap: onShare,
        ),
        if (showAssignmentBtn) ...<Widget>[
          SizedBox(width: ui(8)),
          _SecondaryChipButton(
            iconAsset: AppAssets.theoryAssignmentIcon,
            label: '课程作业',
            onTap: onOpenAssignment,
          ),
        ],
        SizedBox(width: ui(8)),
        _SecondaryChipButton(
          iconAsset: AppAssets.theoryAnswerIcon,
          label: '查看答案',
          onTap: onOpenAnswer,
        ),
      ],
    );
  }
}

/// 顶部"收藏" chip：1px `#F3F2F3` 描边，无填充背景。
class _FavoriteChipButton extends StatelessWidget {
  const _FavoriteChipButton({required this.favorite, required this.onTap});

  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final labelColor = favorite
        ? const Color(0xFF8741FF)
        : const Color(0xFF0B081A);
    final iconAsset = favorite
        ? 'assets/images/home/fav4.png'
        : 'assets/images/home/fav3.png';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: ui(34),
        padding: EdgeInsets.symmetric(horizontal: ui(10)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset(
              iconAsset,
              width: ui(15),
              height: ui(15),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(4)),
            Text(
              favorite ? '收藏' : '收藏',
              style: TextStyle(
                color: labelColor,
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TheoryContent extends ConsumerWidget {
  const _TheoryContent({
    required this.detail,
    required this.answerEndMode,
    required this.pdfInteractive,
    required this.onRequestFullscreen,
  });

  final TheoryDetail? detail;
  final bool answerEndMode;
  final bool pdfInteractive;

  /// PDF 卡片右上角"全屏"按钮被点击时的回调。
  final VoidCallback onRequestFullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = DashboardScaleScope.of(context).ui;
    final token = ref.watch(appStorageProvider).token;

    if (detail == null) {
      return const _TheoryEmptyState(message: '加载中…');
    }
    final resolved = detail!;
    if (resolved.hasPdf) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: kTheoryPdfBackgroundColor,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ui(8)),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: RepaintBoundary(
                  child: TheoryPdfView(
                    url: resolved.pdfUrl,
                    authToken: token,
                    interactive: pdfInteractive,
                  ),
                ),
              ),
              // 右上角浮动"全屏"按钮：
              // - Native：点击后把 PDF 推到根 Navigator 的全屏对话框；
              // - Web：iframe 直接调浏览器 Fullscreen API（HtmlElementView
              //   在 Flutter dialog 里嵌入 iframe 会被 platform view 层
              //   遮住，所以走原生 fullscreen 反而最干净）；
              //   退出 = 用户按 Esc 或浏览器自带的退出全屏按钮。
              Positioned(
                // 设计稿要求按钮整体下移 16 逻辑像素，避开 PDF 顶部
                // 工具栏 / 页眉。
                top: ui(12) + ui(16),
                right: ui(12),
                child: _PdfFullscreenToggle(
                  expanded: false,
                  onTap: onRequestFullscreen,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (resolved.hasHtmlContent) {
      return _TheoryHtmlView(
        htmlText: resolved.htmlContent,
        answerEndMode: answerEndMode,
      );
    }
    return const _TheoryEmptyState(message: '暂无课程内容');
  }
}

/// PDF 卡片右上角的"全屏 / 退出全屏"圆形浮动按钮。
/// - [expanded] = false：显示放大图标，点击进入全屏；
/// - [expanded] = true：显示缩小图标，点击退出全屏。
class _PdfFullscreenToggle extends StatelessWidget {
  const _PdfFullscreenToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui(8)),
        child: Container(
          height: ui(32),
          padding: EdgeInsets.symmetric(horizontal: ui(10)),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: const Color(0xFFF3F2F3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: ui(10),
                offset: Offset(0, ui(2)),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.asset(
                expanded
                    ? 'assets/images/home/quxiao.png'
                    : 'assets/images/home/quan.png',
                width: ui(20),
                height: ui(20),
                fit: BoxFit.contain,
              ),
              SizedBox(width: ui(4)),
              Text(
                expanded ? '退出' : '全屏',
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(12),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PDF 全屏对话框：覆盖整个 app 窗口的浅灰背景 + 占满屏幕的 [TheoryPdfView]，
/// 右上角放退出按钮。PDF 本身不套 [SafeArea]，避免 iOS 底部 Home 指示条
/// 区域留出异色边；仅退出按钮避开刘海。
class _PdfFullscreenView extends StatelessWidget {
  const _PdfFullscreenView({required this.url, required this.authToken});

  final String url;
  final String authToken;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: kTheoryPdfBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          TheoryPdfView(
            url: url,
            authToken: authToken,
            interactive: true,
            fullscreen: true,
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                // 与卡片态保持视觉一致：同样下移 16 逻辑像素。
                padding: EdgeInsets.only(top: ui(12) + ui(16), right: ui(12)),
                child: _PdfFullscreenToggle(
                  expanded: true,
                  onTap: () =>
                      Navigator.of(context, rootNavigator: true).maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 没有 PDF 时（`hasPdf == false`）渲染 `longText1` 这种富文本字段。
///
/// 后端典型形态有两类：
/// - 综合模拟试题：`<p><img src=".." width="100%" /><img ... />…</p>`
///   一组占满宽度的"试卷扫描图"竖向铺开；
/// - 普通文本说明：`<p>章节标题</p><p>正文…</p>` 多段文字。
///
/// 之前实现是 `replaceAll(<[^>]+>)` 一刀把 `<img>` 也剥掉，遇到第
/// 一类内容直接渲染成空白。这里改成"按 `<img>` 切块"的轻量解析：
/// - 文本段 → [SelectableText]，沿用原配色 / 字号；
/// - 图片段 → [_TheoryHtmlImage]，`width="N%"` 撑满容器宽，数字
///   宽度按设计尺寸渲染；
/// - 整个内容包在 [SingleChildScrollView] 里支持竖向滚动浏览。
class _TheoryHtmlView extends StatelessWidget {
  const _TheoryHtmlView({required this.htmlText, this.answerEndMode = false});

  final String htmlText;

  /// 答题结束页（answerEnd）：`longText1` 区域上下留白略收紧为 15。
  final bool answerEndMode;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final textStyle = TextStyle(
      color: const Color(0xFF0B081A),
      fontSize: ui(14),
      height: 1.7,
      fontFamily: 'PingFang SC',
    );
    final blocks = _parseTheoryHtmlBlocks(
      htmlText,
      textStyle: textStyle,
      verticalGap: ui(6),
    );
    if (blocks.isEmpty) {
      return const _TheoryEmptyState(message: '暂无内容');
    }
    final padding = answerEndMode
        ? EdgeInsets.fromLTRB(ui(18), ui(5), ui(18), ui(5))
        : EdgeInsets.all(ui(18));
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: blocks,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// HTML → block widgets：把 `longText1` 这种简单结构的 HTML 拆成
// `[Text, Image, Text, Image, ...]` 一组块级 widget，喂给上面的
// SingleChildScrollView。
// ─────────────────────────────────────────────────────────────────────

final RegExp _theoryImgRegExp = RegExp(
  r'<img\b[^>]*?/?>',
  caseSensitive: false,
);
final RegExp _theoryImgSrcRegExp = RegExp(
  r'''src\s*=\s*(['"])(.*?)\1''',
  caseSensitive: false,
);
final RegExp _theoryImgWidthRegExp = RegExp(
  r'''width\s*=\s*(['"])([^'"]*)\1''',
  caseSensitive: false,
);
final RegExp _theoryImgHeightRegExp = RegExp(
  r'''height\s*=\s*(['"])([^'"]*)\1''',
  caseSensitive: false,
);
final RegExp _theoryBrRegExp = RegExp(r'<br\s*/?>', caseSensitive: false);
final RegExp _theoryBlockEndRegExp = RegExp(
  r'</(p|div|li|tr|h[1-6])>',
  caseSensitive: false,
);
final RegExp _theoryTagStripRegExp = RegExp(r'<[^>]+>');

/// 极简实体解码——`longText1` 实际遇到的实体集中在引号 / 破折号
/// / 空格这几类。需要全量解码时可以扩成 quiz_practice 那一份。
const Map<String, String> _theoryNamedEntities = <String, String>{
  'nbsp': ' ',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'ldquo': '\u201C',
  'rdquo': '\u201D',
  'lsquo': '\u2018',
  'rsquo': '\u2019',
  'hellip': '\u2026',
  'mdash': '\u2014',
  'ndash': '\u2013',
  'middot': '\u00B7',
  'times': '\u00D7',
  'divide': '\u00F7',
  'deg': '\u00B0',
};
final RegExp _theoryEntityRegExp = RegExp(
  r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z][a-zA-Z0-9]+);',
);

String _decodeTheoryEntities(String input) {
  if (input.isEmpty || !input.contains('&')) return input;
  return input.replaceAllMapped(_theoryEntityRegExp, (m) {
    final body = m.group(1)!;
    if (body.startsWith('#x') || body.startsWith('#X')) {
      final cp = int.tryParse(body.substring(2), radix: 16);
      if (cp != null && cp >= 0 && cp <= 0x10FFFF) {
        return String.fromCharCode(cp);
      }
    } else if (body.startsWith('#')) {
      final cp = int.tryParse(body.substring(1));
      if (cp != null && cp >= 0 && cp <= 0x10FFFF) {
        return String.fromCharCode(cp);
      }
    } else {
      final v = _theoryNamedEntities[body];
      if (v != null) return v;
    }
    return m.group(0)!;
  });
}

List<Widget> _parseTheoryHtmlBlocks(
  String html, {
  required TextStyle textStyle,
  required double verticalGap,
}) {
  final blocks = <Widget>[];
  final pendingText = StringBuffer();

  void flushText() {
    if (pendingText.isEmpty) return;
    final raw = pendingText.toString();
    pendingText.clear();
    final stripped = raw
        .replaceAll(_theoryBrRegExp, '\n')
        .replaceAll(_theoryBlockEndRegExp, '\n')
        .replaceAll(_theoryTagStripRegExp, '');
    final cleaned = _decodeTheoryEntities(
      stripped,
    ).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (cleaned.isEmpty) return;
    blocks.add(
      Padding(
        padding: EdgeInsets.symmetric(vertical: verticalGap),
        child: SelectableText(cleaned, style: textStyle),
      ),
    );
  }

  var cursor = 0;
  for (final m in _theoryImgRegExp.allMatches(html)) {
    if (m.start > cursor) {
      pendingText.write(html.substring(cursor, m.start));
    }
    flushText();

    final tag = m.group(0)!;
    final src = _theoryImgSrcRegExp.firstMatch(tag)?.group(2)?.trim();
    if (src != null && src.isNotEmpty) {
      final widthAttr = _theoryImgWidthRegExp.firstMatch(tag)?.group(2) ?? '';
      final heightAttr = _theoryImgHeightRegExp.firstMatch(tag)?.group(2) ?? '';
      final fillWidth = widthAttr.endsWith('%');
      final designW = fillWidth ? null : double.tryParse(widthAttr);
      final designH = double.tryParse(heightAttr);
      blocks.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: verticalGap),
          child: _TheoryHtmlImage(
            url: src,
            designWidth: designW,
            designHeight: designH,
            fillWidth: fillWidth,
          ),
        ),
      );
    }
    cursor = m.end;
  }
  if (cursor < html.length) {
    pendingText.write(html.substring(cursor));
  }
  flushText();

  return blocks;
}

/// 给 [_TheoryHtmlView] 渲染富文本里 `<img>` 的图片 widget。
///
/// - `fillWidth = true`（width="100%" 这种情况）：撑满父容器宽
///   度，高度按图片本身比例自适应；典型场景是综合模拟试题的卷
///   面扫描图竖向铺开。
/// - `fillWidth = false` 且有 `designWidth/designHeight`：按设计
///   尺寸渲染。
/// - 都没有：交给 [CachedNetworkImage] 用图片自身 intrinsic 尺寸。
class _TheoryHtmlImage extends StatelessWidget {
  const _TheoryHtmlImage({
    required this.url,
    this.designWidth,
    this.designHeight,
    this.fillWidth = false,
  });

  final String url;
  final double? designWidth;
  final double? designHeight;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    if (fillWidth) {
      return CachedNetworkImage(
        imageUrl: url,
        cacheKey: url,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, _) => const SizedBox(
          height: 80,
          child: Center(
            child: AppLoadingIndicator(),
          ),
        ),
        errorWidget: (context, _, _) => Container(
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.broken_image_rounded,
            color: Color(0xFFC9C6D8),
          ),
        ),
      );
    }

    final w = designWidth;
    final h = designHeight;
    return Align(
      alignment: Alignment.centerLeft,
      child: CachedNetworkImage(
        imageUrl: url,
        cacheKey: url,
        width: w,
        height: h,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, _) => SizedBox(width: w ?? 40, height: h ?? 40),
        errorWidget: (context, _, _) => Container(
          width: w ?? 60,
          height: h ?? 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.broken_image_rounded,
            color: Color(0xFFC9C6D8),
          ),
        ),
      ),
    );
  }
}

class _TheoryEmptyState extends StatelessWidget {
  const _TheoryEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.menu_book_outlined,
            color: const Color(0xFFC9C6D8),
            size: ui(40),
          ),
          SizedBox(height: ui(12)),
          Text(
            message,
            style: TextStyle(
              color: const Color(0xFFC9C6D8),
              fontSize: ui(13),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(32),
        height: ui(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        child: Icon(icon, size: ui(16), color: const Color(0xFF1C274C)),
      ),
    );
  }
}

class _SecondaryChipButton extends StatelessWidget {
  const _SecondaryChipButton({
    this.icon,
    this.iconAsset,
    required this.label,
    required this.onTap,
  }) : assert(
         icon != null || iconAsset != null,
         'Either icon or iconAsset must be provided',
       );

  final IconData? icon;
  final String? iconAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const labelColor = Color(0xFF0B081A);
    final leading = iconAsset != null
        ? Image.asset(
            iconAsset!,
            width: ui(20),
            height: ui(20),
            fit: BoxFit.contain,
          )
        : Icon(icon!, size: ui(20), color: const Color(0xFF1C274C));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: ui(34),
        padding: EdgeInsets.symmetric(horizontal: ui(10)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            leading,
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
