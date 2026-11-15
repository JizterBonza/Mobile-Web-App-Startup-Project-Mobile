import 'dart:async';

import 'package:agriconnect/models/catalog_search.dart';

import 'package:agriconnect/provider/items_provider.dart';
import 'package:agriconnect/services/items_services.dart';
import 'package:flutter_test/flutter_test.dart';

class _SearchService extends ItemsService {
  final requests = <String, Completer<List<Map<String, dynamic>>>>{};

  @override
  Future<CatalogSearchResponse> searchCatalog(String query, {int limit = 20}) {
    final request = Completer<List<Map<String, dynamic>>>();
    requests[query] = request;
    return request.future.then((items) =>
        CatalogSearchResponse.fromJson({'data': items}, query: query));
  }
}

void main() {
  test('only the newest response may change search results or loading',
      () async {
    final service = _SearchService();
    final provider = ItemsProvider(itemsService: service);
    addTearDown(provider.dispose);
    final older = provider.searchItems('old');
    final newer = provider.searchItems('new');
    service.requests['old']!.complete([
      {'id': 1}
    ]);
    expect(await older, isEmpty);
    expect(provider.isSearching, isTrue);
    expect(provider.searchResults, isEmpty);
    service.requests['new']!.complete([
      {'id': 2}
    ]);
    expect((await newer).map((item) => item['id']), [2]);
    expect(provider.lastSearchQuery, 'new');
    expect(provider.isSearching, isFalse);
    final stale = provider.searchItems('stale');
    final latest = provider.searchItems('latest');
    service.requests['latest']!.complete([
      {'id': 3}
    ]);
    await latest;
    service.requests['stale']!.completeError(Exception('offline'));
    await stale;
    expect(provider.searchResults.map((item) => item['id']), [3]);
    expect(provider.searchError, isNull);
  });

  test('clearing and short queries invalidate in-flight requests', () async {
    final service = _SearchService();
    final provider = ItemsProvider(itemsService: service);
    addTearDown(provider.dispose);
    for (final clear in [true, false]) {
      final pending = provider.searchItems('pending');
      if (clear) {
        provider.clearSearch();
      } else {
        await provider.searchItems('a');
      }
      service.requests['pending']!.complete([
        {'id': 1}
      ]);
      expect(await pending, isEmpty);
      expect(provider.searchResults, isEmpty);
      expect(provider.lastSearchQuery, '');
      expect(provider.isSearching, isFalse);
    }
  });

  test('disposal ignores completion without notifying listeners', () async {
    final service = _SearchService();
    final provider = ItemsProvider(itemsService: service);
    var notifications = 0;
    provider.addListener(() => notifications++);
    final pending = provider.searchItems('pending');
    provider.dispose();
    service.requests['pending']!.complete([
      {'id': 1}
    ]);
    expect(await pending, isEmpty);
    expect(notifications, 1);
  });
}
