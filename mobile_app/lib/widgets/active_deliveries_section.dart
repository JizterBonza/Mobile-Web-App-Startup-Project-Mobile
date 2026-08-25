import 'package:flutter/material.dart';

class ActiveDeliveriesSection extends StatelessWidget {
  const ActiveDeliveriesSection({
    super.key,
    required this.orders,
    required this.count,
    required this.isLoading,
    this.error,
    this.onRetry,
    this.onContinue,
  });

  final List<Map<String, dynamic>> orders;
  final int count;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final ValueChanged<Map<String, dynamic>>? onContinue;

  static const _orange = Color(0xFFF0A000);
  static const _lightOrange = Color(0xFFFFF4D6);
  static const _borderOrange = Color(0xFFF2B84B);
  static const _mutedText = Color(0xFF737373);

  @override
  Widget build(BuildContext context) {
    final displayCount = count > 0 ? count : orders.length;

    return Column(
      key: const ValueKey('active-delivery-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActiveDeliveryHeader(count: displayCount),
        const SizedBox(height: 12),
        if (isLoading)
          const _ActiveDeliveryLoading()
        else if (error != null)
          _ActiveDeliveryMessage(
            icon: Icons.error_outline,
            message: error!,
            actionLabel: 'Retry',
            onAction: onRetry,
          )
        else if (orders.isEmpty)
          const _ActiveDeliveryMessage(
            icon: Icons.inbox_outlined,
            message: 'No active deliveries',
          )
        else
          _ActiveDeliveryList(orders: orders, onContinue: onContinue),
      ],
    );
  }

  static String? formatRate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value.toString().trim());
    if (amount == null || !amount.isFinite) return null;
    final text = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '₱$text';
  }
}

class _ActiveDeliveryHeader extends StatelessWidget {
  const _ActiveDeliveryHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Flexible(
          child: Text(
            'Active Delivery',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          key: const ValueKey('active-delivery-count'),
          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: const BoxDecoration(
            color: Color(0xFFF05252),
            borderRadius: BorderRadius.all(Radius.circular(9)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveDeliveryList extends StatelessWidget {
  const _ActiveDeliveryList({required this.orders, required this.onContinue});

  final List<Map<String, dynamic>> orders;
  final ValueChanged<Map<String, dynamic>>? onContinue;

  @override
  Widget build(BuildContext context) {
    final hasAnyRate = orders.any(
      (order) => ActiveDeliveriesSection.formatRate(order['rate']) != null,
    );
    final listHeight = hasAnyRate ? 224.0 : 202.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 360
            ? constraints.maxWidth * 0.82
            : constraints.maxWidth * 0.88;

        return SizedBox(
          height: listHeight,
          child: ListView.separated(
            key: const ValueKey('active-delivery-list'),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              return SizedBox(
                width: cardWidth,
                child: _ActiveDeliveryCard(
                  order: order,
                  onContinue:
                      onContinue == null ? null : () => onContinue!(order),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  const _ActiveDeliveryCard({required this.order, this.onContinue});

  final Map<String, dynamic> order;
  final VoidCallback? onContinue;

  int _asInt(dynamic value) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  String _valueOrFallback(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatStatus() {
    final activeOrderShops = order['active_order_shops'];
    if (activeOrderShops is List && activeOrderShops.isNotEmpty) {
      final firstShop = activeOrderShops.first;
      if (firstShop is Map) {
        final description =
            firstShop['order_status_description']?.toString().trim() ?? '';
        if (description.isNotEmpty) return description;
      }
    }

    final label = order['status_label']?.toString().trim() ?? '';
    if (label.isNotEmpty) return label;
    final raw = order['status']?.toString().trim() ?? '';
    if (raw.isEmpty) return 'In Progress';
    return raw
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return 'Date unavailable';
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})',
    ).firstMatch(raw);
    if (match == null) return raw;

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    final hour = int.tryParse(match.group(4)!);
    final minute = int.tryParse(match.group(5)!);
    if (year == null ||
        month == null ||
        month < 1 ||
        month > 12 ||
        day == null ||
        hour == null ||
        minute == null) {
      return raw;
    }

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final suffix = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final displayMinute = minute.toString().padLeft(2, '0');
    return '${months[month - 1]} $day, $year • '
        '$displayHour:$displayMinute$suffix';
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: const Color(0xFF999999)),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF242424),
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderCode = _valueOrFallback(order['order_code'], 'Order');
    final recipient =
        _valueOrFallback(order['recipient_name'], 'Unknown recipient');
    final address =
        _valueOrFallback(order['delivery_address'], 'Address unavailable');
    final pickupCount = _asInt(order['pickup_store_count']);
    final itemCount = _asInt(order['item_count']);
    final pickupLabel = pickupCount == 1 ? 'pickup store' : 'pickup stores';
    final itemLabel = itemCount == 1 ? 'item' : 'items';
    final rate = ActiveDeliveriesSection.formatRate(order['rate']);
    final cardKey = order['order_id'] ?? orderCode;

    return Container(
      key: ValueKey('active-delivery-card-$cardKey'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: ActiveDeliveriesSection._borderOrange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(order['ordered_at']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 8, color: Colors.black),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 105),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: ActiveDeliveriesSection._lightOrange,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ActiveDeliveriesSection._orange),
                  ),
                  child: Text(
                    _formatStatus(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ActiveDeliveriesSection._orange,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _detailRow(Icons.person, recipient),
          const SizedBox(height: 5),
          _detailRow(Icons.location_on, address),
          const SizedBox(height: 5),
          _detailRow(
            Icons.shopping_bag,
            '$pickupCount $pickupLabel • $itemCount $itemLabel',
          ),
          if (rate != null) ...[
            const SizedBox(height: 7),
            Row(
              key: ValueKey('active-delivery-rate-$cardKey'),
              children: [
                const Text(
                  'Rate',
                  style: TextStyle(
                    color: ActiveDeliveriesSection._mutedText,
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Text(
                  rate,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          const Divider(height: 1, color: Color(0xFFEAEAEA)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: ElevatedButton(
              key: ValueKey('active-delivery-continue-$cardKey'),
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: ActiveDeliveriesSection._orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ActiveDeliveriesSection._orange,
                disabledForegroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Continue Delivery',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveDeliveryLoading extends StatelessWidget {
  const _ActiveDeliveryLoading();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 360
            ? constraints.maxWidth * 0.82
            : constraints.maxWidth * 0.88;
        return Container(
          key: const ValueKey('active-delivery-loading'),
          width: width,
          height: 202,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(110, 14),
              const SizedBox(height: 8),
              _line(145, 8),
              const SizedBox(height: 24),
              _line(double.infinity, 10),
              const SizedBox(height: 9),
              _line(double.infinity, 10),
              const SizedBox(height: 9),
              _line(160, 10),
              const Spacer(),
              _line(double.infinity, 30),
            ],
          ),
        );
      },
    );
  }

  Widget _line(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAEA),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

class _ActiveDeliveryMessage extends StatelessWidget {
  const _ActiveDeliveryMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(
        actionLabel == null ? 'active-delivery-empty' : 'active-delivery-error',
      ),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: const Color(0xFF999999)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF737373)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 6),
            TextButton(
              key: const ValueKey('active-delivery-retry'),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
