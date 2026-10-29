import 'package:flutter/foundation.dart';

import '../utils/media_url.dart';

/// Display data shared by the request form and its local checkout preview.
@immutable
class GamefowlProductSummary {
  const GamefowlProductSummary({
    this.productName,
    this.title = 'Gamefowl',
    this.traits = '',
    this.price,
    this.imageUrl,
  });

  final String? productName;
  final String title;
  final String traits;
  final double? price;
  final String? imageUrl;

  String get formattedPrice =>
      price == null ? '—' : '₱${price!.toStringAsFixed(2)}';

  factory GamefowlProductSummary.fromProduct(Map<String, dynamic>? source) {
    final product = source ?? const <String, dynamic>{};
    final gamefowl =
        product['gamefowl'] is Map ? product['gamefowl'] as Map : const {};
    final name = _firstText([
      product['item_name'],
      product['product_name'],
      product['name'],
      product['title'],
    ]);
    final title = _firstText([
          gamefowl['class'],
          product['gamefowl_type'],
          product['fowl_type'],
          product['breed_type'],
          product['type'],
          product['category_name'],
        ]) ??
        name ??
        'Gamefowl';
    final bloodline = _firstText([
      gamefowl['bloodline'],
      product['bloodline'],
      product['bloodline_name'],
    ]);
    final age = _firstText([
      gamefowl['age_type'],
      gamefowl['age'],
      product['age'],
      product['gamefowl_age'],
      product['fowl_age'],
    ]);
    final sex = _firstText([
      gamefowl['sex'],
      product['gender'],
      product['sex'],
      product['gamefowl_gender'],
    ]);
    final rawPrice = _firstText([
      product['item_price'],
      product['price'],
      product['selling_price'],
      product['product_price'],
      product['amount'],
    ]);
    final price = double.tryParse(
        rawPrice?.replaceAll(',', '').replaceAll('₱', '').trim() ?? '');
    return GamefowlProductSummary(
      productName: name,
      title: title,
      traits: [bloodline, age, sex].whereType<String>().join(' | '),
      price: price != null && price.isFinite ? price : null,
      imageUrl: _readImageUrl(product, gamefowl),
    );
  }

  static String? _firstText(Iterable<dynamic> values) {
    for (var value in values) {
      if (value is Map) value = value['name'];
      if (value is! String && value is! num) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return null;
  }

  static String? _readImageUrl(Map<String, dynamic> product, Map gamefowl) {
    final images = <String>[];
    for (final source in [
      product['item_images'],
      product['images'],
      product['image_urls'],
      gamefowl['images'],
    ]) {
      if (source is! List) continue;
      for (final image in source) {
        final url = image is Map
            ? _firstText([
                image['url'],
                image['image_url'],
                image['path'],
                image['item_image'],
                image['image'],
              ])
            : _firstText([image]);
        if (url != null) images.add(url);
      }
      if (images.isNotEmpty) break;
    }
    final primary = product['primary_image_index'];
    final raw = images.isNotEmpty
        ? images[primary is int && primary >= 0 && primary < images.length
            ? primary
            : 0]
        : _firstText([
            product['image_url'],
            product['image'],
            product['product_image'],
            product['item_image'],
            product['photo'],
            product['thumbnail'],
          ]);
    return resolveMediaUrl(raw);
  }
}

/// A snapshot of a single request; contains no cart IDs or submission behavior.
@immutable
class GamefowlRequestDraft {
  const GamefowlRequestDraft({
    required this.product,
    this.chosenGamefowl = '',
    this.wingbandNo = '',
    this.featherColor = '',
    this.feetColor = '',
    this.mediaName,
  });

  final GamefowlProductSummary product;
  final String chosenGamefowl;
  final String wingbandNo;
  final String featherColor;
  final String feetColor;
  final String? mediaName;
}
