import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/artwork_repository.dart';

/// 校长点评与推优（按作品 id）。
final principalArtworkActionsProvider = StateNotifierProvider.autoDispose
    .family<PrincipalArtworkActions, bool, String>((ref, artworkId) {
      return PrincipalArtworkActions(
        repository: ref.watch(artworkRepositoryProvider),
        artworkId: artworkId,
      );
    });

class PrincipalArtworkActions extends StateNotifier<bool> {
  PrincipalArtworkActions({
    required ArtworkRepository repository,
    required this.artworkId,
  }) : _repository = repository,
       super(false);

  final ArtworkRepository _repository;
  final String artworkId;

  Future<String?> comment(String content, {double? score}) async {
    if (state) return '正在提交，请稍候';
    final text = content.trim();
    if (text.runes.length < 5) {
      return '校长点评至少 5 个字';
    }
    state = true;
    try {
      final response = await _repository.principalComment(
        artworkId: artworkId,
        content: text,
        score: score,
      );
      return response.isSuccess ? null : response.errorOr('点评失败，请稍后重试');
    } finally {
      if (mounted) state = false;
    }
  }

  Future<String?> setFeatured(bool featured) async {
    if (state) return '正在提交，请稍候';
    state = true;
    try {
      final response = await _repository.principalFeature(
        artworkId: artworkId,
        featured: featured,
      );
      return response.isSuccess ? null : response.errorOr('推优失败，请稍后重试');
    } finally {
      if (mounted) state = false;
    }
  }
}
