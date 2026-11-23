import '../utils/media_url.dart';

enum SearchResultType { product, shop, farm, gamefowl }

/// One search summary. Its type and ID together identify its navigation target.
class CatalogSearchHit {
  const CatalogSearchHit({
    required this.type,
    required this.id,
    required this.name,
    required this.data,
    this.imageUrl,
    this.price,
    this.isBundle = false,
  });

  final SearchResultType type;
  final String id;
  final String name;
  final String? imageUrl;
  final num? price;
  final bool isBundle;
  final Map<String, dynamic> data;

  dynamic get farmId => data['farm_id'];

  factory CatalogSearchHit.fromJson(
      Map<String, dynamic> json, SearchResultType type,
      {bool grouped = true}) {
    final idKey = switch (type) {
      SearchResultType.product => 'item_id',
      SearchResultType.shop => 'shop_id',
      SearchResultType.farm => 'farm_id',
      SearchResultType.gamefowl => 'listing_id',
    };
    final rawId = json[idKey] ?? json['id'];
    if ((rawId is! String && rawId is! num) ||
        rawId.toString().trim().isEmpty) {
      throw const FormatException('Search result is missing its ID');
    }
    final name = (json['item_name'] ??
            json['name'] ??
            json['shop_name'] ??
            json['product_name'] ??
            'Result')
        .toString();
    final images = json['item_images'];
    dynamic rawImage = json['image'] ?? json['logo_url'];
    if (rawImage == null && images is List && images.isNotEmpty) {
      final first = images.first;
      rawImage = first is Map
          ? first['url'] ?? first['image_url'] ?? first['path']
          : first;
    }
    final image = resolveShopMediaUrl(rawImage);
    final rawPrice = json['price'] ?? json['item_price'];
    final price = type == SearchResultType.shop || type == SearchResultType.farm
        ? null
        : num.tryParse(rawPrice?.toString() ?? '');
    return CatalogSearchHit(
      type: type,
      id: rawId.toString(),
      name: name,
      imageUrl: image,
      price: price != null && price.isFinite ? price : null,
      isBundle: type == SearchResultType.gamefowl && json['is_bundle'] == true,
      data: {
        ...json,
        'id': rawId,
        idKey: rawId,
        if (type == SearchResultType.product) ...{
          'item_name': name,
          'item_price': rawPrice,
          if (image != null && (grouped || images == null))
            'item_images': [image],
          if (grouped) '_search_result_type': 'product',
        },
        if (type == SearchResultType.shop) ...{
          'shop_name': name,
          'shop_logo': image,
        },
        if (image != null) 'image': image,
      },
    );
  }
}

class CatalogSearchResponse {
  const CatalogSearchResponse({
    this.query = '',
    this.items = const [],
    this.shops = const [],
    this.farms = const [],
    this.gamefowl = const [],
    this.count = const {},
  });

  final String query;
  final List<CatalogSearchHit> items;
  final List<CatalogSearchHit> shops;
  final List<CatalogSearchHit> farms;
  final List<CatalogSearchHit> gamefowl;
  final Map<String, int> count;

  bool get isEmpty =>
      items.isEmpty && shops.isEmpty && farms.isEmpty && gamefowl.isEmpty;
  List<Map<String, dynamic>> get itemData =>
      items.map((hit) => hit.data).toList();

  factory CatalogSearchResponse.fromJson(dynamic json, {String query = ''}) {
    if (json is! Map || json['success'] == false) {
      throw const FormatException('Invalid search response');
    }
    final data = json['data'];
    if (data is! List && data is! Map) {
      throw const FormatException('Invalid search data');
    }
    final grouped = data is Map;
    List<CatalogSearchHit> read(dynamic value, SearchResultType type) {
      if (value == null) return const [];
      if (value is! List) throw const FormatException('Invalid search group');
      return List.unmodifiable(value.map((entry) {
        if (entry is! Map) throw const FormatException('Invalid search result');
        return CatalogSearchHit.fromJson(Map<String, dynamic>.from(entry), type,
            grouped: grouped);
      }));
    }

    final items =
        read(grouped ? data['items'] : data, SearchResultType.product);
    final shops = read(grouped ? data['shops'] : null, SearchResultType.shop);
    final farms = read(grouped ? data['farms'] : null, SearchResultType.farm);
    final gamefowl =
        read(grouped ? data['gamefowl'] : null, SearchResultType.gamefowl);
    final counts = json['count'];
    int countFor(String key, int fallback) {
      final value = counts is Map ? counts[key] : null;
      return value is int && value >= 0 ? value : fallback;
    }

    return CatalogSearchResponse(
      query: json['query']?.toString() ?? query,
      items: items,
      shops: shops,
      farms: farms,
      gamefowl: gamefowl,
      count: Map.unmodifiable({
        'items': countFor('items', items.length),
        'shops': countFor('shops', shops.length),
        'farms': countFor('farms', farms.length),
        'gamefowl': countFor('gamefowl', gamefowl.length),
      }),
    );
  }
}
