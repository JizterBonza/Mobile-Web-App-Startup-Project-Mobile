import 'package:flutter/material.dart';

import '../../constants/constants.dart';
import '../../services/order_service.dart';
import '../../utils/media_url.dart';

class RiderDeliveryHistoryDetailScreen extends StatefulWidget {
  const RiderDeliveryHistoryDetailScreen({
    super.key,
    required this.orderId,
    this.orderService,
  });

  final int orderId;
  final OrderService? orderService;

  @override
  State<RiderDeliveryHistoryDetailScreen> createState() =>
      _RiderDeliveryHistoryDetailScreenState();
}

class _RiderDeliveryHistoryDetailScreenState
    extends State<RiderDeliveryHistoryDetailScreen> {
  late final OrderService _orderService;
  Map<String, dynamic>? _delivery;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _orderService = widget.orderService ?? OrderService();
    _loadDelivery();
  }

  Future<void> _loadDelivery() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final delivery =
          await _orderService.fetchRiderDeliveryHistoryDetail(widget.orderId);
      if (!mounted) return;
      setState(() {
        _delivery = delivery;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _delivery = null;
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('delivery-history-detail-screen'),
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('delivery-history-detail-back'),
                onPressed: () => Navigator.maybePop(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF929292),
                  padding: const EdgeInsets.fromLTRB(13, 10, 16, 7),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                icon: const Icon(Icons.chevron_left, size: 21),
                label: const Text('Back'),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey('delivery-history-detail-loading'),
          color: AppColors.primaryGreenLight,
        ),
      );
    }

    if (_error != null || _delivery == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 54,
                color: Color(0xFFAAAAAA),
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load delivery details',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_error?.isNotEmpty == true) ...[
                const SizedBox(height: 7),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                key: const ValueKey('delivery-history-detail-retry'),
                onPressed: _loadDelivery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreenLight,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final delivery = _delivery!;
    final customerDelivery = _asMap(delivery['customer_delivery']);
    final pickupStores = _asMaps(delivery['pickup_stores']);
    final timeline = _asMaps(delivery['timeline']);
    final proof = _asMap(delivery['proof_of_delivery']);
    final proofGroups = _asMaps(proof['groups']);

    return RefreshIndicator(
      onRefresh: _loadDelivery,
      color: AppColors.primaryGreenLight,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderHeader(delivery),
            const SizedBox(height: 12),
            _DetailSection(
              key: const ValueKey('delivery-detail-customer'),
              icon: Icons.person,
              title: 'Customer Delivery',
              child: Column(
                children: [
                  _DetailValueRow(
                    label: 'Customer',
                    value: _valueOrFallback(
                      customerDelivery['customer_name'],
                    ),
                  ),
                  const SizedBox(height: 7),
                  _DetailValueRow(
                    label: 'Contact',
                    value: _valueOrFallback(
                      customerDelivery['contact_number'],
                    ),
                  ),
                  const SizedBox(height: 7),
                  _DetailValueRow(
                    label: 'Drop off',
                    value: _valueOrFallback(
                      customerDelivery['drop_off_address'],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DetailSection(
              key: const ValueKey('delivery-detail-pickup-stores'),
              icon: Icons.store,
              title: 'Pickup Stores',
              child: pickupStores.isEmpty
                  ? const _DetailEmptyText('No pickup stores available')
                  : Column(
                      children: [
                        for (var index = 0;
                            index < pickupStores.length;
                            index++) ...[
                          _PickupStoreCard(store: pickupStores[index]),
                          if (index < pickupStores.length - 1)
                            const SizedBox(height: 11),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _DetailSection(
              key: const ValueKey('delivery-detail-timeline'),
              icon: Icons.schedule,
              title: 'Timelines',
              child: timeline.isEmpty
                  ? const _DetailEmptyText('No timeline available')
                  : Column(
                      children: [
                        for (var index = 0;
                            index < timeline.length;
                            index++) ...[
                          _TimelineRow(event: timeline[index]),
                          if (index < timeline.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _DetailSection(
              key: const ValueKey('delivery-detail-proof'),
              icon: Icons.check_circle_outline,
              title: 'Proof of Delivery',
              child: proofGroups.isEmpty
                  ? const _DetailEmptyText('No proof of delivery available')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var index = 0;
                            index < proofGroups.length;
                            index++) ...[
                          _ProofGroup(
                            group: proofGroups[index],
                            showShopName: proofGroups.length > 1,
                          ),
                          if (index < proofGroups.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader(Map<String, dynamic> delivery) {
    final status = _asMap(delivery['status']);
    final statusValue = status['key']?.toString().toLowerCase() ?? '';
    final isFailed = statusValue.contains('fail') ||
        statusValue.contains('cancel') ||
        statusValue.contains('return');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _cleanOrderCode(delivery['order_code']),
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 16,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                formatDeliveryDetailDate(delivery['ordered_at']),
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        _DetailStatusBadge(
          label: status['label']?.toString().trim().isNotEmpty == true
              ? status['label'].toString()
              : (isFailed ? 'Failed' : 'Delivered'),
          isFailed: isFailed,
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF9C9C9C)),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF646464),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          const Divider(height: 1, color: Color(0xFFE8E8E8)),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _DetailValueRow extends StatelessWidget {
  const _DetailValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PickupStoreCard extends StatelessWidget {
  const _PickupStoreCard({required this.store});

  final Map<String, dynamic> store;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        children: [
          _DetailValueRow(
            label: 'Agrivet',
            value: _valueOrFallback(store['name']),
          ),
          const SizedBox(height: 7),
          _DetailValueRow(
            label: 'Address',
            value: _valueOrFallback(store['address']),
          ),
          const SizedBox(height: 7),
          _DetailValueRow(
            label: 'Time',
            value: formatDeliveryDetailDate(
              store['picked_up_at'],
              omitZeroMinutes: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final completed = event['completed'] == true;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: completed
                ? AppColors.primaryGreenLight
                : const Color(0xFFD5D5D5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 11, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _valueOrFallback(event['label']),
                style: const TextStyle(
                  color: Color(0xFF222222),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatDeliveryDetailDate(
                  event['occurred_at'],
                  joiner: ' at ',
                ),
                style: const TextStyle(
                  color: Color(0xFF222222),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProofGroup extends StatelessWidget {
  const _ProofGroup({required this.group, required this.showShopName});

  final Map<String, dynamic> group;
  final bool showShopName;

  @override
  Widget build(BuildContext context) {
    final images = _asMaps(group['images']);
    final remarks = group['remarks']?.toString().trim() ?? '';
    final shopName = group['shop_name']?.toString().trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showShopName && shopName.isNotEmpty) ...[
          Text(
            shopName,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (images.isEmpty)
          const _DetailEmptyText('No delivery images available')
        else
          for (var index = 0; index < images.length; index++)
            _ProofImageRow(image: images[index], index: index),
        const SizedBox(height: 2),
        const Text(
          'Remarks',
          style: TextStyle(
            color: Color(0xFF666666),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          remarks.isEmpty ? 'No remarks provided.' : remarks,
          style: const TextStyle(
            color: Color(0xFF222222),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ProofImageRow extends StatelessWidget {
  const _ProofImageRow({required this.image, required this.index});

  final Map<String, dynamic> image;
  final int index;

  @override
  Widget build(BuildContext context) {
    final displayName = _valueOrFallback(image['display_name']);
    final imageUrl = _proofImageUrl(image);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('delivery-proof-image-$index'),
          onTap: imageUrl == null
              ? null
              : () => _showProofImage(context, imageUrl, displayName),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD55656),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      color: imageUrl == null
                          ? const Color(0xFF222222)
                          : AppColors.primaryGreenLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration:
                          imageUrl == null ? null : TextDecoration.underline,
                    ),
                  ),
                ),
                if (imageUrl != null)
                  const Icon(
                    Icons.open_in_full,
                    size: 15,
                    color: Color(0xFF888888),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showProofImage(
  BuildContext context,
  String imageUrl,
  String displayName,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      key: const ValueKey('delivery-proof-image-preview'),
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const CircularProgressIndicator(
                      color: Colors.white,
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 56,
                        color: Colors.white70,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Unable to display this image.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 16,
              right: 64,
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 4,
              child: IconButton(
                key: const ValueKey('delivery-proof-image-close'),
                tooltip: 'Close image',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailStatusBadge extends StatelessWidget {
  const _DetailStatusBadge({required this.label, required this.isFailed});

  final String label;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 60),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isFailed ? const Color(0xFFFFF0F2) : const Color(0xFFE1F7EA),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isFailed ? const Color(0xFFFF6378) : const Color(0xFF77D4A0),
          width: 0.7,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isFailed ? const Color(0xFFFF334F) : const Color(0xFF149755),
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DetailEmptyText extends StatelessWidget {
  const _DetailEmptyText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        color: Color(0xFF888888),
        fontSize: 12,
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

List<Map<String, dynamic>> _asMaps(dynamic value) {
  return value is List
      ? value
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList()
      : <Map<String, dynamic>>[];
}

String? _proofImageUrl(Map<String, dynamic> image) {
  for (final key in [
    'url',
    'image_url',
    'file_url',
    'full_url',
    'path',
    'file_path',
  ]) {
    final raw = image[key]?.toString().trim();
    if (raw != null && raw.isNotEmpty && raw.toLowerCase() != 'null') {
      return resolveMediaUrl(raw);
    }
  }
  return null;
}

String _valueOrFallback(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? 'Not available' : text;
}

String _cleanOrderCode(dynamic value) {
  final code = value?.toString().trim() ?? '';
  if (code.isEmpty) return 'ORDER';
  return code.startsWith('#') ? code.substring(1) : code;
}

String formatDeliveryDetailDate(
  dynamic value, {
  String joiner = ' • ',
  bool omitZeroMinutes = false,
}) {
  final raw = value?.toString().trim() ?? '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw.isEmpty ? 'Not available' : raw;
  final date = parsed.toLocal();

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
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final meridiem = date.hour < 12 ? 'am' : 'pm';
  final time = omitZeroMinutes && date.minute == 0
      ? '$hour$meridiem'
      : '$hour:${date.minute.toString().padLeft(2, '0')}$meridiem';
  return '${months[date.month - 1]} ${date.day}, ${date.year}$joiner$time';
}
