import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/ebook_models.dart';
import '../../state/ebook_reader_controller.dart';

/// 目录与书签抽屉；点条目返回要跳转的页码。
class EbookTocDrawer extends StatelessWidget {
  const EbookTocDrawer({required this.state, required this.visible, super.key});

  final EbookReaderState state;

  /// 当前这一屏显示的页码。
  final List<int> visible;

  EbookTocEntry? _chapterOf(int page) {
    EbookTocEntry? match;
    for (final entry in state.toc) {
      if (entry.page <= page) {
        match = entry;
      }
    }
    return match;
  }

  @override
  Widget build(BuildContext context) {
    final current = _chapterOf(visible.last);
    final bookmarks = state.bookmarks.toList()..sort();
    return AppDrawer(
      title: '目录与书签',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionTitle(
            title: '目录',
            note: state.toc.isEmpty ? '' : '${state.toc.length} 章',
          ),
          const SizedBox(height: AppSpace.s4),
          if (state.toc.isEmpty)
            Text('这本书刊没有目录。', style: AppText.body13)
          else
            for (final (index, entry) in state.toc.indexed) ...[
              if (index > 0) const AppRule(),
              _DrawerRow(
                page: entry.page,
                title: entry.title,
                current: identical(entry, current),
                onTap: () => Navigator.of(context).pop(entry.page),
              ),
            ],
          const SizedBox(height: AppSpace.s24),
          AppSectionTitle(
            title: '书签',
            note: bookmarks.isEmpty ? '' : '${bookmarks.length} 个',
          ),
          const SizedBox(height: AppSpace.s4),
          if (bookmarks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s8),
              child: Text(
                '还没有书签。阅读时点右上角的「加书签」，可以标记当前页。',
                style: AppText.body13,
              ),
            )
          else
            for (final (index, page) in bookmarks.indexed) ...[
              if (index > 0) const AppRule(),
              _DrawerRow(
                page: page,
                title: _chapterOf(page)?.title ?? '第 $page 页',
                bookmark: true,
                onTap: () => Navigator.of(context).pop(page),
              ),
            ],
        ],
      ),
    );
  }
}

/// 抽屉里的一行：左边 44 宽的页码，右边名称；正在看的章节加粗并注明「在看」。
class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.page,
    required this.title,
    required this.onTap,
    this.current = false,
    this.bookmark = false,
  });

  final int page;
  final String title;
  final bool current;
  final bool bookmark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      selected: current,
      semanticLabel: [
        if (bookmark) '书签',
        '第 $page 页',
        title,
        if (current) '正在看',
      ].join('，'),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  '$page',
                  style: AppText.number(size: 14, color: AppColors.textTertiary),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: current ? AppText.body14Strong : AppText.body14,
                  ),
                ),
              ),
              if (current) ...[
                const SizedBox(width: AppSpace.s12),
                Text('正在看', style: AppText.caption12Strong),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 跳到指定页：输入页码，超出范围时在输入框下面提示。
class EbookJumpDialog extends StatefulWidget {
  const EbookJumpDialog({
    required this.pageCount,
    required this.current,
    super.key,
  });

  final int pageCount;
  final int current;

  @override
  State<EbookJumpDialog> createState() => _EbookJumpDialogState();
}

class _EbookJumpDialogState extends State<EbookJumpDialog> {
  late final TextEditingController _input = TextEditingController(
    text: '${widget.current}',
  );
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final page = int.tryParse(_input.text.trim());
    if (page == null || page < 1 || page > widget.pageCount) {
      setState(() => _error = '请输入 1–${widget.pageCount} 之间的页码');
      return;
    }
    Navigator.of(context).pop(page);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final textStyle = AppText.body14.copyWith(color: AppColors.ink);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: AppRadius.br8,
      borderSide: BorderSide(color: color),
    );
    return AppDialog(
      title: '跳到指定页',
      message: '共 ${widget.pageCount} 页',
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(label: '跳转', onTap: _submit),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: AppTextField(
              controller: _input,
              autofocus: true,
              maxLines: 1,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _submit(),
              textAlignVertical: TextAlignVertical.center,
              cursorColor: AppColors.brand,
              cursorWidth: 1.5,
              cursorHeight: 16,
              style: textStyle,
              decoration: InputDecoration(
                hintText: '输入 1–${widget.pageCount}',
                hintStyle: textStyle.copyWith(color: AppColors.textPlaceholder),
                hintFadeDuration: Duration.zero,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                filled: true,
                fillColor: AppColors.surface,
                enabledBorder: border(
                  error == null ? AppColors.line : AppColors.danger,
                ),
                focusedBorder: border(
                  error == null ? AppColors.brand : AppColors.danger,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error,
              style: AppText.caption12.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}
