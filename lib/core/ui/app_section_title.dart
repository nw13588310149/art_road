import 'package:flutter/widgets.dart';

import 'app_spacing.dart';
import 'app_text.dart';

/// 新页面的分区标题：16 号粗体，后面可以跟一句小字（数量、口径），右边可以放
/// 一个次要操作。分区靠它和上方的留白分开，不用卡片包起来。
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    required this.title,
    this.note = '',
    this.trailing,
    super.key,
  });

  final String title;
  final String note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(header: true, child: Text(title, style: AppText.title16)),
        if (note.isNotEmpty) ...[
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption12,
            ),
          ),
        ] else
          const Spacer(),
        ?trailing,
      ],
    );
  }
}
