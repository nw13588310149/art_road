import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/demo/demo_accounts.dart';
import '../../../core/demo/demo_config.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../shell/state/shell_controller.dart';
import '../data/role_guide_store.dart';
import '../state/help_guide_controller.dart';
import '../state/help_guide_state.dart';
import 'role_guide_dialog.dart';

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
    final items = state.visibleItems.where(_matches).toList(growable: false);

    int countOf(String categoryId) => categoryId == HelpGuideState.allCategoryId
        ? state.items.length
        : state.items.where((item) => item.categoryId == categoryId).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: AppRadius.br12,
            color: AppColors.surface,
            image: DecorationImage(
              image: AssetImage(AppAssets.profileFeedbackBg),
              fit: BoxFit.cover,
            ),
          ),
          child: AppPageHeader(
            title: '操作指南',
            subtitle: '各功能的操作说明',
            onBack: _back,
            actions: [
              SizedBox(
                width: 220,
                child: AppSearchField(
                  controller: _search,
                  hint: '搜索指南',
                  onChanged: (value) => setState(() => _query = value),
                  onCleared: _clearSearch,
                ),
              ),
              AppButton(
                label: '新手引导',
                icon: Icons.explore_outlined,
                variant: AppButtonVariant.quiet,
                size: AppButtonSize.sm,
                onTap: () => showRoleGuide(context, role: _currentRole()),
              ),
              if (widget.demoMode)
                AppButton(
                  label: '组件库（演示）',
                  icon: Icons.widgets_outlined,
                  variant: AppButtonVariant.quiet,
                  size: AppButtonSize.sm,
                  onTap: () =>
                      Navigator.of(context).pushNamed(RoutePaths.designSystem),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        AppCard(
          padding: const EdgeInsets.all(AppSpace.s4),
          bordered: false,
          radius: 8,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AppSegmented<String>(
              trackColor: AppColors.surface,
              selectedColor: AppColors.ink,
              segments: [
                for (final category in state.categories)
                  AppSegment(
                    value: category.id,
                    label: '${category.label} (${countOf(category.id)})',
                  ),
              ],
              value: state.selectedCategoryId,
              onChanged: controller.selectCategory,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        if (widget.demoMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s4,
              AppSpace.page,
              AppSpace.s12,
            ),
            child: AppNotice(
              message: _guidesSkipped == true
                  ? '演示版：新手引导已跳过，各身份进入首页时不再弹出。'
                  : '演示版：各身份第一次进入首页时会弹出新手引导。',
              action: AppButton(
                label: _guidesSkipped == true ? '恢复新手引导' : '跳过新手引导',
                variant: AppButtonVariant.text,
                size: AppButtonSize.sm,
                onTap: _guidesSkipped == null ? null : _toggleGuides,
              ),
            ),
          ),
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

class _GuideGrid extends StatelessWidget {
  const _GuideGrid({required this.items});

  final List<HelpGuideItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - AppSpace.page * 2;
        final columns = width >= 760 ? 3 : (width >= 500 ? 2 : 1);
        final rows = <List<HelpGuideItem>>[
          for (var i = 0; i < items.length; i += columns)
            items.sublist(i, (i + columns).clamp(0, items.length)),
        ];
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s4,
            AppSpace.page,
            AppSpace.s24,
          ),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s16),
          itemBuilder: (context, index) {
            final row = rows[index];
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpace.s16),
                    Expanded(
                      child: i < row.length
                          ? _GuideCard(item: row[i])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
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
    return AppCard(
      onTap: () => _showGuideDetail(context, item),
      padding: const EdgeInsets.all(AppSpace.s12),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body14Strong,
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            item.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppText.body13,
          ),
          const Spacer(),
          const SizedBox(height: AppSpace.s12),
          _GuideCover(subject: item.title),
          const SizedBox(height: AppSpace.s8),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s4,
                  children: [
                    AppTag(label: item.subtitle),
                    Text('${item.steps.length} 个步骤', style: AppText.caption12),
                  ],
                ),
              ),
              const AppAssetGraphic(
                AppAssets.listChevron,
                width: 20,
                height: 20,
              ),
            ],
          ),
        ],
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
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: AppRadius.br8,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.brandWash,
                      AppColors.brandSoft,
                      AppColors.brandDeep,
                    ],
                    stops: [0, 0.48, 1],
                  ),
                ),
                child: CustomPaint(painter: _GuideWavePainter()),
              ),
            ),
            const Positioned(
              top: AppSpace.s8,
              left: AppSpace.s8,
              child: AppAssetGraphic(
                AppAssets.shellLogo,
                height: 16,
                fit: BoxFit.contain,
              ),
            ),
            Align(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s12,
                  AppSpace.s24,
                  AppSpace.s12,
                  AppSpace.s16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '美育集 功能指南',
                      textAlign: TextAlign.center,
                      style: AppText.title20.copyWith(
                        color: AppColors.brandDeep,
                        shadows: const [
                          Shadow(color: Colors.white, blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppColors.brandDeep,
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s12,
                          vertical: AppSpace.s4,
                        ),
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: MediaQuery.textScalerOf(context),
                          text: TextSpan(
                            text: subject,
                            style: AppText.body14Strong.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        colors: [Color(0x00FFFFFF), Color(0xA8FFFFFF), Color(0x00FFFFFF)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke;
    final purple = Paint()
      ..color = AppColors.brandDeep.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (var i = 0; i < 24; i++) {
      final y = size.height * (0.13 + i * 0.034);
      final amplitude = 4.0 + i * 0.45;
      final path = Path()..moveTo(-8, y);
      for (double x = -8; x <= size.width + 8; x += 4) {
        final wave = math.sin(x / size.width * math.pi * 3.2 + i * 0.22);
        path.lineTo(x, y + wave * amplitude);
      }
      canvas.drawPath(path, i.isEven ? glow : purple);
    }
    final flare = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0xC7FFFFFF), Color(0x00FFFFFF)],
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
