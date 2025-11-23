import 'package:flutter/material.dart';

class UpdateStatusDialog extends StatelessWidget {
  final Map<String, dynamic> order;
  final Function(String) onStatusSelected;

  const UpdateStatusDialog({
    super.key,
    required this.order,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    final currentStatus =
        order['order_status']?.toString().toLowerCase() ?? 'pending';
    final orderId = order['order_id']?.toString() ?? order['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      return AlertDialog(
        title: Text('Error'),
        content: Text('Invalid order ID'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text('Update Delivery Status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order: ${order['order_code'] ?? 'N/A'}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text('Current Status: ${order['order_status'] ?? 'Pending'}'),
          SizedBox(height: 16),
          Text('Select new status:'),
          SizedBox(height: 8),
          ...['In Transit', 'Delivered'].map((status) {
            return ListTile(
              title: Text(status),
              leading: Radio<String>(
                value: status.toLowerCase(),
                groupValue: currentStatus,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) {
                    onStatusSelected(value);
                  }
                },
              ),
              onTap: () {
                Navigator.pop(context);
                onStatusSelected(status.toLowerCase());
              },
            );
          }).toList(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ],
    );
  }
}
