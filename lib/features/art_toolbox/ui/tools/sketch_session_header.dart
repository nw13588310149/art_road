import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';

/// 沉浸页的顶栏（设计语言第九节）：白底、高 64、左右 24，下面一条细线。
class SessionHeader extends StatelessWidget {
  const SessionHeader({
    required this.title,
    required this.caption,
    this.onBack,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String caption;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 64,
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
          alignment: Alignment.center,
          child: AppTitleBar(
            title: title,
            caption: caption,
            onBack: onBack,
            actions: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpace.s4),
                actions[i],
              ],
            ],
          ),
        ),
        const AppRule(),
      ],
    );
  }
}
