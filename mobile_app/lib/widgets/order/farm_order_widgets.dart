import 'package:flutter/material.dart';

import '../../constants/constants.dart';
import '../../models/customer_order_entry.dart';
import '../../models/farm_checkout.dart';
import '../../utils/manila_time.dart';
import '../../utils/media_url.dart';

String farmDate(dynamic value) {
  final text = farmText(value);
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return text;
  final date = ManilaTime.tryParseToManila(value);
  if (date == null) return text;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}

class FarmOrderAmountRow extends StatelessWidget {
  const FarmOrderAmountRow(this.label, this.value,
      {super.key, this.emphasis = false});
  final String label;
  final String value;
  final bool emphasis;
  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        fontWeight: emphasis ? FontWeight.w600 : FontWeight.normal);
    final valueStyle = TextStyle(
        fontSize: emphasis ? 16 : 13,
        fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
        color: emphasis ? AppColors.brandPrimary : AppColors.textPrimary);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LayoutBuilder(builder: (context, constraints) {
          double textWidth(String text, TextStyle style) {
            final painter = TextPainter(
                text: TextSpan(
                    text: text,
                    style: DefaultTextStyle.of(context).style.merge(style)),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context))
              ..layout();
            final width = painter.width;
            painter.dispose();
            return width;
          }

          final labelText = Text(label, style: labelStyle);
          final valueText =
              Text(value, textAlign: TextAlign.right, style: valueStyle);
          // Keep ordinary amounts on one row; give long amounts their own line
          // at the user's chosen text size rather than shrinking the digits.
          if (textWidth(label, labelStyle) +
                  12 +
                  textWidth(value, valueStyle) <=
              constraints.maxWidth) {
            return Row(children: [
              labelText,
              const SizedBox(width: 12),
              Expanded(child: valueText),
            ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [labelText, const SizedBox(height: 4), valueText]);
        }));
  }
}

class FarmOrderItems extends StatelessWidget {
  const FarmOrderItems(
      {super.key, required this.order, this.showBirds = false, this.limit});
  final FarmOrder order;
  final bool showBirds;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final items = FarmOrderView(order).items;
    if (order.data['items'] is! List) {
      return const Text('Item details are unavailable.');
    }
    if (items.isEmpty) {
      return const Text('No items recorded for this farm order.');
    }
    final visible = limit == null ? items : items.take(limit!).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var index = 0; index < visible.length; index++) ...[
        if (index > 0) Divider(height: showBirds ? 28 : 24),
        _item(visible[index]),
      ],
      if (visible.length < items.length)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
                '+ ${items.length - visible.length} more items. Open order to view all.')),
    ]);
  }

  Widget _item(FarmOrderItemView item) {
    final image = resolveMediaUrl(item.image);
    final quantity =
        item.quantity > 0 ? '${item.quantity} ${item.sellingUnit}'.trim() : '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
                width: showBirds ? 48 : 56,
                height: showBirds ? 48 : 56,
                child: image == null
                    ? const ColoredBox(
                        color: AppColors.surfaceMuted,
                        child: Icon(Icons.image_outlined,
                            color: AppColors.textSecondary))
                    : Image.network(image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_outlined,
                            color: AppColors.textSecondary)))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          if (item.traits.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(item.traits,
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary))),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              if (quantity.isNotEmpty &&
                  !(item.headCount > 0 &&
                      item.sellingUnit.trim().toLowerCase() == 'per head'))
                Text(quantity,
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary)),
              if (item.headCount > 0)
                Text(
                    '${item.headCount} ${item.headCount == 1 ? 'head' : 'heads'}',
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandPrimary)),
            ]),
          ),
        ])),
      ]),
      if (item.data['line_total'] != null)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8)),
          child: FarmOrderAmountRow(
              'Item total', farmMoney(item.data['line_total'])),
        ),
      if (showBirds) ...[
        if (item.data['birds'] is! List)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                  'Individual bird details were not recorded for this order.',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary))),
        for (var i = 0; i < item.birds.length; i++)
          Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  border: Border.all(color: AppColors.borderDefault),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.sell_outlined,
                          size: 14, color: AppColors.brandPrimary),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text('Bird ${i + 1}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.brandPrimary,
                                  fontWeight: FontWeight.w600))),
                    ]),
                    for (final entry in const {
                      'wingband_no': 'Wingband No.',
                      'feather_color': 'Feather Color',
                      'feet_color': 'Feet Color'
                    }.entries)
                      if (farmText(item.birds[i][entry.key]).isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                      text: '${entry.value}: ',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary)),
                                  TextSpan(
                                      text: farmText(item.birds[i][entry.key]),
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500)),
                                ]),
                                style: const TextStyle(
                                    fontSize: 12, height: 1.5))),
                  ])),
      ],
    ]);
  }
}

