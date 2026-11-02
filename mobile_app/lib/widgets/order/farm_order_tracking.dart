import 'package:flutter/material.dart';

import '../../constants/constants.dart';
import '../../models/customer_order_entry.dart';
import '../../models/farm_checkout.dart';
import '../../utils/manila_time.dart';
import '../../utils/status_utils.dart';
import 'farm_order_widgets.dart';

/// Shows recorded updates only; the current status comes from the order.
class FarmOrderTracking extends StatelessWidget {
  const FarmOrderTracking({super.key, required this.order});

  final FarmOrder order;

  String _label(String value) => value
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  dynamic _timestamp(Map<String, dynamic> event) =>
      event['created_at'] ?? event['timestamp'];

  @override
  Widget build(BuildContext context) {
    final status = normalizeOrderStatus(FarmOrderView(order).status);
    final color = getStatusColor(status);
    final events = farmMaps(order.data['tracking']);
    // Only reorder when every timestamp is known. Undated history retains
    // the server's order so that we do not imply an invented sequence.
    final dated = events.asMap().entries.toList();
    if (events
        .every((event) => ManilaTime.tryParseUtc(_timestamp(event)) != null)) {
      dated.sort((a, b) {
        final comparison = ManilaTime.tryParseUtc(_timestamp(b.value))!
            .compareTo(ManilaTime.tryParseUtc(_timestamp(a.value))!);
        return comparison == 0 ? a.key.compareTo(b.key) : comparison;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                status == 'completed'
                    ? Icons.check_circle_outline_rounded
                    : getStatusIcon(status),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current status',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(status.isEmpty ? 'Status unavailable' : _label(status),
                      style: TextStyle(
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        if (events.isEmpty)
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history_rounded,
                  size: 20, color: AppColors.textSecondary),
              SizedBox(width: 10),
              Expanded(
                child: Text('No tracking updates yet. Pull down to refresh.',
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary)),
              ),
            ],
          )
        else ...[
          const Text('Order updates',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          for (var index = 0; index < dated.length; index++)
            _event(dated[index].value, last: index == dated.length - 1),
        ],
      ],
    );
  }

  Widget _event(Map<String, dynamic> event, {required bool last}) {
    final status = normalizeOrderStatus(farmText(event['status']));
    final color = getStatusColor(status);
    final title = [event['title'], event['event'], event['status']]
        .map(farmText)
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'Order update');
    final description = farmText(event['description'] ?? event['message']);
    final timestamp = farmDate(_timestamp(event));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.borderDefault),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_label(title),
                      style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.textSecondary)),
                  ],
                  if (timestamp.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(timestamp,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
