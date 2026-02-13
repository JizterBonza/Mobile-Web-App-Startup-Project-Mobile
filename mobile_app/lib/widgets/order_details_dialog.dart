import 'dart:io';
import 'package:flutter/material.dart';
import 'detail_row.dart';

class OrderDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> order;
  final String Function(String) formatOrderDate;
  final String Function(dynamic) formatPrice;
  final String? deliveryPhotoPath;

  const OrderDetailsDialog({
    super.key,
    required this.order,
    required this.formatOrderDate,
    required this.formatPrice,
    this.deliveryPhotoPath,
  });

  @override
  Widget build(BuildContext context) {
    final user = order['user'] as Map<String, dynamic>?;
    // Use recipient_name from address if available, fallback to user name
    final recipientName = order['recipient_name']?.toString().isNotEmpty == true
        ? order['recipient_name'].toString()
        : (user != null
            ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()
            : 'Unknown Customer');
    // Use recipient_contact from address if available, fallback to user mobile
    final recipientContact =
        order['recipient_contact']?.toString().isNotEmpty == true
            ? order['recipient_contact'].toString()
            : (user?['mobile_number']?.toString() ?? 'N/A');
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
            DetailRow(
                label: 'Recipient',
                value: recipientName.isNotEmpty ? recipientName : 'Unknown'),
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
              label: 'Contact',
              value: recipientContact,
            ),
            // Show delivery photo if available and order is delivered
            if (deliveryPhotoPath != null &&
                deliveryPhotoPath!.isNotEmpty &&
                File(deliveryPhotoPath!).existsSync()) ...[
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 8),
              Text(
                'Delivery Photo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showFullImage(context, deliveryPhotoPath!),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(deliveryPhotoPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, color: Colors.grey[400]),
                                SizedBox(height: 4),
                                Text(
                                  'Image not found',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Tap to view full image',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: 8),
            Divider(),
            SizedBox(height: 8),
            Text(
              'Items (${orderItems.length}):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...orderItems.take(3).map((orderItem) {
              final itemDetails = orderItem['item'] as Map<String, dynamic>?;
              final itemName = itemDetails?['item_name'] ?? 'Unknown';
              final quantity = orderItem['quantity'] ?? 1;
              return Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $itemName x$quantity',
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

  void _showFullImage(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: EdgeInsets.all(20),
                    color: Colors.grey[200],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                        SizedBox(height: 8),
                        Text(
                          'Image not found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
