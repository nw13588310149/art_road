import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import 'creative_models.dart';

final marketRepositoryProvider = Provider(
  (ref) => MarketRepository(ref.watch(apiClientProvider)),
);

class MarketRepository {
  MarketRepository(this.client);
  final ApiClient client;
  Future<Object?> _data(Future<ApiResponse> request) async {
    final response = await request;
    if (!response.isSuccess) {
      throw StateError(
        response.displayMsg.isEmpty ? '操作失败，请稍后重试' : response.displayMsg,
      );
    }
    return response.data;
  }

  Future<List<MarketListing>> listings() async => creativeRows(
    await _data(client.get('/app/market/listings')),
  ).map(MarketListing.fromJson).toList();
  Future<MarketListing> listing(String id) async => MarketListing.fromJson(
    creativeMap(await _data(client.get('/app/market/listings/$id'))),
  );
  Future<List<MarketOrder>> orders() async => creativeRows(
    await _data(client.get('/app/market/orders')),
  ).map(MarketOrder.fromJson).toList();
  Future<MarketOrder> order(String id) async => MarketOrder.fromJson(
    creativeMap(await _data(client.get('/app/market/orders/$id'))),
  );
  Future<List<MarketAddress>> addresses() async => creativeRows(
    await _data(client.get('/app/market/addresses')),
  ).map(MarketAddress.fromJson).toList();
  Future<MarketAddress> saveAddress(CreativeJson body) async =>
      MarketAddress.fromJson(
        creativeMap(
          await _data(client.post('/app/market/addresses', data: body)),
        ),
      );
  Future<void> removeAddress(String id) async =>
      _data(client.post('/app/market/addresses/$id/remove'));
  Future<MarketListing> saveListing(CreativeJson body, {String? id}) async =>
      MarketListing.fromJson(
        creativeMap(
          await _data(
            client.post(
              id == null
                  ? '/app/market/listings'
                  : '/app/market/listings/$id/save',
              data: body,
            ),
          ),
        ),
      );
  Future<MarketListing> listingAction(String id, String action) async =>
      MarketListing.fromJson(
        creativeMap(
          await _data(client.post('/app/market/listings/$id/$action')),
        ),
      );
  Future<void> favorite(String id) async =>
      _data(client.post('/app/market/listings/$id/favorite'));
  Future<MarketOrder> createOrder(CreativeJson body) async =>
      MarketOrder.fromJson(
        creativeMap(await _data(client.post('/app/market/orders', data: body))),
      );
  Future<MarketOrder> orderAction(
    String id,
    String action, [
    CreativeJson body = const {},
  ]) async => MarketOrder.fromJson(
    creativeMap(
      await _data(client.post('/app/market/orders/$id/$action', data: body)),
    ),
  );
  Future<CreativeJson> delivery(String id) async =>
      creativeMap(await _data(client.get('/app/market/orders/$id/delivery')));
  Future<MarketModeration> moderation() async => MarketModeration.fromJson(
    creativeMap(await _data(client.get('/app/market/moderation'))),
  );
  Future<void> moderate(
    String id, {
    required bool approve,
    required String note,
  }) async => _data(
    client.post(
      '/app/market/listings/$id/moderate',
      data: {'approve': approve, 'note': note},
    ),
  );
  Future<void> report(String id, String reason) async => _data(
    client.post('/app/market/listings/$id/report', data: {'reason': reason}),
  );
  Future<void> resolveCase(
    String id, {
    required bool uphold,
    required String note,
  }) async => _data(
    client.post(
      '/app/market/cases/$id/resolve',
      data: {'uphold': uphold, 'note': note},
    ),
  );
}
