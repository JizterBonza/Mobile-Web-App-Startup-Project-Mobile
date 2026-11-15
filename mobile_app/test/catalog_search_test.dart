import 'dart:async';
import 'dart:convert';

import 'package:agriconnect/models/catalog_search.dart';
import 'package:agriconnect/provider/items_provider.dart';
import 'package:agriconnect/services/items_services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> groupedPayload() => {
      'success': true,
      'query': 'kelso',
      'data': {
        'items': [
          {
            'item_id': 42,
            'item_name': 'Kelso Gamefowl Feed',
            'image': 'items/kelso-feed.jpg',
            'price': 850
          }
        ],
        'shops': [
          {
            'shop_id': 42,
            'name': 'Kelso Agrivet Supply',
            'image': 'shops/kelso-agrivet-logo.jpg'
          }
        ],
        'gamefowl': [
          {
            'listing_id': 42,
            'farm_id': 7,
            'name': 'Kelso Red',
            'image': 'gamefowls/kelso-red.jpg',
            'price': 1500,
            'is_bundle': false
          },
          {
            'listing_id': 102,
            'farm_id': 7,
            'name': 'Kelso Breeding Pair',
            'image': '/storage/gamefowls/kelso-pair.jpg',
            'price': 2800,
            'is_bundle': true
          },
        ],
      },
      'count': {'items': 11, 'shops': 1, 'gamefowl': 2},
    };

class _PendingSearch extends ItemsService {
  final pending = <Completer<CatalogSearchResponse>>[];
  @override
  Future<CatalogSearchResponse> searchCatalog(String query, {int limit = 20}) {
    final response = Completer<CatalogSearchResponse>();
    pending.add(response);
    return response.future;
  }
}

void main() {
  setUp(() {
    dotenv.testLoad(
        fileInput:
            'TEST_URL=https://example.test\nSTAGING_URL=https://example.test\nPROD_URL=https://example.test');
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
  });

  test('parses grouped summaries, IDs, prices, bundles, query and counts', () {
    final result = CatalogSearchResponse.fromJson(groupedPayload());
    expect(result.query, 'kelso');
    expect(result.count, {'items': 11, 'shops': 1, 'gamefowl': 2});
    expect(result.items.single.type, SearchResultType.product);
    expect(result.items.single.name, 'Kelso Gamefowl Feed');
    expect(result.items.single.price, 850);
    expect(result.itemData.single['item_id'], 42);
    expect(result.itemData.single['id'], 42);
    expect(result.itemData.single['_search_result_type'], 'product');
    expect(result.itemData.single.containsKey('item_quantity'), isFalse);
    expect(result.shops.single.type, SearchResultType.shop);
    expect(result.shops.single.price, isNull);
    expect(result.gamefowl.first.farmId, 7);
    expect(result.gamefowl.first.isBundle, isFalse);
    expect(result.gamefowl.last.isBundle, isTrue);
    expect(result.items.single.imageUrl,
        'https://example.test/storage/items/kelso-feed.jpg');
    expect(result.shops.single.imageUrl,
        'https://example.test/storage/shops/kelso-agrivet-logo.jpg');
    expect(result.gamefowl.last.imageUrl,
        'https://example.test/storage/gamefowls/kelso-pair.jpg');
  });

  test('preserves absolute image URLs and supports the previous item response',
      () {
    final result = CatalogSearchResponse.fromJson({
      'data': [
        {
          'id': 9,
          'item_name': 'Old feed',
          'item_price': '1000.10',
          'category': 1,
          'item_quantity': 5,
          'item_images': ['https://cdn.example.test/feed.jpg']
        },
      ]
    }, query: 'feed');
    expect(result.items.single.imageUrl, 'https://cdn.example.test/feed.jpg');
    expect(result.items.single.price, 1000.1);
    expect(result.itemData.single['item_quantity'], 5);
    expect(result.itemData.single.containsKey('_search_result_type'), isFalse);
    expect(result.query, 'feed');
    expect(result.shops, isEmpty);
    expect(result.gamefowl, isEmpty);
    expect(result.count['items'], 1);
  });

  test('empty groups work and invalid response shapes report errors', () {
    expect(
        CatalogSearchResponse.fromJson({
          'success': true,
          'data': {
            'items': [],
            'shops': [],
            'gamefowl': [],
          }
        }).isEmpty,
        isTrue);
    for (final invalid in [
      [],
      {'data': null},
      {'success': false, 'data': {}},
      {
        'data': {'shops': 'invalid'}
      },
      {
        'data': {
          'items': [false]
        }
      },
      {
        'data': {
          'gamefowl': [
            {'name': 'Missing listing ID'}
          ]
        }
      },
    ]) {
      expect(
          () => CatalogSearchResponse.fromJson(invalid), throwsFormatException);
    }
  });

  test('service sends trimmed query and limit; item wrapper retains items only',
      () async {
    final service = ItemsService(httpClient: MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/search');
      expect(request.url.queryParameters, {'q': 'kelso', 'limit': '7'});
      expect(request.headers['Accept'], 'application/json');
      return http.Response(jsonEncode(groupedPayload()), 200);
    }));
    final response = await service.searchCatalog(' kelso ', limit: 7);
    expect(response.shops.single.id, '42');
    expect(response.gamefowl, hasLength(2));
    final items = await service.searchItems(' kelso ', limit: 7);
    expect(items, hasLength(1));
    expect(items.single['item_name'], 'Kelso Gamefowl Feed');
  });

  test(
      'HTTP and application errors are not treated as empty successful results',
      () async {
    for (final status in [200, 500]) {
      final service = ItemsService(
          httpClient: MockClient((_) async => http.Response(
              jsonEncode({'success': false, 'data': {}}), status)));
      await expectLater(service.searchCatalog('kelso'), throwsException);
    }
  });

  test(
      'provider updates groups atomically and rejects stale work after clearing',
      () async {
    final service = _PendingSearch();
    final provider = ItemsProvider(itemsService: service);
    addTearDown(provider.dispose);
    final older = provider.searchCatalog('old');
    final latest = provider.searchCatalog('kelso');
    final result = CatalogSearchResponse.fromJson(groupedPayload());
    service.pending.last.complete(result);
    await latest;
    expect(provider.catalogSearchResults.shops, hasLength(1));
    expect(provider.catalogSearchResults.gamefowl, hasLength(2));
    expect(provider.searchResults, hasLength(1));
    service.pending.first.complete(const CatalogSearchResponse());
    await older;
    expect(provider.catalogSearchResults, same(result));
    final pending = provider.searchCatalog('again');
    provider.clearSearch();
    service.pending.last.complete(result);
    expect((await pending).isEmpty, isTrue);
    expect(provider.catalogSearchResults.isEmpty, isTrue);
    expect(provider.searchResults, isEmpty);
  });
}
