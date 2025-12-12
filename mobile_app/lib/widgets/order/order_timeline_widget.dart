import 'package:flutter/material.dart';
import '../../constants/constants.dart';

class OrderTimelineWidget extends StatelessWidget {
  final String currentStatus;

  const OrderTimelineWidget({
    super.key,
    required this.currentStatus,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = ['Pending', 'Processing', 'In Transit', 'Delivered'];
    final currentIndex = statuses.indexWhere(
      (s) =>
          s.toLowerCase() == currentStatus.toLowerCase() ||
          s.toLowerCase().replaceAll(' ', '-') == currentStatus.toLowerCase(),
    );

    // If cancelled, show different timeline
    if (currentStatus.toLowerCase() == 'cancelled' ||
        currentStatus.toLowerCase() == 'canceled') {
      return _buildCancelledTimeline();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          SizedBox(height: 20),
          ...statuses.asMap().entries.map((entry) {
            final index = entry.key;
            final status = entry.value;
            final isCompleted = currentIndex >= index;
            final isCurrent = currentIndex == index;
            final isLast = index == statuses.length - 1;

            return Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.mediumGreen
                            : Colors.grey[200],
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(
                                color: AppColors.mediumGreen,
                                width: 3,
                              )
                            : null,
                      ),
                      child: Icon(
                        isCompleted ? Icons.check : Icons.circle,
                        size: isCompleted ? 18 : 8,
                        color: isCompleted ? Colors.white : Colors.grey[400],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: isCompleted
                                  ? Colors.grey[900]
                                  : Colors.grey[400],
                            ),
                          ),
                          if (isCurrent)
                            Text(
                              'Current status',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.mediumGreen,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isCompleted)
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: AppColors.mediumGreen,
                      ),
                  ],
                ),
                if (!isLast)
                  Container(
                    margin: EdgeInsets.only(left: 15),
                    width: 2,
                    height: 30,
                    color: isCompleted && currentIndex > index
                        ? AppColors.mediumGreen
                        : Colors.grey[200],
                  ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCancelledTimeline() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cancel,
                  color: Colors.red[600],
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Cancelled',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'This order has been cancelled',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
