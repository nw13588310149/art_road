import 'package:flutter/material.dart';

import '../../study_catalog/state/study_catalog_state.dart';
import '../../study_catalog/ui/study_catalog_page.dart';

/// 智能视唱二级列表：布局与听写二级页一致；顶部留白对齐智能听写闯关列表（14px）。
class SmartSightSingingCatalogPage extends StatelessWidget {
  const SmartSightSingingCatalogPage({super.key});

  @override
  Widget build(BuildContext context) => const StudyCatalogPage(
        defaultArgs: StudyCatalogPageArgs(
          config: StudyCatalogConfig.smartSightSinging,
          initialFirstMenuId: '1',
        ),
      );
}
