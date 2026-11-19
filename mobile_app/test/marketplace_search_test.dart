import 'dart:async';

import 'package:agriconnect/models/catalog_search.dart';

import 'package:agriconnect/provider/badge_provider.dart';
import 'package:agriconnect/provider/category_provider.dart';
import 'package:agriconnect/provider/items_provider.dart';
import 'package:agriconnect/provider/klasrum_provider.dart';
import 'package:agriconnect/provider/message_provider.dart';
import 'package:agriconnect/provider/shops_provider.dart';
import 'package:agriconnect/screens/customer/customerDashboardScreen.dart';
import 'package:agriconnect/screens/customer/farmGamefowlListingDetailScreen.dart';
import 'package:agriconnect/screens/customer/productDetailScreen.dart';
import 'package:agriconnect/screens/customer/shopScreen.dart';
import 'package:agriconnect/services/farms_service.dart';
import 'package:agriconnect/services/featured_service.dart';
import 'package:agriconnect/services/items_services.dart';
import 'package:agriconnect/widgets/search_suggestions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _catalog = <Map<String, dynamic>>[
  {'id': 1, 'item_name': 'Golden Feed', 'category': 1, 'item_price': 100},
  {'id': 2, 'item_name': 'White Bowl', 'category': 2, 'item_price': 200},
  {'id': 3, 'item_name': 'Golden Bird', 'category': 3, 'item_price': 300},
];

class _Categories extends CategoryProvider {
  @override
  List<Map<String, dynamic>> get categories => [
        {'id': 1, 'name': 'Feeds'},
        {'id': 2, 'name': 'Supplies'},
        {'id': 3, 'name': 'Gamefowl'},
      ];
  @override
  Future<void> fetchCategories({bool useCache = true}) async {}
}

class _SearchService extends ItemsService {
  bool grouped = false;
  final groupedPending = <Completer<CatalogSearchResponse>>[];
  final requests = <String>[];
  final pending = <Completer<List<Map<String, dynamic>>>>[];
  @override
  Future<CatalogSearchResponse> searchCatalog(String query, {int limit = 20}) {
    requests.add(query);
    if (grouped) {
      final result = Completer<CatalogSearchResponse>();
      groupedPending.add(result);
      return result.future;
    }
    final result = Completer<List<Map<String, dynamic>>>();
    pending.add(result);
    return result.future.then((items) =>
        CatalogSearchResponse.fromJson({'data': items}, query: query));
  }
}

class _Items extends ItemsProvider {
  _Items(_SearchService service, this.catalog) : super(itemsService: service);
  final List<Map<String, dynamic>> catalog;
  @override
  List<Map<String, dynamic>> get items => catalog;
  @override
  Future<void> fetchItems({bool useCache = true}) async {}
  @override
  Future<void> fetchItemsOnSale() async {}
  @override
  Future<void> fetchItemReviews(dynamic itemId) async {}
  List<Map<String, dynamic>> _category = [];
  @override
  List<Map<String, dynamic>> get categoryItems => _category;
  @override
  Future<void> fetchItemsByCategory(dynamic categoryId) async {
    _category =
        catalog.where((item) => item['category'] == categoryId).toList();
  }
}

class _Shops extends ShopsProvider {
  _Shops(this.catalog);
  final List<Map<String, dynamic>> catalog;
  @override
  Future<void> fetchShops({bool useCache = true, int? limit}) async {}
  @override
  Future<void> fetchShopDetails(dynamic shopId) async {}
  @override
  Future<void> fetchShopItems(dynamic shopId) async {}
  @override
  Future<void> fetchShopReviews(dynamic shopId) async {}
  @override
  Map<String, dynamic>? getShopDetails(dynamic shopId) => {
        'id': shopId,
        'shop_name': 'Test Store',
      };
  @override
  List<Map<String, dynamic>> getShopItems(dynamic shopId) => catalog;
}

class _Klasrum extends KlasrumProvider {
  @override
  Future<void> fetchFeatured() async {}
}

