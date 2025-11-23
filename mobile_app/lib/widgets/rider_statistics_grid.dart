import 'package:flutter/material.dart';
import '../constants/constants.dart';
import 'stat_card.dart';

class RiderStatisticsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String Function(dynamic) formatPrice;

  const RiderStatisticsGrid({
    super.key,
    required this.stats,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        StatCard(
          title: 'Total Deliveries',
          value: '${stats['totalDeliveries']}',
          icon: Icons.local_shipping_outlined,
          color: Colors.blue,
        ),
        StatCard(
          title: 'Active',
          value: '${stats['active']}',
          icon: Icons.directions_bike,
          color: Colors.orange,
        ),
        StatCard(
          title: 'Completed',
          value: '${stats['completed']}',
          icon: Icons.check_circle_outline,
          color: AppColors.mediumGreen,
        ),
        StatCard(
          title: 'Earnings',
          value: formatPrice(stats['earnings']),
          icon: Icons.attach_money,
          color: Colors.green[700]!,
        ),
      ],
    );
  }
}
