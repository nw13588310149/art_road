import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/demo/demo_accounts.dart';
import '../../../core/demo/demo_config.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/ui/shell_layout.dart';
import '../data/role_guide_store.dart';
import '../state/help_guide_controller.dart';
import '../state/help_guide_state.dart';
import 'role_guide_dialog.dart';

const _textPrimary = Color(0xFF0B081A);
const _textSecondary = Color(0xFF8E8D95);
const _softBorder = Color(0xFFF3F2F3);

class HelpGuidePage extends ConsumerStatefulWidget {
  const HelpGuidePage({super.key, this.demoMode = kDemoMode});

  /// 演示版在页头下方提供「跳过 / 恢复新手引导」（演示与截图走查用）。
  final bool demoMode;

  @override
  ConsumerState<HelpGuidePage> createState() => _HelpGuidePageState();
}

class _HelpGuidePageState extends ConsumerState<HelpGuidePage> {
  static const _guideStore = RoleGuideStore();

  final _search = TextEditingController();
  String _query = '';

  /// 全部身份是否都已看过新手引导；读取完成前为 null。
  bool? _guidesSkipped;

  @override
  void initState() {
    super.initState();
    if (widget.demoMode) {
      _guideStore.allSeen().then((value) {
        if (mounted) setState(() => _guidesSkipped = value);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 当前身份：`/myInfo` 回包前按登录 token 还原（演示账号）。
  String _currentRole() {
    final role = ref.read(shellControllerProvider).user.role.trim();
    if (role.isNotEmpty) return role;
    return DemoAccounts.fromToken(ref.read(appStorageProvider).token).roleKey;
  }

  Future<void> _toggleGuides() async {
    final skipped = _guidesSkipped ?? false;
    if (skipped) {
      await _guideStore.resetAll();
      RoleGuideLauncher.forgetSession();
    } else {
      await _guideStore.markAllSeen();
    }
    if (!mounted) return;
    setState(() => _guidesSkipped = !skipped);
    AppToast.showSuccess(
      context,
      skipped ? '已恢复，下次进入首页会显示新手引导' : '已跳过各身份的新手引导',
    );
  }

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(RoutePaths.home);
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  bool _matches(HelpGuideItem item) {
    final q = _query.trim();
    if (q.isEmpty) {
      return true;
    }
    return item.title.contains(q) ||
        item.summary.contains(q) ||
        item.steps.any((step) => step.contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(helpGuideControllerProvider);
    final controller = ref.read(helpGuideControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;
    final items = state.visibleItems.where(_matches).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuideHeader(
          onBack: _back,
          search: _search,
          onSearchChanged: (value) => setState(() => _query = value),
          onSearchCleared: _clearSearch,
          onOpenRoleGuide: () => showRoleGuide(context, role: _currentRole()),
        ),
        SizedBox(height: ui(14)),
        _CategoryBar(
          categories: state.categories,
          selectedCategoryId: state.selectedCategoryId,
          onSelected: controller.selectCategory,
        ),
        if (widget.demoMode) ...[
          SizedBox(height: ui(10)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(2)),
            child: AppNotice(
              message: _guidesSkipped == true
                  ? '演示版：新手引导已跳过，各身份进入首页时不再弹出。'
                  : '演示版：各身份第一次进入首页时会弹出新手引导。',
              // 组件库只在演示版开放，和「跳过新手引导」一起放在演示提示条里，
              // 页头保持原版的样子。
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: '组件库',
                    variant: AppButtonVariant.text,
                    size: AppButtonSize.sm,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(RoutePaths.designSystem),
                  ),
                  SizedBox(width: ui(4)),
                  AppButton(
                    label: _guidesSkipped == true ? '恢复新手引导' : '跳过新手引导',
                    variant: AppButtonVariant.text,
                    size: AppButtonSize.sm,
                    onTap: _guidesSkipped == null ? null : _toggleGuides,
                  ),
                ],
              ),
            ),
          ),
        ],
        SizedBox(height: ui(12)),
        Expanded(
          child: items.isEmpty
              ? AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: '没有找到相关指南',
                  description: '换个关键词试试，或切换到「全部」分类',
                  actionLabel: '清除搜索',
                  onAction: _clearSearch,
                )
              : _GuideGrid(items: items),
        ),
      ],
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader({
    required this.onBack,
    required this.search,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onOpenRoleGuide,
  });

  final VoidCallback onBack;
  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onOpenRoleGuide;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final back = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(ui(8)),
      child: InkWell(
        onTap: onBack,
        borderRadius: BorderRadius.circular(ui(8)),
        child: Container(
          width: ui(28),
          height: ui(28),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _softBorder),
          ),
          child: Icon(
            Icons.chevron_left_rounded,
            size: ui(20),
            color: _textPrimary,
          ),
        ),
      ),
    );
    Widget titles(CrossAxisAlignment align) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        Text(
          '操作指南',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _textPrimary,
            fontFamily: 'PingFang SC',
            fontSize: ui(16),
            height: 1.1,
            fontWeight: AppFont.w600,
          ),
        ),
        SizedBox(height: ui(3)),
        Text(
          '美育集操作指南',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFFC2C1C5),
            fontFamily: 'PingFang SC',
            fontSize: ui(10),
            height: 1.1,
            fontWeight: AppFont.w400,
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: ui(148),
          height: ui(32),
          child: AppSearchField(
            controller: search,
            hint: '搜索指南',
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
          ),
        ),
        SizedBox(width: ui(6)),
        AppButton(
          label: '新手引导',
          icon: Icons.explore_outlined,
          variant: AppButtonVariant.quiet,
          size: AppButtonSize.sm,
          onTap: onOpenRoleGuide,
        ),
      ],
    );
    return ShellPageSurface(
      height: ui(54),
      borderRadius: BorderRadius.circular(ui(14)),
      gradient: const LinearGradient(
        colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFFF9FF)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 原版页头标题居中。本页右侧多了搜索和新手引导，页头太窄时居中的标题会
          // 压到搜索框，这时标题退到返回按钮右边。
          if (constraints.maxWidth < ui(680)) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(12)),
              child: Row(
                children: [
                  back,
                  SizedBox(width: ui(10)),
                  Expanded(child: titles(CrossAxisAlignment.start)),
                  actions,
                ],
              ),
            );
          }
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned(left: ui(12), child: back),
              titles(CrossAxisAlignment.center),
              Positioned(right: ui(12), child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<HelpGuideCategory> categories;
  final String selectedCategoryId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(38),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(7)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories
              .map((category) {
                final selected = category.id == selectedCategoryId;
                return Padding(
                  padding: EdgeInsets.only(left: ui(3)),
                  child: Material(
                    color: selected ? _textPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(ui(6)),
                    child: InkWell(
                      onTap: () => onSelected(category.id),
                      borderRadius: BorderRadius.circular(ui(6)),
                      child: Container(
                        height: ui(32),
                        padding: EdgeInsets.symmetric(horizontal: ui(14)),
                        alignment: Alignment.center,
                        child: Text(
                          category.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF57545F),
                            fontFamily: 'PingFang SC',
                            fontSize: ui(12),
                            height: 1,
                            fontWeight: selected ? AppFont.w500 : AppFont.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _GuideGrid extends StatelessWidget {
  const _GuideGrid({required this.items});

  final List<HelpGuideItem> items;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= ui(760)
            ? 3
            : constraints.maxWidth >= ui(500)
            ? 2
            : 1;
        return GridView.builder(
          padding: EdgeInsets.only(bottom: ui(16)),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: ui(10),
            mainAxisSpacing: ui(12),
            mainAxisExtent: ui(204),
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _GuideCard(item: items[index]),
        );
      },
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.item});

  final HelpGuideItem item;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(ui(12)),
      child: InkWell(
        onTap: () => _showGuideDetail(context, item),
        borderRadius: BorderRadius.circular(ui(12)),
        child: Container(
          padding: EdgeInsets.all(ui(10)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ui(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textPrimary,
                  fontFamily: 'PingFang SC',
                  fontSize: ui(13),
                  height: 1.2,
                  fontWeight: AppFont.w500,
                ),
              ),
              SizedBox(height: ui(4)),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textSecondary,
                  fontFamily: 'PingFang SC',
                  fontSize: ui(10),
                  height: 1.1,
                  fontWeight: AppFont.w400,
                ),
              ),
              SizedBox(height: ui(8)),
              Expanded(child: _GuideCover(subject: item.title)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 与功能指南原版一致的渐变封面，以当前品牌和实际指南标题呈现。
class _GuideCover extends StatelessWidget {
  const _GuideCover({required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(10)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  AppColors.brandWash,
                  AppColors.brandSoft,
                  AppColors.brandDeep,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: <double>[0, 0.48, 1],
              ),
            ),
          ),
          const CustomPaint(painter: _GuideWavePainter()),
          Positioned(
            top: ui(8),
            left: ui(9),
            child: AppAssetGraphic(
              AppAssets.shellLogo,
              height: ui(16),
              fit: BoxFit.contain,
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.05),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '美育集 功能指南',
                  style: TextStyle(
                    color: AppColors.brandDeep,
                    fontFamily: 'PingFang SC',
                    fontSize: ui(22),
                    height: 1.05,
                    fontWeight: AppFont.w600,
                    shadows: const <Shadow>[
                      Shadow(color: Colors.white, blurRadius: 6),
                    ],
                  ),
                ),
                SizedBox(height: ui(5)),
                Container(
                  constraints: BoxConstraints(maxWidth: ui(190)),
                  padding: EdgeInsets.symmetric(
                    horizontal: ui(14),
                    vertical: ui(4),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandDeep,
                    borderRadius: BorderRadius.circular(ui(18)),
                  ),
                  child: Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'PingFang SC',
                      fontSize: ui(14),
                      height: 1,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ui(8),
            child: Text(
              '学画就用美育集',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontFamily: 'PingFang SC',
                fontSize: ui(6),
                height: 1,
                fontWeight: AppFont.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideWavePainter extends CustomPainter {
  const _GuideWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final glow = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0x00FFFFFF),
          Color(0xA8FFFFFF),
          Color(0x00FFFFFF),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final purple = Paint()
      ..color = AppColors.brandDeep.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (var i = 0; i < 24; i++) {
      final y = size.height * (0.13 + i * 0.034);
      final amplitude = 4.0 + i * 0.45;
      final path = Path()..moveTo(-8, y);
      for (double x = -8; x <= size.width + 8; x += 4) {
        final wave = math.sin((x / size.width * math.pi * 3.2) + i * 0.22);
        path.lineTo(x, y + wave * amplitude);
      }
      canvas.drawPath(path, i.isEven ? glow : purple);
    }

    final flare = Paint()
      ..shader =
          RadialGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: 0.78),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.52, size.height * 0.08),
              radius: size.width * 0.52,
            ),
          );
    canvas.drawRect(Offset.zero & size, flare);
  }

  @override
  bool shouldRepaint(covariant _GuideWavePainter oldDelegate) => false;
}

Future<void> _showGuideDetail(BuildContext context, HelpGuideItem item) {
  final route = item.route;
  return showAppDialog<void>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: item.title,
      message: item.summary,
      width: AppSize.dialogWide,
      actions: [
        AppButton(
          label: '关闭',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(dialogContext).pop(),
        ),
        if (route != null)
          AppButton(
            label: '去看看',
            onTap: () {
              Navigator.of(dialogContext).pop();
              if (context.mounted) {
                Navigator.of(context).pushNamed(route);
              }
            },
          ),
      ],
      child: _GuideDetailBody(item: item),
    ),
  );
}

class _GuideDetailBody extends StatelessWidget {
  const _GuideDetailBody({required this.item});

  final HelpGuideItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < item.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: AppSpace.s12),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.brandWash,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppText.number(size: 12, color: AppColors.brandDeep),
                  ),
                ),
                Expanded(child: Text(item.steps[i], style: AppText.body14)),
              ],
            ),
          ),
        if (item.tip.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s12,
              vertical: AppSpace.s8,
            ),
            decoration: BoxDecoration(
              color: AppTone.info.background,
              borderRadius: AppRadius.br8,
            ),
            child: Text(
              item.tip,
              style: AppText.body13.copyWith(color: AppTone.info.foreground),
            ),
          ),
      ],
    );
  }
}
