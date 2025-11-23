import 'package:flutter/material.dart';
import 'detail_row.dart';

class OrderDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> order;
  final String Function(String) formatOrderDate;
  final String Function(dynamic) formatPrice;

  const OrderDetailsDialog({
    super.key,
    required this.order,
    required this.formatOrderDate,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    final user = order['user'] as Map<String, dynamic>?;
    final customerName = user != null
        ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()
        : 'Unknown Customer';
    final orderItems = order['order_items'] as List? ?? [];

    return AlertDialog(
      title: Text('Order Details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DetailRow(
              label: 'Order Code',
              value: order['order_code']?.toString() ?? 'N/A',
            ),
            DetailRow(label: 'Customer', value: customerName),
            DetailRow(
              label: 'Status',
              value: order['order_status']?.toString() ?? 'Pending',
            ),
            DetailRow(
              label: 'Date',
              value: formatOrderDate(order['ordered_at']?.toString() ?? ''),
            ),
            DetailRow(
              label: 'Address',
              value: order['shipping_address']?.toString() ?? 'N/A',
            ),
            DetailRow(
              label: 'Phone',
              value: user?['mobile_number']?.toString() ?? 'N/A',
            ),
            SizedBox(height: 8),
            Divider(),
            SizedBox(height: 8),
            Text(
              'Items (${orderItems.length}):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...orderItems.take(3).map((item) {
              return Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${item['item_name'] ?? 'Unknown'} x${item['quantity'] ?? 1}',
                  style: TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            if (orderItems.length > 3)
              Text(
                '... and ${orderItems.length - 3} more',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            SizedBox(height: 8),
            Divider(),
            SizedBox(height: 8),
            DetailRow(
              label: 'Subtotal',
              value: formatPrice(order['subtotal']),
            ),
            DetailRow(
              label: 'Shipping Fee',
              value: formatPrice(order['shipping_fee']),
            ),
            DetailRow(
              label: 'Total',
              value: formatPrice(order['total_amount']),
              isBold: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    );
  }
}