class _Farms extends FarmsService {
  @override
  Future<Map<String, dynamic>> fetchFarmGamefowlListing(dynamic id) async =>
      {'id': id, 'name': 'Opened gamefowl', 'price': 1500};
  @override
  Future<List<Map<String, dynamic>>> fetchFarms() async => [];
}

class _Featured extends FeaturedService {
  @override
  Future<List<Map<String, dynamic>>> fetchFeaturedProducts() async => [];
}

Future<_SearchService> _show(WidgetTester tester,
    {bool dashboard = false,
    bool grouped = false,
    List<Map<String, dynamic>> catalog = _catalog}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final service = _SearchService()..grouped = grouped;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<CategoryProvider>(create: (_) => _Categories()),
      ChangeNotifierProvider<ItemsProvider>(
          create: (_) => _Items(service, catalog)),
      ChangeNotifierProvider<ShopsProvider>(create: (_) => _Shops(catalog)),
      ChangeNotifierProvider<KlasrumProvider>(create: (_) => _Klasrum()),
      ChangeNotifierProvider<BadgeProvider>(create: (_) => BadgeProvider()),
      ChangeNotifierProvider<MessageProvider>(create: (_) => MessageProvider()),
    ],
    child: MaterialApp(
        home: dashboard
            ? CustomerDashboardScreen(
                farmsService: _Farms(), featuredService: _Featured())
            : const ShopScreen(shopId: 1)),
  ));
  await tester.pumpAndSettle();
  addTearDown(() async => tester.pumpWidget(const SizedBox()));
  return service;
}

Finder get _dropdown =>
    find.byKey(const ValueKey('search-suggestions-dropdown'));
Finder _suggestion(int id) =>
    find.byKey(ValueKey('search-suggestion-product-$id'));

