import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/ui/ui.dart';

/// Uses the bundled PDF engine so reading also works in embedded web browsers.
class CreativePdfReader extends StatefulWidget {
  const CreativePdfReader({required this.url, super.key});
  final String url;

  @override
  State<CreativePdfReader> createState() => _CreativePdfReaderState();
}

class _CreativePdfReaderState extends State<CreativePdfReader> {
  final _controller = PdfViewerController();
  int _page = 1;
  int _pageCount = 0;
  int _attempt = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: PdfViewer.uri(
          Uri.parse(widget.url),
          key: ValueKey(_attempt),
          controller: _controller,
          params: PdfViewerParams(
            backgroundColor: AppColors.surfaceSubtle,
            margin: 16,
            pageDropShadow: null,
            onViewerReady: (document, controller) {
              if (!mounted) return;
              setState(() {
                _pageCount = document.pages.length;
                _page = controller.pageNumber ?? 1;
              });
            },
            onPageChanged: (page) {
              if (mounted && page != null && page != _page) {
                setState(() => _page = page);
              }
            },
            loadingBannerBuilder: (context, received, total) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLoadingIndicator(),
                  const SizedBox(height: 12),
                  Text('正在打开 PDF', style: AppText.body13),
                ],
              ),
            ),
            errorBannerBuilder: (context, error, stack, document) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('PDF 暂时无法打开，请重试', style: AppText.body14),
                  const SizedBox(height: 16),
                  AppButton(
                    label: '重新加载',
                    onTap: () => setState(() {
                      _pageCount = 0;
                      _attempt++;
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (_pageCount > 0)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIconButton(
                icon: Icons.chevron_left,
                semanticLabel: '上一页',
                onTap: _page <= 1 ? null : () => _goTo(_page - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('$_page / $_pageCount', style: AppText.number()),
              ),
              AppIconButton(
                icon: Icons.chevron_right,
                semanticLabel: '下一页',
                onTap: _page >= _pageCount ? null : () => _goTo(_page + 1),
              ),
            ],
          ),
        ),
    ],
  );

  void _goTo(int page) {
    _controller.goToPage(pageNumber: page, duration: Duration.zero);
  }
}
