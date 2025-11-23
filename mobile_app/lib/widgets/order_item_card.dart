import 'package:flutter/material.dart';
import '../constants/constants.dart';
import 'status_badge.dart';

class OrderItemCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isLast;
  final bool showDetails;
  final VoidCallback? onUpdateStatus;
  final VoidCallback? onViewDetails;

  const OrderItemCard({
    super.key,
    required this.order,
    this.isLast = false,
    this.showDetails = false,
    this.onUpdateStatus,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (showDetails) {
      return _buildDetailedCard(context);
    }
    return _buildCompactCard();
  }

  Widget _buildCompactCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.mediumGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.mediumGreen,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order['id'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  order['customer'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${order['items'] ?? 0} items • ${order['date'] ?? ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(status: order['status'] ?? ''),
              SizedBox(height: 4),
              Text(
                '₱${(order['total'] ?? 0.0).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mediumGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['id'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          order['customer'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusBadge(status: order['status'] ?? ''),
            ],
          ),
          SizedBox(height: 12),
          Divider(height: 1),
          SizedBox(height: 12),
          if (order['phone'] != null) ...[
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  order['phone'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
          ],
          if (order['address'] != null) ...[
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order['address'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${order['items'] ?? 0} items • ${order['date'] ?? ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                '₱${(order['total'] ?? 0.0).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mediumGreen,
                ),
              ),
            ],
          ),
          if (onUpdateStatus != null || onViewDetails != null) ...[
            SizedBox(height: 12),
            Row(
              children: [
                if (onUpdateStatus != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onUpdateStatus,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.mediumGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Update Status',
                        style: TextStyle(color: AppColors.mediumGreen),
                      ),
                    ),
                  ),
                if (onUpdateStatus != null && onViewDetails != null)
                  SizedBox(width: 8),
                if (onViewDetails != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onViewDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mediumGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('View Details'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
