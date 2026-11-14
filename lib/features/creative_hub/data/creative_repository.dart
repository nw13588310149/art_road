import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import 'creative_models.dart';

final creativeRepositoryProvider = Provider(
  (ref) => CreativeRepository(ref.watch(apiClientProvider)),
);

class CreativeRepository {
  CreativeRepository(this.client);
  final ApiClient client;

  Future<int> readingProgress(String id) async =>
      (creativeMap(
                await _data(client.get('/app/creative/resources/$id/progress')),
              )['page']
              as num?)
          ?.toInt() ??
      0;
  Future<void> saveReadingProgress(String id, int page) async => _data(
    client.post('/app/creative/resources/$id/progress', data: {'page': page}),
  );

  Future<Object?> _data(Future<ApiResponse> request) async {
    final response = await request;
    if (!response.isSuccess) {
      throw StateError(
        response.displayMsg.isEmpty ? '操作失败，请重试' : response.displayMsg,
      );
    }
    return response.data;
  }

  Future<List<LearningTopic>> topics() async => creativeRows(
    await _data(client.get('/app/micro-lessons')),
  ).map(LearningTopic.fromJson).toList();
  Future<List<ReadingResource>> resources() async => creativeRows(
    await _data(client.get('/app/micro-lessons/resources')),
  ).map(ReadingResource.fromJson).toList();
  Future<List<CreativeJson>> myArtworks() async =>
      creativeRows(await _data(client.get('/app/market/my-artworks')));
  Future<void> favorite(String kind, String id) async =>
      _data(client.post('/app/$kind/$id/favorite'));
  Future<void> remove(String kind, String id) async =>
      _data(client.post('/app/$kind/$id/remove'));
  Future<String> publish(String kind, CreativeJson body) async => creativeText(
    creativeMap(await _data(client.post('/app/$kind', data: body)))['id'],
  );
  Future<ReadingResource> upload({
    required String name,
    Uint8List? bytes,
    String? path,
  }) async {
    final data = bytes != null && bytes.isNotEmpty
        ? MultipartFile.fromBytes(bytes, filename: name)
        : await MultipartFile.fromFile(path!, filename: name);
    return ReadingResource.fromJson(
      creativeMap(
        await _data(
          client.postFormData(
            '/app/creative/uploads',
            data: FormData.fromMap({'file': data}),
          ),
        ),
      ),
    );
  }

  Future<ReadingResource> imageBook(List<String> ids) async =>
      ReadingResource.fromJson(
        creativeMap(
          await _data(
            client.post(
              '/app/creative/image-books',
              data: {'resourceIds': ids},
            ),
          ),
        ),
      );
}
