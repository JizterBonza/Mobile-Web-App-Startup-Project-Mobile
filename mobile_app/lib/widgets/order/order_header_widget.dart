import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/constants.dart';
import 'order_helpers.dart';

class OrderHeaderWidget extends StatelessWidget {
  final String orderCode;
  final String orderStatus;
  final String orderedAt;

  const OrderHeaderWidget({
    super.key,
    required this.orderCode,
    required this.orderStatus,
    required this.orderedAt,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.copy, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('$label copied to clipboard'),
          ],
        ),
        backgroundColor: AppColors.mediumGreen,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$orderCode',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      OrderHelpers.formatOrderDate(orderedAt),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _copyToClipboard(context, orderCode, 'Order code'),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.copy,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          // SizedBox(height: 16),
          // Container(
          //   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          //   decoration: BoxDecoration(
          //     color: OrderHelpers.getStatusColor(orderStatus).withOpacity(0.1),
          //     borderRadius: BorderRadius.circular(12),
          //     border: Border.all(
          //       color:
          //           OrderHelpers.getStatusColor(orderStatus).withOpacity(0.3),
          //     ),
          //   ),
          //   child: Row(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       Icon(
          //         OrderHelpers.getStatusIcon(orderStatus),
          //         size: 20,
          //         color: OrderHelpers.getStatusColor(orderStatus),
          //       ),
          //       SizedBox(width: 10),
          //       Text(
          //         orderStatus,
          //         style: TextStyle(
          //           fontSize: 16,
          //           fontWeight: FontWeight.w600,
          //           color: OrderHelpers.getStatusColor(orderStatus),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}
