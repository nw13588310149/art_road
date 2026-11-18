// 新页面方向稿的入口：`/design-system/directions?d=a&p=today`。
//
// 临时代码，见 direction_kit.dart 开头的说明。`d` 取 a / b / c，`p` 取 today / ebooks；
// 带 `bare=1` 时不显示底部的切换条，用来截图。
import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import 'direction_a.dart';
import 'direction_b.dart';
import 'direction_c.dart';

const draftDirections = <String, String>{
  'a': '一 留白',
  'b': '二 栅格',
  'c': '三 主视觉',
};

const draftPages = <String, String>{'today': '今日', 'ebooks': '电子书刊'};

class DirectionDraftPage extends StatelessWidget {
  const DirectionDraftPage({
    required this.direction,
    required this.page,
    this.bare = false,
    super.key,
  });

  factory DirectionDraftPage.fromArgs(Map<String, dynamic> args) {
    final direction = '${args['d'] ?? ''}';
    final page = '${args['p'] ?? ''}';
    return DirectionDraftPage(
      direction: draftDirections.containsKey(direction) ? direction : 'a',
      page: draftPages.containsKey(page) ? page : 'today',
      bare: '${args['bare'] ?? ''}' == '1',
    );
  }

  final String direction;
  final String page;
  final bool bare;

  /// 外壳按这个路由高亮左导航，方向稿看起来就在它要替换的那一页的位置上。
  String get shellRoute =>
      page == 'ebooks' ? RoutePaths.ebooks : RoutePaths.today;

  @override
  Widget build(BuildContext context) {
    final draft = switch ((direction, page)) {
      ('a', 'ebooks') => const DirectionAEbooks(),
      ('a', _) => const DirectionAToday(),
      ('b', 'ebooks') => const DirectionBEbooks(),
      ('b', _) => const DirectionBToday(),
      (_, 'ebooks') => const DirectionCEbooks(),
      _ => const DirectionCToday(),
    };
    if (bare) return draft;
    return Stack(
      children: [
        Positioned.fill(child: draft),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpace.s12,
          child: Center(child: _Switcher(direction: direction, page: page)),
        ),
      ],
    );
  }
}

/// 底部的切换条：换方向、换页面、退出。只在应用里看方向稿时出现。
class _Switcher extends StatelessWidget {
  const _Switcher({required this.direction, required this.page});

  final String direction;
  final String page;

  void _open(BuildContext context, String direction, String page) {
    Navigator.of(context).pushReplacementNamed(
      RoutePaths.designDirections,
      arguments: <String, dynamic>{'d': direction, 'p': page},
    );
  }

  @override
  Widget build(BuildContext context) {
    final divider = Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      color: AppColors.onBrand.withValues(alpha: 0.2),
    );
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.92),
        borderRadius: AppRadius.brPill,
        boxShadow: AppShadow.overlay,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
            child: Text(
              '方向稿',
              style: AppText.caption12.copyWith(
                color: AppColors.onBrand.withValues(alpha: 0.6),
              ),
            ),
          ),
          for (final entry in draftDirections.entries)
            _Item(
              label: entry.value,
              selected: entry.key == direction,
              onTap: () => _open(context, entry.key, page),
            ),
          divider,
          for (final entry in draftPages.entries)
            _Item(
              label: entry.value,
              selected: entry.key == page,
              onTap: () => _open(context, direction, entry.key),
            ),
          divider,
          _Item(
            label: '退出',
            onTap: () => Navigator.of(
              context,
            ).pushReplacementNamed(RoutePaths.designSystem),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.label, required this.onTap, this.selected = false});

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      selected: selected,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.onBrand : null,
          borderRadius: AppRadius.brPill,
        ),
        child: Text(
          label,
          style: AppText.body13.copyWith(
            color: selected ? AppColors.ink : AppColors.onBrand,
          ),
        ),
      ),
    );
  }
}
