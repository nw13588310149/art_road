import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/artwork_repository.dart';

/// 校长点评与推优（按作品 id）。
final principalArtworkActionsProvider = Provider.autoDispose
    .family<PrincipalArtworkActions, String>((ref, artworkId) {
      return PrincipalArtworkActions(
        repository: ref.watch(artworkRepositoryProvider),
        artworkId: artworkId,
      );
    });

class PrincipalArtworkActions {
  PrincipalArtworkActions({
    required ArtworkRepository repository,
    required this.artworkId,
  }) : _repository = repository;

  final ArtworkRepository _repository;
  final String artworkId;

  Future<String?> comment(String content) async {
    final text = content.trim();
    if (text.runes.length < 5) {
      return '校长点评至少 5 个字';
    }
    final response = await _repository.principalComment(
      artworkId: artworkId,
      content: text,
    );
    return response.isSuccess ? null : response.errorOr('点评失败，请稍后重试');
  }

  Future<String?> setFeatured(bool featured) async {
    final response = await _repository.principalFeature(
      artworkId: artworkId,
      featured: featured,
    );
    return response.isSuccess ? null : response.errorOr('推优失败，请稍后重试');
  }
}
