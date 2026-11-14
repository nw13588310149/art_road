import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/creative_models.dart';
import '../data/market_repository.dart';

final commerceProvider =
    StateNotifierProvider.autoDispose<MarketController, MarketState>(
      (ref) => MarketController(ref.watch(marketRepositoryProvider))..load(),
    );
final marketModerationProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(marketRepositoryProvider).moderation(),
);
final marketDeliveryProvider = FutureProvider.autoDispose
    .family<CreativeJson, String>(
      (ref, id) => ref.watch(marketRepositoryProvider).delivery(id),
    );

class MarketState {
  const MarketState({
    this.listings = const [],
    this.orders = const [],
    this.addresses = const [],
    this.loading = true,
    this.loaded = false,
    this.busy = false,
    this.error = '',
    this.keyword = '',
    this.subject = '',
    this.kind = '',
    this.savedOnly = false,
    this.sort = 'newest',
  });
  final List<MarketListing> listings;
  final List<MarketOrder> orders;
  final List<MarketAddress> addresses;
  final bool loading, loaded, busy, savedOnly;
  final String error, keyword, subject, kind, sort;
  MarketState copy({
    List<MarketListing>? listings,
    List<MarketOrder>? orders,
    List<MarketAddress>? addresses,
    bool? loading,
    bool? loaded,
    bool? busy,
    String? error,
    String? keyword,
    String? subject,
    String? kind,
    bool? savedOnly,
    String? sort,
  }) => MarketState(
    listings: listings ?? this.listings,
    orders: orders ?? this.orders,
    addresses: addresses ?? this.addresses,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    busy: busy ?? this.busy,
    error: error ?? this.error,
    keyword: keyword ?? this.keyword,
    subject: subject ?? this.subject,
    kind: kind ?? this.kind,
    savedOnly: savedOnly ?? this.savedOnly,
    sort: sort ?? this.sort,
  );
}

class MarketResult<T> {
  const MarketResult({this.value, this.error = ''});
  final T? value;
  final String error;
  bool get success => error.isEmpty;
}

class MarketController extends StateNotifier<MarketState> {
  MarketController(this.repository) : super(const MarketState()) {
    _expiryRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!state.busy &&
          !state.loading &&
          state.orders.any((o) => o.status == MarketOrderStatus.pendingPayment)) {
        load();
      }
    });
  }
  late final Timer _expiryRefresh;
  @override
  void dispose() {
    _expiryRefresh.cancel();
    super.dispose();
  }

  final MarketRepository repository;
  final Map<String, String> _checkoutKeys = {};
  int _loadVersion = 0;
  String _message(Object e) => '$e'.replaceFirst('Bad state: ', '');
  Future<void> load() async {
    final version = ++_loadVersion;
    state = state.copy(loading: true, error: '');
    try {
      final results = await Future.wait([
        repository.listings(),
        repository.orders(),
        repository.addresses(),
      ]);
      if (!mounted || version != _loadVersion) return;
      state = state.copy(
        loading: false,
        loaded: true,
        listings: results[0].cast<MarketListing>(),
        orders: results[1].cast<MarketOrder>(),
        addresses: results[2].cast<MarketAddress>(),
      );
    } catch (e) {
      if (mounted && version == _loadVersion) {
        state = state.copy(loading: false, error: _message(e));
      }
    }
  }

  void filter({
    String? keyword,
    String? subject,
    String? kind,
    bool? savedOnly,
    String? sort,
  }) => state = state.copy(
    keyword: keyword,
    subject: subject,
    kind: kind,
    savedOnly: savedOnly,
    sort: sort,
  );
  void clearFilters() => state = state.copy(
    keyword: '',
    subject: '',
    kind: '',
    savedOnly: false,
    sort: 'newest',
  );
  List<MarketListing> get visible {
    final list = state.listings
        .where(
          (l) =>
              l.status == MarketPublication.published &&
              (state.kind.isEmpty || l.kind.key == state.kind) &&
              (state.subject.isEmpty || l.subject == state.subject) &&
              (!state.savedOnly || l.favorite) &&
              '${l.title} ${l.author} ${l.description}'.contains(
                state.keyword.trim(),
              ),
        )
        .toList();
    list.sort(
      (a, b) => switch (state.sort) {
        'priceAsc' => a.priceCents.compareTo(b.priceCents),
        'priceDesc' => b.priceCents.compareTo(a.priceCents),
        _ => b.createdAt.compareTo(a.createdAt),
      },
    );
    return list;
  }

  Future<MarketResult<T>> run<T>(Future<T> Function() task) async {
    if (state.busy) return const MarketResult(error: '正在处理，请稍候');
    state = state.copy(busy: true, error: '');
    try {
      final result = await task();
      if (mounted) await load();
      return MarketResult(value: result);
    } catch (e) {
      if (mounted) await load();
      return MarketResult(error: _message(e));
    } finally {
      if (mounted) state = state.copy(busy: false);
    }
  }

  Future<MarketResult<MarketOrder>> checkout(
    MarketListing listing, {
    MarketAddress? address,
  }) {
    final pending = state.orders
        .where(
          (o) =>
              o.buyer &&
              o.listing.id == listing.id &&
              o.status == MarketOrderStatus.pendingPayment,
        )
        .firstOrNull;
    if (pending != null) return run(() => repository.order(pending.id));
    final scope = '${listing.id}:${listing.totalCents}:${address?.id ?? ''}';
    final key = _checkoutKeys.putIfAbsent(
      scope,
      () => 'checkout-${DateTime.now().microsecondsSinceEpoch}',
    );
    return run(() async {
      final order = await repository.createOrder({
        'listingId': listing.id,
        'idempotencyKey': key,
        'expectedPriceCents': listing.priceCents,
        'expectedTotalCents': listing.totalCents,
        'termsAccepted': true,
        if (address != null) 'addressId': address.id,
      });
      _checkoutKeys.remove(scope);
      return order;
    });
  }

  Future<MarketResult<MarketListing>> saveListing(
    CreativeJson body, {
    String? id,
  }) => run(() => repository.saveListing(body, id: id));
  Future<MarketResult<MarketListing>> listingAction(String id, String action) =>
      run(() => repository.listingAction(id, action));
  Future<MarketResult<void>> favorite(String id) =>
      run(() => repository.favorite(id));
  Future<MarketResult<MarketOrder>> orderAction(
    String id,
    String action, [
    CreativeJson body = const {},
  ]) => run(() => repository.orderAction(id, action, body));
  Future<MarketResult<MarketAddress>> saveAddress(CreativeJson body) =>
      run(() => repository.saveAddress(body));
  Future<MarketResult<void>> removeAddress(String id) =>
      run(() => repository.removeAddress(id));
  Future<MarketResult<void>> report(String id, String reason) =>
      run(() => repository.report(id, reason));
  Future<MarketResult<void>> moderate(
    String id, {
    required bool approve,
    required String note,
  }) => run(() => repository.moderate(id, approve: approve, note: note));
  Future<MarketResult<void>> resolveCase(
    String id, {
    required bool uphold,
    required String note,
  }) => run(() => repository.resolveCase(id, uphold: uphold, note: note));
}
