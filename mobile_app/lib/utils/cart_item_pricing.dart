import 'package:flutter/material.dart';
import '../constants/constants.dart';
import 'price_format.dart';

/// Resolves cart line pricing from the server's payable unit price, the
/// marked-up list price, and the price snapshot taken when the item was added.
class CartItemPricing {
  CartItemPricing({
    required this.priceSnapshot,
    required this.unitPrice,
    double? originalPrice,
    this.discountStatus,
    this.discountPercent,
  }) : originalPrice = originalPrice ?? unitPrice;

  final double priceSnapshot;

  /// Payable unit price; checkout rejects any other `price_at_purchase`.
  final double unitPrice;

  /// Marked-up list price before any discount.
  final double originalPrice;
  final String? discountStatus;
  final double? discountPercent;

  bool get hasActiveDiscount =>
      discountStatus?.toLowerCase() == 'active' && unitPrice < originalPrice;

  bool get _snapshotDiffers => priceSnapshot > 0 && priceSnapshot != unitPrice;

  /// Price used for line totals, subtotals, and checkout `price_at_purchase`.
  double get effectivePrice => unitPrice;

  /// Bold primary price shown to the user.
  double get displayPrimaryPrice => unitPrice;

  /// Struck-through secondary price, or null when only one price applies.
  double? get displayStrikethroughPrice {
    if (hasActiveDiscount) {
      return originalPrice;
    }
    if (_snapshotDiffers) {
      return priceSnapshot;
    }
    return null;
  }

  /// Prefix label for the strikethrough line when snapshot differs from live price.
  String? get strikethroughLabel {
    if (hasActiveDiscount) {
      return null;
    }
    if (_snapshotDiffers) {
      return 'Price added';
    }
    return null;
  }

  /// Label shown before the primary price when snapshot differs from live price
  /// and discount is not active.
  String? get primaryPriceLabel {
    return null;
  }

  /// Extra muted snapshot note when discount is active but snapshot differs
  /// from both the live and discounted prices.
  bool get showSnapshotNote =>
      hasActiveDiscount &&
      priceSnapshot > 0 &&
      priceSnapshot != originalPrice &&
      priceSnapshot != unitPrice;

  static double parseDouble(dynamic value, [double fallback = 0.0]) {
    return _amount(value) ?? fallback;
  }

  static double? _amount(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  /// Reads a GET cart entry, or a flattened checkout line built from one.
  ///
  /// `discounted_price` is always the payable unit price, whatever
  /// `discount_status` says.
  static CartItemPricing fromCartMap(Map<String, dynamic> cartLine) {
    final rawItem = cartLine['item'];
    final item = rawItem is Map ? rawItem : const {};
    final rawDetails = cartLine['discount_details'];
    final details = rawDetails is Map ? rawDetails : const {};

    final unitPrice = _amount(cartLine['discounted_price']) ??
        _amount(details['discounted_price']) ??
        _amount(item['effective_price']) ??
        _amount(cartLine['effective_price']) ??
        _amount(item['item_price']) ??
        _amount(cartLine['item_price']) ??
        0.0;
    final originalPrice = _amount(details['original_price']) ??
        _amount(item['list_price']) ??
        _amount(cartLine['list_price']) ??
        unitPrice;

    return CartItemPricing(
      priceSnapshot: parseDouble(cartLine['price_snapshot']),
      unitPrice: unitPrice,
      originalPrice: originalPrice,
      discountStatus: cartLine['discount_status']?.toString(),
      discountPercent: _amount(details['discount_percent']),
    );
  }

  static String formatPrice(double price) => formatPeso(price);
}

/// Shared cart/checkout price row with optional strikethrough and snapshot note.
class CartItemPriceDisplay extends StatelessWidget {
  const CartItemPriceDisplay({
    super.key,
    required this.pricing,
    this.primaryFontSize = 15,
    this.strikethroughFontSize = 12,
    this.compact = false,
  });

  final CartItemPricing pricing;
  final double primaryFontSize;
  final double strikethroughFontSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final strikethrough = pricing.displayStrikethroughPrice;

    if (strikethrough == null) {
      return Text(
        CartItemPricing.formatPrice(pricing.displayPrimaryPrice),
        style: TextStyle(
          fontSize: primaryFontSize,
          fontWeight: FontWeight.bold,
          color: AppColors.brandPrimaryDark,
        ),
      );
    }

    final label = pricing.strikethroughLabel;
    final strikethroughText = label != null
        ? '$label ${CartItemPricing.formatPrice(strikethrough)}'
        : CartItemPricing.formatPrice(strikethrough);

    final primaryLabel = pricing.primaryPriceLabel;
    final primaryText = primaryLabel != null
        ? '$primaryLabel: ${CartItemPricing.formatPrice(pricing.displayPrimaryPrice)}'
        : CartItemPricing.formatPrice(pricing.displayPrimaryPrice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strikethroughText,
          style: TextStyle(
            fontSize: strikethroughFontSize,
            color: Colors.grey[500],
            decoration: TextDecoration.lineThrough,
          ),
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(
          primaryText,
          style: TextStyle(
            fontSize: primaryFontSize,
            fontWeight: FontWeight.bold,
            color: AppColors.brandPrimaryDark,
          ),
        ),
        if (pricing.showSnapshotNote) ...[
          SizedBox(height: compact ? 2 : 4),
          Text(
            'Added at ${CartItemPricing.formatPrice(pricing.priceSnapshot)}',
            style: TextStyle(
              fontSize: strikethroughFontSize - 1,
              color: Colors.grey[400],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
