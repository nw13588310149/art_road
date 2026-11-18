import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../data/creative_models.dart';
import '../../state/creative_controllers.dart';
import 'topic_reader.dart';
import 'topic_row.dart';

/// 一份课件最多带的资料数。
const topicResourceLimit = 12;

/// 表单里的「阅读资料」：上传，或从书刊里勾选。勾选的顺序就是阅读顺序，
/// 第一份作为封面。刚上传的资料排在最前面，一直是选中的。
class TopicResourcePicker extends ConsumerWidget {
  const TopicResourcePicker({
    required this.selected,
    required this.onToggle,
    required this.onUpload,
    this.uploading = false,
    this.enabled = true,
    this.errorText,
    super.key,
  });
  final List<ReadingResource> selected;
  final ValueChanged<ReadingResource> onToggle;
  final VoidCallback onUpload;
  final bool uploading, enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(readingResourcesProvider);
    final error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionTitle(
          title: '阅读资料',
          note: '已选 ${selected.length} / $topicResourceLimit 份 · 第一份作为封面',
          trailing: Transform.translate(
            offset: const Offset(AppSpace.s12, 0),
            child: AppPlainButton(
              label: uploading ? '正在上传' : '上传 PDF / 图片',
              icon: Icons.file_upload_outlined,
              enabled: enabled && !uploading,
              onTap: onUpload,
            ),
          ),
        ),
        Text(
          '支持 PDF、JPG、PNG，每份不超过 20 MB；一次上传的几张图片会合成一本图片书籍。',
          style: AppText.body13,
        ),
        if (error != null && error.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s4),
          Text(
            error,
            style: AppText.caption12.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: AppSpace.s12),
        library.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpace.s24),
            child: Center(child: AppLoadingIndicator()),
          ),
          error: (_, _) => AppErrorState(
            title: '书刊加载失败',
            description: '已上传的资料不受影响，可以重试后再勾选书刊。',
            onRetry: () => ref.invalidate(readingResourcesProvider),
          ),
          data: (items) {
            final books = items.where((item) => !item.id.startsWith('sample-'));
            final rows = [
              for (final item in selected)
                if (!books.any((book) => book.id == item.id)) item,
              ...books,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final resource in rows) ...[
                  const AppRule(),
                  _Choice(
                    resource: resource,
                    order: selected.indexWhere((r) => r.id == resource.id),
                    enabled: enabled,
                    onTap: () => onToggle(resource),
                  ),
                ],
                const AppRule(),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// 一份可选的资料：勾选框、封面、名称和类型；选中后写出是第几份。
class _Choice extends StatelessWidget {
  const _Choice({
    required this.resource,
    required this.order,
    required this.enabled,
    required this.onTap,
  });
  final ReadingResource resource;

  /// 在已选里的位置，没选是 -1。
  final int order;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final checked = order >= 0;
    final meta = [
      topicResourceKind(resource),
      if (checked) order == 0 ? '第 1 份，作为封面' : '第 ${order + 1} 份',
    ].join(' · ');
    return AppPressable(
      onTap: onTap,
      enabled: enabled,
      checked: checked,
      semanticLabel: '选择${resource.title}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
          child: Row(
            children: [
              _CheckMark(checked: checked),
              const SizedBox(width: AppSpace.s16),
              TopicCover(src: resource.cover, width: 36),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body14Strong,
                    ),
                    Text(meta, style: AppText.caption12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 勾选框只是标记，整行可点。选中用墨色，控件的选中态不用品牌紫。
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: checked ? AppColors.ink : AppColors.surface,
      borderRadius: AppRadius.br4,
      border: Border.all(
        color: checked ? AppColors.ink : AppColors.textTertiary,
        width: 1.5,
      ),
    ),
    child: checked
        ? const Icon(Icons.check_rounded, size: 14, color: AppColors.surface)
        : null,
  );
}
