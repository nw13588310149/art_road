import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../logic/image_ops.dart';
import '../../logic/pigment_mix.dart';
import '../widgets/tool_panel.dart';

/// 取色结果下面的「调色参考」：两三个水粉配方，每行左边是取到的颜色、右边是
/// 估算调出的颜色，再写配方和匹配程度。配方在后台线程里算。
class GouacheMixSection extends StatefulWidget {
  const GouacheMixSection({required this.color, super.key});

  final RgbColor color;

  @override
  State<GouacheMixSection> createState() => _GouacheMixSectionState();
}

class _GouacheMixSectionState extends State<GouacheMixSection> {
  List<GouacheRecipe>? _recipes;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void didUpdateWidget(GouacheMixSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color.argb != widget.color.argb) _compute();
  }

  Future<void> _compute() async {
    final request = ++_request;
    setState(() {
      _recipes = null;
      _failed = false;
    });
    try {
      final recipes = await compute(gouacheRecipesFor, widget.color);
      if (mounted && request == _request) setState(() => _recipes = recipes);
    } catch (_) {
      if (mounted && request == _request) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _recipes;
    return ToolPanelSection(
      title: '调色参考',
      note: '左为取色，右为估算调出',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_failed)
            const ToolNote('暂时算不出配方，换个位置再取一次色试试。')
          else if (recipes == null)
            const AppSkeletonText(lines: 3, lineHeight: 28)
          else ...[
            for (var i = 0; i < recipes.length; i++) ...[
              if (i > 0) const AppRule(),
              _RecipeRow(target: widget.color, recipe: recipes[i]),
            ],
            if (recipes.isNotEmpty && recipes.first.match == MixMatch.far) ...[
              const SizedBox(height: AppSpace.s8),
              const ToolNotice('这个颜色超出常见水粉能直接调出的范围，配方只能接近色相方向'),
            ],
          ],
          const SizedBox(height: AppSpace.s8),
          const ToolNote('按常见水粉颜料估算，不同品牌有色差，以实际调出的颜色为准。'),
        ],
      ),
    );
  }
}

final TextStyle _recipeStyle = AppText.body13.copyWith(color: AppColors.ink);

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({required this.target, required this.recipe});

  final RgbColor target;
  final GouacheRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final match = recipe.match;
    return Semantics(
      container: true,
      label: '${recipe.text}，${match.label}',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          child: Row(
            children: [
              _SwatchPair(target: target, mixed: recipe.mixed),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                // 每种颜料和份数是一段，换行只发生在段与段之间。
                child: Wrap(
                  spacing: AppSpace.s4,
                  children: [
                    for (final (i, segment) in recipe.segments.indexed) ...[
                      if (i > 0) Text('+', style: _recipeStyle),
                      Text(segment, style: _recipeStyle),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              _MatchLabel(match: match),
            ],
          ),
        ),
      ),
    );
  }
}

/// 两块色并排贴在一起：左边是目标色，右边是估算调出的颜色。
class _SwatchPair extends StatelessWidget {
  const _SwatchPair({required this.target, required this.mixed});

  final RgbColor target;
  final RgbColor mixed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: AppRadius.br4,
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ColoredBox(color: Color(target.argb))),
          Expanded(child: ColoredBox(color: Color(mixed.argb))),
        ],
      ),
    );
  }
}

/// 匹配程度：状态色的小圆点加文字。
class _MatchLabel extends StatelessWidget {
  const _MatchLabel({required this.match});

  final MixMatch match;

  @override
  Widget build(BuildContext context) {
    final color = switch (match) {
      MixMatch.close => AppColors.success,
      MixMatch.rough => AppColors.warning,
      MixMatch.far => AppColors.danger,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpace.s4),
        Text(match.label, style: AppText.caption12),
      ],
    );
  }
}
