import 'package:flutter/material.dart';

import '../constants/constants.dart';
import '../models/messageModel.dart';
import 'gamefowl_icon.dart';

/// Farm listing messages use their own card; shop product cards are unchanged.
class FarmGamefowlMessageCard extends StatelessWidget {
  const FarmGamefowlMessageCard({
    super.key,
    required this.product,
    required this.body,
    required this.listingFuture,
    this.onTap,
  });

  final MessageProductSnapshot product;
  final String body;
  final Future<Map<String, dynamic>> listingFuture;
  final VoidCallback? onTap;

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty || text.toLowerCase() == 'null'
        ? null
        : text;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: listingFuture,
      builder: (context, snapshot) {
        final listing = snapshot.data ?? const <String, dynamic>{};
        final gamefowl = _map(listing['gamefowl']);
        final traits = [
          _text(_map(gamefowl['class'])['name']),
          _text(_map(gamefowl['age_type'])['name']),
          _text(gamefowl['sex']),
        ].whereType<String>().join(' | ');
        final name = product.name == 'Product'
            ? (_text(listing['name']) ?? product.name)
            : product.name;
        final rawPrice = listing['price'];
        final price = product.price ??
            (rawPrice is num
                ? rawPrice
                : num.tryParse(rawPrice?.toString() ?? ''));
        final priceText = price == null
            ? (product.priceLabel ?? 'Price unavailable')
            : '₱${price.toStringAsFixed(2)}';
        final image = _text(product.imageUrl) ?? _text(listing['image']);

        return Semantics(
          button: onTap != null,
          label: 'View $name',
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: image == null
                            ? const ColoredBox(
                                color: Color(0xFFF3F4F6),
                                child: Center(
                                  child: GamefowlIcon(
                                      size: 36, color: AppColors.brandPrimary),
                                ),
                              )
                            : Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: Color(0xFFF3F4F6),
                                  child: Center(
                                    child: GamefowlIcon(
                                        size: 36,
                                        color: AppColors.brandPrimary),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (traits.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              traits,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF757575),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            priceText,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(body, style: const TextStyle(fontSize: 15, height: 1.4)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