class FarmOrderCard extends StatefulWidget {
  const FarmOrderCard(
      {super.key,
      required this.entry,
      required this.status,
      required this.onOpen,
      required this.onContinue,
      required this.onLoad});
  final CustomerOrderEntry entry;
  final String status;
  final VoidCallback onOpen;
  final VoidCallback onContinue;
  final void Function(bool retry) onLoad;
  @override
  State<FarmOrderCard> createState() => _FarmOrderCardState();
}

class _FarmOrderCardState extends State<FarmOrderCard> {
  void _hydrate() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.entry.farm?.data['items'] is! List) {
          widget.onLoad(false);
        }
      });
  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(covariant FarmOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _hydrate();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final order = entry.farm;
    final view = order == null ? null : FarmOrderView(order);
    return Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            flex: 3,
                            child: Text('Farm order',
                                style: TextStyle(
                                    fontSize: 18,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text(widget.status,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                    const SizedBox(height: 8),
                    Text('No: ${entry.code}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500)),
                    if (entry.orderedAt != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(farmDate(entry.orderedAt),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary))),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Text(
                              view?.farmName.isNotEmpty == true
                                  ? view!.farmName
                                  : 'Farm',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (entry.detailState ==
                                    FarmOrderDetailState.loading)
                                  const LinearProgressIndicator(),
                                if (order?.data['items'] is List)
                                  FarmOrderItems(order: order!, limit: 3)
                                else ...[
                                  Text(entry.detailError ??
                                      (entry.detailState ==
                                                  FarmOrderDetailState.idle ||
                                              entry.detailState ==
                                                  FarmOrderDetailState.loading
                                          ? 'Loading farm item details...'
                                          : 'Farm item details are unavailable.')),
                                  if (entry.detailState ==
                                          FarmOrderDetailState.failed ||
                                      entry.detailState ==
                                          FarmOrderDetailState.unavailable)
                                    TextButton(
                                        onPressed: () => widget.onLoad(true),
                                        child:
                                            const Text('Retry item details')),
                                ],
                              ],
                            ),
                          ),
                          if (order?.data['items'] is List)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.vertical(
                                    bottom: Radius.circular(12)),
                              ),
                              child: order!.data['chicken_subtotal'] != null
                                  ? FarmOrderAmountRow(
                                      '${view!.items.length} item${view.items.length == 1 ? '' : 's'}',
                                      farmMoney(order.data['chicken_subtotal']))
                                  : Text(
                                      '${view!.items.length} item${view.items.length == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary)),
                            ),
                        ],
                      ),
                    ),
                    if (view != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FarmOrderAmountRow(
                                'Payment status', view.paymentLabel),
                            FarmOrderAmountRow(view.totalLabel, view.total,
                                emphasis: true),
                            if (order!.data['deposit_due'] != null)
                              FarmOrderAmountRow('Deposit',
                                  farmMoney(order.data['deposit_due'])),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (order?.canPay == true)
                            OutlinedButton(
                                onPressed: widget.onContinue,
                                child: Text(order!.balancePayable
                                    ? 'Pay Balance'
                                    : order.paymentActionLabel)),
                          ElevatedButton(
                            onPressed: widget.onOpen,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: const Text('View order',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ]),
                  ])),
        ));
  }
}
