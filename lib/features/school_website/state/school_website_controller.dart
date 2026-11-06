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

  Future<void> _load() async {
    state = state.copyWith(loading: true, errorMessage: '');
    final response = await _repository.getHomePage();
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        errorMessage: response.displayMsg,
      );
      return;
    }
    final html = parseSchoolHomePageHtml(response.data);
    if (html == null || html.isEmpty) {
      state = state.copyWith(loading: false, errorMessage: '暂无官网内容');
      return;
    }
    state = state.copyWith(loading: false, htmlContent: html);
  }
}
