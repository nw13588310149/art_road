import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/class_share_drawer.dart';
import '../../shell/ui/shell_layout.dart';
import '../../smart_campus/navigation/group_chat_return.dart';
import '../state/consultation_detail_controller.dart';
import '../state/consultation_detail_state.dart';
import 'consultation_page.dart';

class ConsultationDetailPage extends ConsumerStatefulWidget {
  const ConsultationDetailPage({super.key});

  @override
  ConsumerState<ConsultationDetailPage> createState() =>
      _ConsultationDetailPageState();
}

class _ConsultationDetailPageState
    extends ConsumerState<ConsultationDetailPage> {
  ConsultationDetailArgs? _args;
  bool _shareDialogShowing = false;

  ConsultationDetailArgs _resolveArgs(BuildContext context) {
    if (_args != null) return _args!;
    final raw = ModalRoute.of(context)?.settings.arguments;
    _args = ConsultationDetailArgs.fromRaw(raw);
    return _args!;
  }

  @override
  Widget build(BuildContext context) {
    final args = _resolveArgs(context);
    final provider = consultationDetailControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<ConsultationDetailState>(provider, (previous, next) {
      final msg = next.errorMessage;
      if (msg.isNotEmpty &&
          msg != previous?.errorMessage &&
          next.detail != null) {
        AppToast.showError(context, msg);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.clearError();
        });
      }

      if (next.shareDialogVisible && !_shareDialogShowing) {
        _shareDialogShowing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showShareDialog(context, args);
        });
      }
    });

    final detail = state.detail;
    final Widget body;
    if (detail != null) {
      body = _DetailBody(detail: detail);
    } else if (state.loading) {
      body = const _DetailSkeleton();
    } else {
      body = AppErrorState(
        title: '资讯加载失败',
        description: state.errorMessage.isEmpty
            ? '内容可能已下架，请返回列表查看其他资讯'
            : state.errorMessage,
        onRetry: controller.reload,
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            title: '资讯',
            subtitle: detail?.source,
            onBack: () => GroupChatReturnNavigator.pop(context, ref: ref),
            actions: [
              AppButton(
                label: '分享',
                iconAsset: AppAssets.videoV2Share,
                variant: AppButtonVariant.quiet,
                size: AppButtonSize.sm,
                onTap: detail == null ? null : controller.openShareDialog,
              ),
            ],
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Future<void> _showShareDialog(
    BuildContext context,
    ConsultationDetailArgs args,
  ) async {
    if (!mounted) return;
    await showClassShareDrawer<void>(
      context: context,
      scale: DashboardScaleScope.of(context),
      child: _ConsultationShareDrawer(args: args),
    );
    _shareDialogShowing = false;
    if (mounted) {
      ref
          .read(consultationDetailControllerProvider(args).notifier)
          .closeShareDialog();
    }
  }
}

class _ConsultationShareDrawer extends ConsumerWidget {
  const _ConsultationShareDrawer({required this.args});

  final ConsultationDetailArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consultationDetailControllerProvider(args));
    final controller = ref.read(
      consultationDetailControllerProvider(args).notifier,
    );

    return ClassShareDrawer(
      title: '分享资讯',
      targetCard: ShareTargetCard(
        label: '你将分享的资讯',
        title: state.detail?.title ?? '',
        coverUrl: state.detail?.coverUrl ?? '',
        placeholderIcon: Icons.feed_rounded,
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
        final success = await controller.send();
        if (!context.mounted) return;
        if (success) {
          AppToast.showSuccess(context, '已分享到班级群');
          Navigator.of(context).maybePop();
        }
      },
    );
  }
}

/// 发布时间统一为「YYYY-MM-DD HH:mm」，不显示秒。
String _formatPublishTime(String raw) {
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) return raw;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final ConsultationDetail detail;

  @override
  Widget build(BuildContext context) {
    final time = _formatPublishTime(detail.updateTime);
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          AppSpace.s4,
          AppSpace.page,
          AppSpace.s24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpace.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detail.title, style: AppText.title24),
                  const SizedBox(height: AppSpace.s8),
                  Wrap(
                    spacing: AppSpace.s12,
                    runSpacing: AppSpace.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (detail.source.isNotEmpty)
                        Text(detail.source, style: AppText.body13),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: AppText.number(
                            size: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ViewCountLabel(count: detail.viewCount),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s20),
                  HtmlWidget(
                    detail.htmlContent.isEmpty
                        ? '<p>暂无内容</p>'
                        : detail.htmlContent,
                    textStyle: AppText.body14.copyWith(height: 1.8),
                    // 拦截 <img>：默认实现会按原始分辨率解码整张大图，iPad 上快速
                    // 滚动时多张高清图同时解码容易 OOM，改用受限 memCacheWidth 的图片。
                    customWidgetBuilder: (element) {
                      if (element.localName != 'img') return null;
                      final src = element.attributes['src']?.trim() ?? '';
                      if (src.isEmpty) return null;
                      return _ConsultationHtmlImage(
                        url: src,
                        designWidth: double.tryParse(
                          element.attributes['width'] ?? '',
                        ),
                        designHeight: double.tryParse(
                          element.attributes['height'] ?? '',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 资讯正文中的 `<img>`：按容器宽度等比缩放，解码尺寸限制在屏幕物理像素内。
class _ConsultationHtmlImage extends StatelessWidget {
  const _ConsultationHtmlImage({
    required this.url,
    this.designWidth,
    this.designHeight,
  });

  final String url;
  final double? designWidth;
  final double? designHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.maybeOf(context);
        final dpr = media?.devicePixelRatio ?? 1.0;
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (media?.size.width ?? 1024.0);

        double width = designWidth ?? maxW;
        double? height = designHeight;
        if (width > maxW) {
          if (designWidth != null && designHeight != null && designWidth! > 0) {
            height = designHeight! * (maxW / designWidth!);
          } else {
            height = null;
          }
          width = maxW;
        }
        final memCacheW = (width * dpr).clamp(1.0, 1600.0).toInt();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: AppRadius.br8,
              child: CachedNetworkImage(
                imageUrl: url,
                width: width,
                height: height,
                fit: BoxFit.contain,
                memCacheWidth: memCacheW,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                errorWidget: (context, error, stackTrace) => Container(
                  width: width,
                  height: height ?? 60,
                  alignment: Alignment.center,
                  color: AppColors.surfaceSubtle,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textPlaceholder,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.s4,
        AppSpace.page,
        AppSpace.s24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: const AppCard(
            padding: EdgeInsets.all(AppSpace.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 420, height: 28),
                SizedBox(height: AppSpace.s12),
                AppSkeleton(width: 240, height: 14),
                SizedBox(height: AppSpace.s24),
                AppSkeletonText(lines: 6, lineHeight: 16),
                SizedBox(height: AppSpace.s16),
                AppSkeleton(height: 220, radius: AppRadius.control),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
