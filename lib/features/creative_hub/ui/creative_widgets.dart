import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/art/art_subject.dart';
import '../../../core/ui/ui.dart';
import '../../ebooks/ui/ebook_reader_page.dart';
import '../data/creative_models.dart';
import '../state/creative_controllers.dart';
import 'creative_pdf_reader.dart';

const creativeSubjects = ['素描', '色彩', '速写', '美术常识'];

class CreativeHeading extends StatelessWidget {
  const CreativeHeading({
    required this.title,
    required this.subtitle,
    this.onBack,
    this.actions = const [],
    super.key,
  });
  final String title, subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (onBack != null) ...[
        AppIconButton.back(onTap: onBack),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.title24),
            const SizedBox(height: 4),
            Text(subtitle, style: AppText.body13),
          ],
        ),
      ),
      ...actions,
    ],
  );
}

class CreativeSubjectFilter extends StatelessWidget {
  const CreativeSubjectFilter({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      AppChip(
        label: '全部科目',
        selected: value.isEmpty,
        onTap: () => onChanged(''),
      ),
      for (final name in creativeSubjects)
        AppChip(
          label: ArtSubject.tryParse(name)?.label ?? name,
          selected: value == name,
          onTap: () => onChanged(name),
        ),
    ],
  );
}

class CreativeSubjectSelect extends StatelessWidget {
  const CreativeSubjectSelect({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => AppSelect<String>(
    value: value,
    onChanged: onChanged,
    options: [
      for (final name in creativeSubjects)
        AppSelectOption(
          value: name,
          label: ArtSubject.tryParse(name)?.label ?? name,
        ),
    ],
  );
}

Future<void> openReadingResource(
  BuildContext context,
  ReadingResource resource,
) async {
  if (resource.bookId.isNotEmpty) {
    await Navigator.of(
      context,
    ).push(EbookReaderPage.route(bookId: resource.bookId));
  } else {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => _ResourceReader(resource: resource),
      ),
    );
  }
}

class _ResourceReader extends ConsumerWidget {
  const _ResourceReader({required this.resource});
  final ReadingResource resource;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (id: resource.id, pageCount: resource.pages.length);
    final progress = !resource.isPdf && resource.pages.length > 1
        ? ref.watch(creativeReadingProvider(key))
        : null;
    final page = progress?.page ?? 0;
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AppIconButton.back(
                    onTap: () async {
                      if (progress != null) {
                        await ref
                            .read(creativeReadingProvider(key).notifier)
                            .flush();
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(resource.title, style: AppText.title16)),
                  Text(
                    resource.isPdf ? 'PDF 阅读' : '图片书籍',
                    style: AppText.body13,
                  ),
                ],
              ),
            ),
            if (progress?.error.isNotEmpty == true)
              AppNotice(message: progress!.error, tone: AppTone.warning),
            Expanded(
              child: progress?.loading == true
                  ? const Center(child: AppLoadingIndicator())
                  : resource.isPdf
                  ? CreativePdfReader(url: resource.url)
                  : resource.pages.isEmpty
                  ? const AppEmptyState(title: '暂无可阅读页面')
                  : InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: AppImage(
                          src: resource.pages[page],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
            ),
            if (!resource.isPdf && resource.pages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIconButton(
                      icon: Icons.chevron_left,
                      semanticLabel: '上一页',
                      onTap: page == 0 || progress?.loading == true
                          ? null
                          : () => ref
                                .read(creativeReadingProvider(key).notifier)
                                .goTo(page - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '${page + 1} / ${resource.pages.length}',
                        style: AppText.number(),
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.chevron_right,
                      semanticLabel: '下一页',
                      onTap:
                          page >= resource.pages.length - 1 ||
                              progress?.loading == true
                          ? null
                          : () => ref
                                .read(creativeReadingProvider(key).notifier)
                                .goTo(page + 1),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ReadingResourceTile extends StatelessWidget {
  const ReadingResourceTile({
    required this.resource,
    this.trailing,
    this.onTap,
    super.key,
  });
  final ReadingResource resource;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => AppListRow(
    leading: AppImage(
      src: resource.cover,
      width: 44,
      height: 58,
      borderRadius: AppRadius.br4,
    ),
    title: resource.title,
    subtitle: resource.isPdf ? 'PDF · 可在线阅读' : '图片书籍 · 可翻页阅读',
    trailing:
        trailing ??
        const Icon(
          Icons.arrow_forward,
          size: 18,
          color: AppColors.textSecondary,
        ),
    onTap: onTap ?? () => openReadingResource(context, resource),
  );
}
