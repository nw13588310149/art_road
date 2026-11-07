import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ebook_models.dart';
import '../data/ebook_repository.dart';

@immutable
class HomeEbookShelfData {
  const HomeEbookShelfData({required this.picks, required this.reading});

  /// 精选书刊（按「推荐」排序的前几本）。
  final List<EbookSummary> picks;

  /// 继续阅读：在读、未读完，最近读过的在前。
  final List<EbookSummary> reading;
}

/// 首页「精选书刊 / 继续阅读」；从阅读器返回后 invalidate 刷新进度。
final homeEbookShelfProvider = FutureProvider.autoDispose<HomeEbookShelfData>((
  ref,
) async {
  final repository = ref.watch(ebookRepositoryProvider);
  final responses = await Future.wait([
    repository.getBooks(size: 6),
    repository.getShelf(),
  ]);
  return HomeEbookShelfData(
    picks: responses[0].isSuccess
        ? EbookListPage.fromJson(responses[0].data).records
        : const <EbookSummary>[],
    reading: responses[1].isSuccess
        ? EbookShelf.fromJson(responses[1].data).reading
        : const <EbookSummary>[],
  );
});
