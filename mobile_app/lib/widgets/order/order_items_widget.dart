import 'package:flutter/material.dart';
import '../../constants/constants.dart';
import 'order_helpers.dart';

class OrderItemsWidget extends StatelessWidget {
  final List<dynamic> orderItems;

  const OrderItemsWidget({
    super.key,
    required this.orderItems,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.mediumGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${orderItems.length} item${orderItems.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mediumGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          if (orderItems.isEmpty)
            Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No items found',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...orderItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == orderItems.length - 1;
              return _buildOrderItemRow(item, isLast);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(dynamic item, bool isLast) {
    // Handle nested item structure
    final nestedItem = item['item'] as Map<String, dynamic>?;
    final itemName = nestedItem?['item_name']?.toString() ??
        item['item_name']?.toString() ??
        item['name']?.toString() ??
        'Unknown Item';
    final quantity = item['quantity']?.toString() ?? '1';
    final price = item['price'] ??
        item['item_price'] ??
        nestedItem?['item_price'] ??
        item['price_at_purchase'] ??
        0;
    final itemImage = nestedItem?['item_images'] ?? item['item_images'];
    final hasImage = itemImage != null &&
        itemImage is List &&
        (itemImage as List).isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.mediumGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.mediumGreen.withOpacity(0.2),
                  ),
                ),
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          (itemImage as List).first.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.shopping_bag,
                              color: AppColors.mediumGreen,
                              size: 24,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.shopping_bag,
                        color: AppColors.mediumGreen,
                        size: 24,
                      ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Qty: $quantity',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Text(
                OrderHelpers.formatPrice(price),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mediumGreen,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, indent: 90, color: Colors.grey[200]),
      ],
    );
  }
}
