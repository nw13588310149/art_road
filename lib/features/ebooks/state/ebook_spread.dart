import 'package:flutter/foundation.dart';

/// 阅读器版式：一屏一页（阅读器固定用单页），或双页并排（1–2、3–4…）。
///
/// 页码从 1 开始；一屏以「起始页」表示，双页时起始页总是奇数。
@immutable
class EbookSpread {
  const EbookSpread({required this.pageCount, this.twoPage = false});

  final int pageCount;
  final bool twoPage;

  int get step => twoPage ? 2 : 1;

  /// 包含 [page] 的这一屏的起始页。
  int startOf(int page) {
    if (pageCount <= 0) {
      return 1;
    }
    final p = page.clamp(1, pageCount);
    return twoPage && p.isEven ? p - 1 : p;
  }

  /// 这一屏显示的页码（单页 1 个，双页最多 2 个）。
  List<int> pagesAt(int page) {
    final start = startOf(page);
    return [start, if (twoPage && start + 1 <= pageCount) start + 1];
  }

  int lastVisible(int page) => pagesAt(page).last;

  int? next(int page) {
    final target = startOf(page) + step;
    return target <= pageCount ? target : null;
  }

  int? previous(int page) {
    final target = startOf(page) - step;
    return target >= 1 ? target : null;
  }

  /// 页码指示：`3–4 / 12` 或 `3 / 12`。
  String label(int page) {
    final pages = pagesAt(page);
    final range = pages.length == 2 ? '${pages[0]}–${pages[1]}' : '${pages[0]}';
    return '$range / $pageCount';
  }
}
