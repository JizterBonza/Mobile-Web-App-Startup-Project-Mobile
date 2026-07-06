import 'package:flutter/material.dart';
import '../constants/constants.dart';

/// Resolves cart line pricing from snapshot, live item price, and discount fields.
class CartItemPricing {
  CartItemPricing({
    required this.priceSnapshot,
    required this.itemPrice,
    this.discountedPrice,
    this.discountStatus,
    this.discountPercent,
  });

  final double priceSnapshot;
  final double itemPrice;
  final double? discountedPrice;
  final String? discountStatus;
  final double? discountPercent;

  bool get hasActiveDiscount =>
      discountStatus?.toLowerCase() == 'active' &&
      discountedPrice != null &&
      discountedPrice! < itemPrice;

  /// Price used for line totals, subtotals, and checkout `price_at_purchase`.
  double get effectivePrice {
    if (hasActiveDiscount) {
      return discountedPrice!;
    }
    if (priceSnapshot != itemPrice) {
      return itemPrice;
    }
    return itemPrice;
  }

  /// Bold primary price shown to the user.
  double get displayPrimaryPrice {
    if (hasActiveDiscount) {
      return discountedPrice!;
    }
    return itemPrice;
  }

  /// Struck-through secondary price, or null when only one price applies.
  double? get displayStrikethroughPrice {
    if (hasActiveDiscount) {
      return itemPrice;
    }
    if (priceSnapshot != itemPrice) {
      return priceSnapshot;
    }
    return null;
  }

  /// Prefix label for the strikethrough line when snapshot differs from live price.
  String? get strikethroughLabel {
    if (hasActiveDiscount) {
      return null;
    }
    if (priceSnapshot != itemPrice) {
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
      priceSnapshot != itemPrice &&
      priceSnapshot != discountedPrice;

  static double parseDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static CartItemPricing fromCartMap(Map<String, dynamic> item) {
    final priceSnapshot = parseDouble(item['price_snapshot']);
    final itemPrice = parseDouble(item['item_price']);

    double? discountedPrice;
    if (item['discounted_price'] != null) {
      discountedPrice = parseDouble(item['discounted_price']);
    }

    final discountDetails = item['discount_details'];
    if (discountedPrice == null && discountDetails is Map) {
      final nested = discountDetails['discounted_price'];
      if (nested != null) {
        discountedPrice = parseDouble(nested);
      }
    }

    double? discountPercent;
    if (discountDetails is Map && discountDetails['discount_percent'] != null) {
      discountPercent = parseDouble(discountDetails['discount_percent']);
    }

    return CartItemPricing(
      priceSnapshot: priceSnapshot,
      itemPrice: itemPrice,
      discountedPrice: discountedPrice,
      discountStatus: item['discount_status']?.toString(),
      discountPercent: discountPercent,
    );
  }

  static String formatPrice(double price) => '₱${price.toStringAsFixed(2)}';
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
          color: AppColors.primaryGreenDark,
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
            color: AppColors.primaryGreenDark,
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
