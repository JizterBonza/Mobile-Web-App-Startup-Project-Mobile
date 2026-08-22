import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/constants.dart';
import '../provider/category_provider.dart';
import '../screens/customer/productDetailScreen.dart';
import '../utils/media_url.dart';

/// Reusable marketplace product card.
///
/// Layout (top to bottom): full-width image, category label, bold name,
/// store name, "(N sold)" count and price. Fields are resolved leniently so
/// the same card works across the dashboard, shop screen and favorites where
/// the underlying maps use slightly different keys.
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final double imageHeight;
  final VoidCallback? onTap;

  /// Optional widget rendered in the top-right corner of the image
  /// (e.g. a favorite toggle button).
  final Widget? imageOverlay;

  const ProductCard({
    super.key,
    required this.product,
    this.imageHeight = 130,
    this.onTap,
    this.imageOverlay,
  });

  /// Resolves a category id stored on an item to its display name using the
  /// loaded categories. Falls back to the raw value when it is already a name
  /// and hides unknown numeric ids.
  String _resolveCategoryName(BuildContext context) {
    final raw = (product['category'] ?? '').toString().trim();
    if (raw.isEmpty) return '';

    final categories = context.watch<CategoryProvider>().categories;
    for (final category in categories) {
      if (category['id']?.toString() == raw) {
        return (category['name'] ?? '').toString();
      }
    }
    for (final category in categories) {
      final name = (category['name'] ?? '').toString();
      if (name.toLowerCase() == raw.toLowerCase()) return name;
    }

    // Unknown numeric id with no match -> hide rather than show a bare number.
    return int.tryParse(raw) != null ? '' : raw;
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '₱0.00';
    if (price is num) return '₱${price.toStringAsFixed(2)}';
    final parsed = double.tryParse(price.toString());
    return parsed != null ? '₱${parsed.toStringAsFixed(2)}' : '₱0.00';
  }

  DateTime? _parseDiscountExpiresAt() {
    final raw = product['discount_expires_at'];
    if (raw == null || raw.toString().trim().isEmpty) return null;
    return DateTime.tryParse(raw.toString());
  }

  bool _hasActiveDiscount(double discountPercent, DateTime? expiresAt) {
    if (discountPercent <= 0) return false;
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveItemImageUrl(product['item_images']);
    final hasImage = imageUrl != null;

    final category = _resolveCategoryName(context);
    final shopName =
        (product['shop_name'] ?? product['vendor'] ?? '').toString().trim();

    final soldRaw = product['sold_count'];
    final soldCount = soldRaw is num
        ? soldRaw.toInt()
        : int.tryParse(soldRaw?.toString() ?? '') ?? 0;

    final discountRaw = product['active_discount_percent'];
    final discountPercent = discountRaw is num
        ? discountRaw.toDouble()
        : double.tryParse(discountRaw?.toString() ?? '0') ?? 0;
    final discountExpiresAt = _parseDiscountExpiresAt();
    final hasDiscount =
        _hasActiveDiscount(discountPercent, discountExpiresAt);
    final showCountdown = hasDiscount &&
        discountExpiresAt != null &&
        discountExpiresAt.isAfter(DateTime.now());

    final name = (product['item_name'] ?? product['name'] ?? 'Unknown Product')
        .toString();
    final originalPrice = product['item_price'] ?? product['price'];
    final effectivePrice = product['effective_price'] ?? originalPrice;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ??
              () {
                final id = product['item_id'] ?? product['id'];
                if (id == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(productId: id),
                  ),
                );
              },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: AppColors.surfaceLight,
                        child: hasImage
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                  child: Icon(
                                    Icons.shopping_bag,
                                    color: AppColors.primaryGreen,
                                    size: 32,
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.shopping_bag,
                                  color: AppColors.primaryGreen,
                                  size: 32,
                                ),
                              ),
                      ),
                    ),
                    if (hasDiscount)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '-${discountPercent.toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (imageOverlay != null)
                      Positioned(top: 8, right: 8, child: imageOverlay!),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category.isNotEmpty) ...[
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (shopName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            shopName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (soldCount > 0)
                            Text(
                              '($soldCount sold)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ] else if (soldCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '($soldCount sold)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            _formatPrice(effectivePrice),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _formatPrice(originalPrice),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                decoration: TextDecoration.lineThrough,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (showCountdown) ...[
                      const SizedBox(height: 6),
                      _DiscountCountdown(expiresAt: discountExpiresAt),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscountCountdown extends StatefulWidget {
  final DateTime expiresAt;

  const _DiscountCountdown({required this.expiresAt});

  @override
  State<_DiscountCountdown> createState() => _DiscountCountdownState();
}

class _DiscountCountdownState extends State<_DiscountCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final remaining = widget.expiresAt.difference(DateTime.now());
    if (!mounted) return;

    if (remaining <= Duration.zero) {
      _timer?.cancel();
      setState(() => _remaining = Duration.zero);
      return;
    }

    setState(() => _remaining = remaining);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining <= Duration.zero) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 12, color: AppColors.error),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Ends in ${_format(_remaining)}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
