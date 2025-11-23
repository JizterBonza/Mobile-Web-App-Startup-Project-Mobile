import 'package:flutter/material.dart';
import '../constants/constants.dart';
import 'order_item_card.dart';

class ActiveDeliveriesSection extends StatelessWidget {
  final List<Map<String, dynamic>> deliveries;
  final bool isLoading;
  final String? error;
  final bool useSampleData;
  final VoidCallback? onRetry;
  final VoidCallback? onViewAll;
  final VoidCallback? onLoadSampleData;
  final Function(Map<String, dynamic>) onUpdateStatus;
  final Function(Map<String, dynamic>) onViewDetails;
  final Map<String, dynamic> Function(Map<String, dynamic>)
      convertOrderToCardFormat;

  const ActiveDeliveriesSection({
    super.key,
    required this.deliveries,
    required this.isLoading,
    this.error,
    this.useSampleData = false,
    this.onRetry,
    this.onViewAll,
    this.onLoadSampleData,
    required this.onUpdateStatus,
    required this.onViewDetails,
    required this.convertOrderToCardFormat,
  });

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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            if (error != null)
              IconButton(
                icon:
                    Icon(Icons.refresh, size: 20, color: AppColors.mediumGreen),
                onPressed: onRetry,
                tooltip: 'Retry',
              )
            else if (deliveries.length > 3)
              TextButton(
                onPressed: onViewAll,
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.mediumGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16),
        if (isLoading)
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.mediumGreen,
              ),
            ),
          )
        else if (deliveries.isEmpty && !useSampleData)
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No active deliveries',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (onLoadSampleData != null) ...[
                    SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: onLoadSampleData,
                      icon: Icon(Icons.visibility),
                      label: Text('Load Sample Data'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.mediumGreen),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: deliveries.asMap().entries.map((entry) {
                final index = entry.key;
                final order = entry.value;
                final cardData = convertOrderToCardFormat(order);
                final isLast = index == deliveries.length - 1;

                return OrderItemCard(
                  order: cardData,
                  isLast: isLast,
                  onUpdateStatus: () => onUpdateStatus(order),
                  onViewDetails: () => onViewDetails(order),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
