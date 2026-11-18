import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/ui/ui.dart';
import '../../../ebooks/ui/ebook_reader_page.dart';
import '../../data/creative_models.dart';
import '../../state/creative_controllers.dart';
import '../creative_pdf_reader.dart';

/// 打开一份阅读资料：书刊库里的书走电子书刊的阅读器，上传的 PDF 和图片书籍走
/// [TopicReaderPage]。
Future<void> openTopicResource(
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
        pageBuilder: (_, _, _) => TopicReaderPage(resource: resource),
      ),
    );
  }
}

/// 资料的类型，列表、详情和表单里写法一致。
String topicResourceKind(ReadingResource resource) =>
    resource.isPdf ? 'PDF' : '图片书籍';

/// 沉浸阅读：白色顶栏放返回、资料名和翻页，下面整块深色底只放页面。
class TopicReaderPage extends ConsumerStatefulWidget {
  const TopicReaderPage({required this.resource, super.key});
  final ReadingResource resource;

  @override
  ConsumerState<TopicReaderPage> createState() => _TopicReaderPageState();
}

class _TopicReaderPageState extends ConsumerState<TopicReaderPage> {
  final _pdf = PdfViewerController();
  int _pdfPage = 1;
  int _pdfCount = 0;

  ReadingResource get _resource => widget.resource;
  CreativeReadingKey get _key =>
      (id: _resource.id, pageCount: _resource.pages.length);
  bool get _paged => !_resource.isPdf && _resource.pages.length > 1;

  Future<void> _close() async {
    if (_paged) await ref.read(creativeReadingProvider(_key).notifier).flush();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _paged ? ref.watch(creativeReadingProvider(_key)) : null;
    final loading = progress?.loading == true;
    final page = progress?.page ?? 0;
    void turn(int to) =>
        ref.read(creativeReadingProvider(_key).notifier).goTo(to);
    final (
      int current,
      int count,
      VoidCallback? previous,
      VoidCallback? next,
    ) = _resource.isPdf
        ? (
            _pdfPage,
            _pdfCount,
            _pdfPage <= 1 ? null : () => _goToPdf(_pdfPage - 1),
            _pdfPage >= _pdfCount ? null : () => _goToPdf(_pdfPage + 1),
          )
        : (
            page + 1,
            loading ? 0 : _resource.pages.length,
            !_paged || page == 0 || loading ? null : () => turn(page - 1),
            !_paged || page >= _resource.pages.length - 1 || loading
                ? null
                : () => turn(page + 1),
          );
    return Scaffold(
      backgroundColor: AppColors.canvasDark,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: AppColors.surface,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
                alignment: Alignment.center,
                child: AppTitleBar(
                  title: _resource.title,
                  onBack: _close,
                  actions: [
                    if (count > 0) _Pager(current, count, previous, next),
                  ],
                ),
              ),
            ),
          ),
          const AppRule(),
          if (progress?.error.isNotEmpty == true)
            AppNotice(message: progress!.error, tone: AppTone.warning),
          Expanded(
            child: SafeArea(
              top: false,
              child: loading
                  ? const Center(child: AppLoadingIndicator())
                  : _resource.isPdf
                  ? CreativePdfReader(
                      url: _resource.url,
                      backgroundColor: AppColors.canvasDark,
                      controller: _pdf,
                      onPageChanged: (page, count) => setState(() {
                        _pdfPage = page;
                        _pdfCount = count;
                      }),
                    )
                  : _resource.pages.isEmpty
                  ? Center(
                      child: Text(
                        '这份资料还没有可以阅读的页面',
                        style: AppText.body14.copyWith(
                          color: AppColors.surface,
                        ),
                      ),
                    )
                  : InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.s24),
                        child: Center(
                          child: AppImage(
                            src: _resource.pages[page],
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToPdf(int page) =>
      _pdf.goToPage(pageNumber: page, duration: Duration.zero);
}

/// 顶栏右侧的翻页：上一页、当前页 / 总页数、下一页。
class _Pager extends StatelessWidget {
  const _Pager(this.page, this.count, this.previous, this.next);
  final int page, count;
  final VoidCallback? previous, next;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppIconAction(
        icon: Icons.chevron_left_rounded,
        size: 24,
        semanticLabel: '上一页',
        color: previous == null ? AppColors.textPlaceholder : AppColors.ink,
        onTap: previous,
      ),
      SizedBox(
        width: 72,
        child: Text(
          '$page / $count',
          textAlign: TextAlign.center,
          style: AppText.number(size: 14),
        ),
      ),
      AppIconAction(
        icon: Icons.chevron_right_rounded,
        size: 24,
        semanticLabel: '下一页',
        color: next == null ? AppColors.textPlaceholder : AppColors.ink,
        onTap: next,
      ),
    ],
  );
}