CatalogSearchResponse _groupedResponse(
        {bool items = true, bool shops = true, bool gamefowl = true}) =>
    CatalogSearchResponse.fromJson({
      'success': true,
      'query': 'kelso',
      'data': {
        'items': items
            ? [
                {
                  'item_id': 42,
                  'item_name': 'Kelso Gamefowl Feed',
                  'price': 850
                }
              ]
            : [],
        'shops': shops
            ? [
                {'shop_id': 42, 'name': 'Kelso Agrivet Supply'}
              ]
            : [],
        'gamefowl': gamefowl
            ? [
                {
                  'listing_id': 42,
                  'farm_id': 7,
                  'name': 'Kelso Red',
                  'price': 1500,
                  'is_bundle': false
                },
                {
                  'listing_id': 102,
                  'farm_id': 7,
                  'name': 'Kelso Breeding Pair',
                  'price': 2800,
                  'is_bundle': true
                },
              ]
            : [],
      },
    });

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(
        fileInput:
            'TEST_URL=https://example.test\nSTAGING_URL=https://example.test\nPROD_URL=https://example.test');
  });

  testWidgets('store drafts suggest without changing grid and submit filters',
      (tester) async {
    final service = await _show(tester);
    expect(find.text('2 items'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'golden');
    await tester.pumpAndSettle();
    expect(find.text('2 items'), findsOneWidget);
    expect(_suggestion(1), findsOneWidget);
    expect(_suggestion(3), findsNothing);
    expect(service.requests, isEmpty);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('1 items'), findsOneWidget);
    expect(_dropdown, findsNothing);
    await tester.enterText(find.byType(TextField), 'bowl');
    await tester.pumpAndSettle();
    expect(find.text('1 items'), findsOneWidget);
    expect(_suggestion(2), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('2 items'), findsOneWidget);
    expect(_dropdown, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('store suggestion opens the selected product', (tester) async {
    await _show(tester);
    await tester.enterText(find.byType(TextField), 'bowl');
    await tester.pumpAndSettle();
    await tester.tap(_suggestion(2));
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(
        tester
            .widget<ProductDetailScreen>(find.byType(ProductDetailScreen))
            .productId,
        2);
    expect(_dropdown, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard debounce, merged matches and submitted snapshot',
      (tester) async {
    final service = await _show(tester, dashboard: true);
    final scrollable = tester.state<ScrollableState>(find
        .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable))
        .first);
    final offset = scrollable.position.pixels;
    await tester.enterText(find.byType(TextField), 'golden');
    await tester.pump(const Duration(milliseconds: 499));
    expect(service.requests, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(service.requests, ['golden']);
    expect(scrollable.position.pixels, offset);
    service.pending.last.complete([
      _catalog.first,
      {'id': 4, 'item_name': 'Golden Online', 'category': 1},
      _catalog.last,
    ]);
    await tester.pumpAndSettle();
    expect(_suggestion(1), findsOneWidget);
    expect(_suggestion(4), findsOneWidget);
    expect(_suggestion(3), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    service.pending.last.complete([
      _catalog.first,
      {'id': 4, 'item_name': 'Golden Online', 'category': 1},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Products matching "golden"'), findsOneWidget);
    expect(_dropdown, findsNothing);
    await tester.enterText(find.byType(TextField), 'bowl');
    await tester.pump(const Duration(milliseconds: 500));
    service.pending.last.complete([_catalog[1]]);
    await tester.pumpAndSettle();
    expect(find.text('Products matching "golden"'), findsOneWidget);
    expect(_suggestion(2), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard rejects late responses after clear or dismissal',
      (tester) async {
    final service = await _show(tester, dashboard: true);
    await tester.enterText(find.byType(TextField), 'golden');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), '');
    service.pending.last.complete([
      {'id': 9, 'item_name': 'Stale result'}
    ]);
    await tester.pumpAndSettle();
    expect(_dropdown, findsNothing);
    await tester.enterText(find.byType(TextField), 'bowl');
    await tester.pump(const Duration(milliseconds: 500));
    tester.widget<TextField>(find.byType(TextField)).focusNode!.unfocus();
    await tester.pump();
    service.pending.last.complete([
      {'id': 9, 'item_name': 'Stale result'}
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_suggestion(9), findsNothing);
    service.pending.last.completeError(Exception('offline'));
    await tester.pump();
    await tester.pump();
    expect(_suggestion(2), findsOneWidget);
    expect(
        find.text('Could not load online suggestions. Showing local matches.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard checks online product names for category-like queries',
      (tester) async {
    final service = await _show(tester, dashboard: true);
    await tester.enterText(find.byType(TextField), 'feed');
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.requests, ['feed']);
    service.pending.last.complete([]);
    await tester.pumpAndSettle();
    expect(_suggestion(1), findsOneWidget);
    expect(_suggestion(2), findsNothing);
    final field = tester.getRect(find.byType(TextField));
    final dropdown = tester.getRect(_dropdown);
    expect(dropdown.top, field.bottom + 6);
    expect(dropdown.width, field.width);
    final scrollable = tester.state<ScrollableState>(find
        .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable))
        .first);
    scrollable.position.jumpTo(250);
    await tester.pumpAndSettle();
    expect(tester.getRect(_dropdown).top,
        tester.getRect(find.byType(TextField)).bottom + 6);
    expect(tester.takeException(), isNull);
  });

  for (final dashboard in [false, true]) {
    testWidgets(
        '${dashboard ? 'dashboard' : 'store'} prioritizes product names before categories and descriptions',
        (tester) async {
      final service = await _show(tester, dashboard: dashboard, catalog: [
        ..._catalog,
        {'id': 5, 'product_name': 'Feed Scoop', 'category': 2},
        {'id': 6, 'item_name': 'Starter Crumble', 'category': 1},
        {
          'id': 7,
          'name': 'Storage Bin',
          'category': 2,
          'item_description': 'Feed holder'
        },
      ]);
      await tester.enterText(find.byType(TextField), '  FEED  ');
      if (dashboard) {
        await tester.pump(const Duration(milliseconds: 500));
        service.pending.last.complete([
          {'id': 6, 'item_name': 'Starter Crumble', 'category': 1},
          {'id': 8, 'name': 'Online Feed Scoop', 'category': 2},
          _catalog.first,
        ]);
      }
      await tester.pumpAndSettle();
      expect(_suggestion(1), findsOneWidget);
      expect(_suggestion(5), findsOneWidget);
      expect(_suggestion(6), dashboard ? findsOneWidget : findsNothing);
      expect(_suggestion(7), findsNothing);
      if (dashboard) {
        expect(_suggestion(8), findsOneWidget);
        final suggestions = tester
            .widget<SearchSuggestions>(find.byType(SearchSuggestions).first)
            .suggestions;
        expect(suggestions.map((hit) => hit.id), ['8', '1', '5', '6']);
      }
      await tester.testTextInput.receiveAction(TextInputAction.search);
      if (dashboard) {
        await tester.pump();
        service.pending.last.complete([]);
      }
      await tester.pumpAndSettle();
      expect(find.text(dashboard ? 'Products matching "FEED"' : '2 items'),
          findsOneWidget);
      if (dashboard) {
        final cards = find.byKey(const ValueKey('search-suggestions-dropdown'));
        expect(cards, findsNothing);
      }
      await tester.enterText(find.byType(TextField), 'supplies');
      if (dashboard) {
        await tester.pump(const Duration(milliseconds: 500));
        service.pending.last.complete([]);
      }
      await tester.pumpAndSettle();
      expect(_suggestion(2), findsOneWidget);
      expect(_suggestion(5), findsOneWidget);
      expect(_suggestion(7), findsOneWidget);
      expect(_suggestion(1), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('online product name wins over locally loaded category matches',
      (tester) async {
    final service = await _show(tester, dashboard: true);
    await tester.enterText(find.byType(TextField), 'supplies');
    await tester.pump(const Duration(milliseconds: 500));
    service.pending.last.complete([
      {'id': 8, 'item_name': 'Supplies Bundle', 'category': 1},
      _catalog[1],
    ]);
    await tester.pumpAndSettle();
    expect(_suggestion(8), findsOneWidget);
    expect(_suggestion(2), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('store category scope and Search from Reviews', (tester) async {
    await _show(tester);
    await tester.ensureVisible(find.text('Feeds').first);
    await tester.tap(find.text('Feeds').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bowl');
    await tester.pumpAndSettle();
    expect(_suggestion(2), findsNothing);
    expect(
        find.descendant(
            of: _dropdown, matching: find.text('No matching products')),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reviews').first);
    await tester.tap(find.text('Reviews').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'golden');
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet'), findsNothing);
    expect(find.text('1 items'), findsOneWidget);
  });

  testWidgets('dashboard selection opens details and ignores pending response',
      (tester) async {
    final service = await _show(tester, dashboard: true);
    await tester.enterText(find.byType(TextField), 'golden');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.tap(_suggestion(1));
    service.pending.last.complete([
      {'id': 9, 'item_name': 'Late product'}
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(
        tester
            .widget<ProductDetailScreen>(find.byType(ProductDetailScreen))
            .productId,
        1);
    expect(_dropdown, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard hides category controls and reclaims header space',
      (tester) async {
    final service = await _show(tester, dashboard: true);
    final header = find.byType(SliverPersistentHeader);
    final delegate = tester.widget<SliverPersistentHeader>(header).delegate;
    expect(delegate.maxExtent, 280);
    expect(delegate.minExtent, 68);
    expect(
        tester.renderObject<RenderSliver>(header).geometry!.paintExtent, 280);
    for (final label in ['All', 'Feeds', 'Supplies']) {
      expect(find.descendant(of: header, matching: find.text(label)),
          findsNothing);
      // The controls remain mounted offstage so the feature can be restored.
      expect(
          find.descendant(
              of: header,
              skipOffstage: false,
              matching: find.text(label, skipOffstage: false)),
          findsOneWidget);
    }
    final hiddenRow = find.descendant(
        of: header,
        matching: find.byWidgetPredicate((widget) =>
            widget is Visibility && !widget.visible && widget.maintainState));
    expect(hiddenRow, findsOneWidget);
    final scrollable = tester.state<ScrollableState>(find
        .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable))
        .first);
    scrollable.position.jumpTo(250);
    await tester.pumpAndSettle();
    expect(tester.renderObject<RenderSliver>(header).geometry!.paintExtent, 68);
    expect(find.descendant(of: header, matching: find.text('Feeds')),
        findsNothing);
    await tester.enterText(find.byType(TextField), 'supplies');
    await tester.pump(const Duration(milliseconds: 500));
    service.pending.last.complete([]);
    await tester.pumpAndSettle();
    expect(_suggestion(2), findsOneWidget);
    expect(_suggestion(1), findsNothing);
    expect(tester.getRect(_dropdown).top,
        tester.getRect(find.byType(TextField)).bottom + 6);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'grouped results keep gamefowl feed as a product and submit all groups',
      (tester) async {
    final service = await _show(tester, dashboard: true, grouped: true);
    await tester.enterText(find.byType(TextField), 'kelso');
    await tester.pump(const Duration(milliseconds: 500));
    service.groupedPending.last.complete(_groupedResponse());
    await tester.pumpAndSettle();
    for (final type in ['product', 'shop', 'gamefowl']) {
      expect(
          find.byKey(ValueKey('search-suggestion-$type-42')), findsOneWidget);
    }
    expect(find.descendant(of: _dropdown, matching: find.text('Products')),
        findsOneWidget);
    expect(find.descendant(of: _dropdown, matching: find.text('Shops')),
        findsOneWidget);
    expect(find.descendant(of: _dropdown, matching: find.text('Gamefowl')),
        findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('search-suggestion-gamefowl-102')), 120,
        scrollable: find
            .descendant(of: _dropdown, matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Bundle'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    service.groupedPending.last.complete(_groupedResponse());
    await tester.pumpAndSettle();
    expect(_dropdown, findsNothing);
    expect(find.text('Kelso Gamefowl Feed'), findsOneWidget);
    expect(find.byKey(const ValueKey('search-result-shop-42')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-result-gamefowl-42')),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), 'other');
    await tester.pump(const Duration(milliseconds: 500));
    service.groupedPending.last.complete(const CatalogSearchResponse());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-result-shop-42')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-result-gamefowl-42')),
        findsOneWidget);
    expect(
        find.descendant(of: _dropdown, matching: find.text('No matches found')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final type in ['product', 'shop', 'gamefowl', 'bundle']) {
    testWidgets('grouped $type suggestion opens its own detail route',
        (tester) async {
      final service = await _show(tester, dashboard: true, grouped: true);
      await tester.enterText(find.byType(TextField), 'kelso');
      await tester.pump(const Duration(milliseconds: 500));
      service.groupedPending.last.complete(_groupedResponse());
      await tester.pumpAndSettle();
      final key = type == 'bundle' ? 'gamefowl-102' : '$type-42';
      final suggestion = find.byKey(ValueKey('search-suggestion-$key'));
      await tester.scrollUntilVisible(suggestion, 120,
          scrollable: find
              .descendant(of: _dropdown, matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await tester.tap(suggestion);
      await tester.pumpAndSettle();
      switch (type) {
        case 'product':
          final screen = tester
              .widget<ProductDetailScreen>(find.byType(ProductDetailScreen));
          expect(screen.productId, 42);
          expect(screen.loadFullDetails, isTrue);
        case 'shop':
          expect(tester.widget<ShopScreen>(find.byType(ShopScreen)).shopId, 42);
        default:
          final screen = tester.widget<FarmGamefowlListingDetailScreen>(
              find.byType(FarmGamefowlListingDetailScreen));
          expect(screen.listingId, type == 'bundle' ? 102 : 42);
      }
      expect(_dropdown, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'shop-only and gamefowl-only hits avoid a false no-results message',
      (tester) async {
    final service = await _show(tester, dashboard: true, grouped: true);
    for (final shopOnly in [true, false]) {
      await tester.enterText(find.byType(TextField), 'kelso');
      await tester.pump(const Duration(milliseconds: 500));
      service.groupedPending.last.complete(
          _groupedResponse(items: false, shops: shopOnly, gamefowl: !shopOnly));
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      service.groupedPending.last.complete(
          _groupedResponse(items: false, shops: shopOnly, gamefowl: !shopOnly));
      await tester.pumpAndSettle();
      expect(find.textContaining('No matches found for'), findsNothing);
      expect(find.textContaining('No products found for'), findsNothing);
      expect(
          find.byKey(
              ValueKey('search-result-${shopOnly ? 'shop' : 'gamefowl'}-42')),
          findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('submitted feed product card opens hydrated product details',
      (tester) async {
    final service = await _show(tester, dashboard: true, grouped: true);
    await tester.enterText(find.byType(TextField), 'kelso');
    await tester.pump(const Duration(milliseconds: 500));
    service.groupedPending.last
        .complete(_groupedResponse(shops: false, gamefowl: false));
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    service.groupedPending.last
        .complete(_groupedResponse(shops: false, gamefowl: false));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kelso Gamefowl Feed'));
    await tester.tap(find.text('Kelso Gamefowl Feed'));
    await tester.pumpAndSettle();
    final screen =
        tester.widget<ProductDetailScreen>(find.byType(ProductDetailScreen));
    expect(screen.productId, 42);
    expect(screen.loadFullDetails, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'leaving during submitted search does not leave results loading on return',
      (tester) async {
    final service = await _show(tester, dashboard: true, grouped: true);
    await tester.enterText(find.byType(TextField), 'kelso');
    await tester.pump(const Duration(milliseconds: 500));
    service.groupedPending.last.complete(_groupedResponse());
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    tester.widget<TextField>(find.byType(TextField)).focusNode!.requestFocus();
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('search-suggestion-shop-42')));
    await tester.pump(const Duration(milliseconds: 200));
    service.groupedPending.last.complete(const CatalogSearchResponse());
    await tester.pumpAndSettle();
    expect(find.byType(ShopScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(ShopScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('search-result-shop-42')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'keeps every API match for test, including non-name product and shop matches',
      (tester) async {
    final service = await _show(tester, dashboard: true, grouped: true);
    final response = CatalogSearchResponse.fromJson({
      'success': true,
      'query': 'test',
      'data': {
        'items': [
          {
            'item_id': 15,
            'item_name': 'Test Item 3',
            'image': null,
            'price': 50
          },
          {
            'item_id': 4,
            'item_name': 'Test Item 2',
            'image': null,
            'price': 12
          },
          {
            'item_id': 17,
            'item_name': 'TAb',
            'image': '/storage/product-catalog/tab.png',
            'price': 100
          },
        ],
        'shops': [
          {'shop_id': 1, 'name': 'James Shop1', 'image': null}
        ],
        'gamefowl': [
          {
            'listing_id': 2,
            'farm_id': 1,
            'name': 'Test',
            'image': '/storage/gamefowl-catalog/test.jpg',
            'price': 5000,
            'is_bundle': false
          }
        ],
      },
      'count': {'items': 3, 'shops': 1, 'gamefowl': 1},
    });
    await tester.enterText(find.byType(TextField), 'test');
    await tester.pump(const Duration(milliseconds: 500));
    service.groupedPending.last.complete(response);
    await tester.pumpAndSettle();
    final dropdown =
        tester.widget<SearchSuggestions>(find.byType(SearchSuggestions).first);
    expect(
        dropdown.suggestions
            .where((hit) => hit.type == SearchResultType.product)
            .map((hit) => hit.id),
        ['15', '4', '17']);
    expect(
        dropdown.suggestions
            .where((hit) => hit.type == SearchResultType.shop)
            .map((hit) => hit.id),
        ['1']);
    expect(
        dropdown.suggestions
            .where((hit) => hit.type == SearchResultType.gamefowl)
            .map((hit) => hit.id),
        ['2']);
    final scrollbar = tester.widget<Scrollbar>(
        find.descendant(of: _dropdown, matching: find.byType(Scrollbar)).first);
    expect(scrollbar.thumbVisibility, isTrue);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('search-suggestion-gamefowl-2')), 120,
        scrollable: find
            .descendant(of: _dropdown, matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-suggestion-gamefowl-2')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
