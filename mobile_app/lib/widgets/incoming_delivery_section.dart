import 'package:flutter/material.dart';

class IncomingDeliverySection extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final int count;
  final ValueChanged<Map<String, dynamic>>? onAccept;
  final Set<String> acceptingOrderIds;

  const IncomingDeliverySection({
    super.key,
    required this.orders,
    required this.count,
    this.onAccept,
    this.acceptingOrderIds = const {},
  });

  static const _blue = Color(0xFF0A8CFF);
  static const _lightBlue = Color(0xFFE8F4FF);
  static const _borderBlue = Color(0xFF66B5FF);
  static const _mutedText = Color(0xFF737373);

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const SizedBox.shrink();

    final displayCount = count > 0 ? count : orders.length;
    final hasAnyRate = orders.any((order) => formatRate(order['rate']) != null);
    final listHeight = hasAnyRate ? 224.0 : 202.0;

    return Column(
      key: const ValueKey('incoming-delivery-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Flexible(
              child: Text(
                'Incoming Delivery',
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
              key: const ValueKey('incoming-delivery-count'),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: const BoxDecoration(
                color: Color(0xFFF05252),
                borderRadius: BorderRadius.all(Radius.circular(9)),
              ),
              alignment: Alignment.center,
              child: Text(
                '$displayCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 360
                ? constraints.maxWidth * 0.82
                : constraints.maxWidth * 0.88;

            return SizedBox(
              height: listHeight,
              child: ListView.separated(
                key: const ValueKey('incoming-delivery-list'),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final orderKey = order['order_id']?.toString() ??
                      order['order_code']?.toString() ??
                      '';
                  return SizedBox(
                    width: cardWidth,
                    child: IncomingDeliveryCard(
                      order: order,
                      isAccepting: acceptingOrderIds.contains(orderKey),
                      onAccept: () => onAccept?.call(order),
                    ),
                  );
                },
              ),
            );
          },
        ),
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

class IncomingDeliveryCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isAccepting;
  final VoidCallback onAccept;
  final bool fullWidth;

  const IncomingDeliveryCard({
    super.key,
    required this.order,
    required this.isAccepting,
    required this.onAccept,
    this.fullWidth = false,
  });

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _valueOrFallback(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatOrderCode(dynamic value) {
    final raw = _valueOrFallback(value, 'Order');
    final code = raw.startsWith('#') ? raw.substring(1).trim() : raw;
    return code.isEmpty ? 'Order' : code;
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
          child: Icon(
            icon,
            size: fullWidth ? 15 : 14,
            color: const Color(0xFF999999),
          ),
        ),
        SizedBox(width: fullWidth ? 7 : 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF242424),
              fontSize: fullWidth ? 12 : 11,
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
    final orderCode = _formatOrderCode(order['order_code']);
    final recipient =
        _valueOrFallback(order['recipient_name'], 'Unknown recipient');
    final address =
        _valueOrFallback(order['delivery_address'], 'Address unavailable');
    final pickupCount = _asInt(order['pickup_store_count']);
    final itemCount = _asInt(order['item_count']);
    final rate = IncomingDeliverySection.formatRate(order['rate']);
    final pickupLabel = pickupCount == 1 ? 'pickup store' : 'pickup stores';
    final itemLabel = itemCount == 1 ? 'item' : 'items';

    return Container(
      key: ValueKey('incoming-delivery-card-${order['order_id'] ?? orderCode}'),
      padding: fullWidth
          ? const EdgeInsets.all(18)
          : const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(fullWidth ? 8 : 9),
        border: Border.all(
          color: fullWidth
              ? const Color(0xFF8DCAFF)
              : IncomingDeliverySection._borderBlue,
        ),
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
                      style: TextStyle(
                        fontSize: fullWidth ? 16 : 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: fullWidth ? 4 : 2),
                    Text(
                      _formatDate(order['ordered_at']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fullWidth ? 10 : 8,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: fullWidth ? 10 : 9,
                  vertical: fullWidth ? 6 : 5,
                ),
                decoration: BoxDecoration(
                  color: IncomingDeliverySection._lightBlue,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: IncomingDeliverySection._blue),
                ),
                child: const Text(
                  'New',
                  style: TextStyle(
                    color: IncomingDeliverySection._blue,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: fullWidth ? 23 : 14),
          _detailRow(Icons.person, recipient),
          SizedBox(height: fullWidth ? 8 : 5),
          _detailRow(Icons.location_on, address),
          SizedBox(height: fullWidth ? 8 : 5),
          _detailRow(
            Icons.shopping_bag,
            '$pickupCount $pickupLabel • $itemCount $itemLabel',
          ),
          if (rate != null) ...[
            const SizedBox(height: 7),
            Row(
              key: ValueKey(
                'incoming-delivery-rate-${order['order_id'] ?? orderCode}',
              ),
              children: [
                const Text(
                  'Rate',
                  style: TextStyle(
                    color: IncomingDeliverySection._mutedText,
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
          if (fullWidth) const SizedBox(height: 8) else const Spacer(),
          const Divider(height: 1, color: Color(0xFFEAEAEA)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: fullWidth ? 34 : 30,
            child: ElevatedButton(
              key: ValueKey(
                'incoming-delivery-accept-${order['order_id'] ?? orderCode}',
              ),
              onPressed: isAccepting ? null : onAccept,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: EdgeInsets.zero,
                backgroundColor: IncomingDeliverySection._blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    IncomingDeliverySection._blue.withOpacity(0.7),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              child: isAccepting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        key: ValueKey('incoming-delivery-accept-spinner'),
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
