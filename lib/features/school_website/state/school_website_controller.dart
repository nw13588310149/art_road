import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/school_website_repository.dart';
import 'school_website_state.dart';

final schoolWebsiteControllerProvider =
    StateNotifierProvider.autoDispose<
      SchoolWebsiteController,
      SchoolWebsiteState
    >((ref) {
      final repo = ref.watch(schoolWebsiteRepositoryProvider);
      return SchoolWebsiteController(repository: repo);
    });

class SchoolWebsiteController extends StateNotifier<SchoolWebsiteState> {
  SchoolWebsiteController({required SchoolWebsiteRepository repository})
    : _repository = repository,
      super(const SchoolWebsiteState()) {
    unawaited(_load());
  }

  final SchoolWebsiteRepository _repository;

  /// 加载失败后重试。
  Future<void> reload() => _load();

  Future<void> _load() async {
    state = state.copyWith(loading: true, errorMessage: '');
    final response = await _repository.getHomePage();
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(loading: false, errorMessage: response.displayMsg);
      return;
    }
    final data = response.data;
    final html = parseSchoolHomePageHtml(data);
    if (html == null || html.isEmpty) {
      state = state.copyWith(loading: false, errorMessage: '暂无官网内容');
      return;
    }
    final title = data is Map ? data['title']?.toString().trim() ?? '' : '';
    state = state.copyWith(loading: false, htmlContent: html, title: title);
  }
}
