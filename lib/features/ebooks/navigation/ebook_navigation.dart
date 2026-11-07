import 'package:flutter/widgets.dart';

import '../data/ebook_models.dart';
import '../ui/ebook_reader_page.dart';

/// 美术书刊页的路由；主路由表登记 `RoutePaths.ebooks` 后两者保持一致。
const String kEbooksRoute = '/ebooks';

abstract final class EbookNavigation {
  /// 打开书刊页：带 [bookId] 时直接进入详情，带 [category]（key 或中文名称）时选中该分类。
  static Future<Object?> openEbooks(
    BuildContext context, {
    String bookId = '',
    String category = '',
  }) {
    return Navigator.of(context).pushNamed<Object?>(
      kEbooksRoute,
      arguments: <String, dynamic>{
        if (bookId.isNotEmpty) 'bookId': bookId,
        if (category.isNotEmpty) 'category': category,
      },
    );
  }

  /// 打开全屏阅读器（不带外壳）；[page] 为 0 时从上次的进度继续。
  /// 关闭时返回最新的阅读进度。
  static Future<EbookProgress?> openReader(
    BuildContext context, {
    required String bookId,
    int page = 0,
  }) {
    return Navigator.of(context).push<EbookProgress>(
      EbookReaderPage.route(bookId: bookId, initialPage: page),
    );
  }
}
