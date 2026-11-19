/// Customer-facing price of a catalog item.
///
/// `item_price` is the vendor price without the category markup, so it is
/// only a last-resort fallback for older payloads.
class ItemDisplayPrice {
  const ItemDisplayPrice({required this.price, this.regular});

  /// Price the customer pays.
  final double? price;

  /// Regular price before any discount.
  final double? regular;

  /// Crossed-out price, shown only when the customer pays less than [regular].
  double? get strikethrough =>
      price != null && regular != null && price! < regular! ? regular : null;

  factory ItemDisplayPrice.fromItem(Map<dynamic, dynamic>? item) {
    if (item == null) return const ItemDisplayPrice(price: null);
    final list = parseAmount(item['list_price']);
    final vendor = parseAmount(item['item_price']);
    return ItemDisplayPrice(
      price: parseAmount(item['effective_price']) ??
          list ??
          vendor ??
          parseAmount(item['price']),
      regular: list ?? vendor,
    );
  }

  static double? parseAmount(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.isFinite ? value.toDouble() : null;
    final parsed = double.tryParse(
        value.toString().replaceAll(',', '').replaceAll('₱', '').trim());
    return parsed != null && parsed.isFinite ? parsed : null;
  }
}
