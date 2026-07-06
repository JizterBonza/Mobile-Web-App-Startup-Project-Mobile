import 'package:flutter/material.dart';
import '../constants/constants.dart';
import 'order_item_card.dart';
import 'skeletons/app_skeletons.dart';

class ActiveDeliveriesSection extends StatelessWidget {
  final List<Map<String, dynamic>> deliveries;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onViewAll;
  final Function(Map<String, dynamic>) onUpdateStatus;
  final Function(Map<String, dynamic>) onViewDetails;
  final Map<String, dynamic> Function(Map<String, dynamic>)
      convertOrderToCardFormat;

  const ActiveDeliveriesSection({
    super.key,
    required this.deliveries,
    required this.isLoading,
    this.error,
    this.onRetry,
    this.onViewAll,
    required this.onUpdateStatus,
    required this.onViewDetails,
    required this.convertOrderToCardFormat,
  });

  Color _getStatusAccentColor(String status) {
    return OrderStatusColors.getColor(status);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Deliveries',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[900],
              ),
            ),
            Row(
              children: [
                if (error != null)
                  GestureDetector(
                    onTap: onRetry,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.refresh,
                          size: 18, color: AppColors.primaryGreen),
                    ),
                  ),
                GestureDetector(
                  onTap: onViewAll,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 12),
        if (isLoading)
          const OrderListSkeleton(count: 3, padding: EdgeInsets.zero)
        else if (deliveries.isEmpty)
          Container(
            padding: EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 40,
                    color: Colors.grey[300],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No active deliveries',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: deliveries.asMap().entries.map((entry) {
              final index = entry.key;
              final order = entry.value;
              final cardData = convertOrderToCardFormat(order);
              final isLast = index == deliveries.length - 1;
              final statusColor =
                  _getStatusAccentColor(cardData['status'] ?? '');

              return Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(14),
                            bottomLeft: Radius.circular(14),
                          ),
                        ),
                      ),
                      Expanded(
                        child: OrderItemCard(
                          order: cardData,
                          isLast: true,
                          onUpdateStatus: () => onUpdateStatus(order),
                          onViewDetails: () => onViewDetails(order),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
