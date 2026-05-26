import 'package:flutter/material.dart';
import '../constants/constants.dart';
import 'stat_card.dart';

class RiderStatisticsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String Function(dynamic) formatPrice;
  final VoidCallback? onEarningsTap;

  const RiderStatisticsGrid({
    super.key,
    required this.stats,
    required this.formatPrice,
    this.onEarningsTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.2,
      children: [
        StatCard(
          title: 'Total Deliveries',
          value: '${stats['totalDeliveries']}',
          icon: Icons.local_shipping_outlined,
          color: AppColors.primaryNavyLight,
        ),
        StatCard(
          title: 'Active',
          value: '${stats['active']}',
          icon: Icons.directions_bike,
          color: AppColors.accentAmber,
        ),
        StatCard(
          title: 'Completed',
          value: '${stats['completed']}',
          icon: Icons.check_circle_outline,
          color: AppColors.primaryNavy,
        ),
        StatCard(
          title: 'Earnings',
          value: formatPrice(stats['earnings']),
          icon: Icons.payments,
          color: AppColors.success,
          onTap: onEarningsTap,
        ),
      ],
    );
  }
}
