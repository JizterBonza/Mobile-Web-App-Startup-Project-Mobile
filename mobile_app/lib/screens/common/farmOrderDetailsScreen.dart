import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/constants.dart';
import '../../models/customer_order_entry.dart';
import '../../models/farm_checkout.dart';
import '../../services/farm_checkout_service.dart';
import '../../widgets/order/farm_order_widgets.dart';
import '../../widgets/order/farm_order_tracking.dart';
import '../../widgets/order/farm_order_overview.dart';
import '../customer/gamefowlCheckoutScreen.dart';

class FarmOrderDetailsScreen extends StatefulWidget {
  const FarmOrderDetailsScreen(
      {super.key,
      required this.orderId,
      this.initialOrder,
      this.service,
      this.onUpdated,
      this.paymentOpener});
  final int orderId;
  final FarmOrder? initialOrder;
  final FarmCheckoutService? service;
  final ValueChanged<FarmOrder>? onUpdated;
  final Future<void> Function(int orderId)? paymentOpener;
  @override
  State<FarmOrderDetailsScreen> createState() => _FarmOrderDetailsScreenState();
}

class _FarmOrderDetailsScreenState extends State<FarmOrderDetailsScreen>
    with WidgetsBindingObserver {
  late final FarmCheckoutService _service;
  FarmOrder? _order;
  bool _loading = true;
  bool _paying = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = widget.service ?? FarmCheckoutService();
    _order = widget.initialOrder;
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_paying) _load(reconcile: true);
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load({bool reconcile = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (reconcile) await _service.reconcile(widget.orderId);
      final order = await _service.order(widget.orderId);
      await _service.customerId();
      if (!mounted || generation != _generation) return;
      setState(() => _order = order);
      widget.onUpdated?.call(order);
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.toString();
          if (e is FarmApiException && e.statusCode == 401) _order = null;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _continuePayment() async {
    if (_paying || _loading || _order == null || !_order!.canPay) return;
    setState(() => _paying = true);
    try {
      if (widget.paymentOpener != null) {
        await widget.paymentOpener!(widget.orderId);
      } else {
        await Navigator.push<void>(
            context,
            MaterialPageRoute(
                builder: (_) => GamefowlCheckoutScreen(
                    orderId: widget.orderId, service: _service)));
      }
      if (mounted) await _load(reconcile: true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Widget _section(String title, List<Widget> children, {IconData? icon}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(icon == null ? 12 : 16),
            border: icon == null
                ? null
                : Border.all(color: AppColors.borderDefault)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: AppColors.brandPrimary),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
                child: Padding(
              padding: EdgeInsets.only(top: icon == null ? 0 : 6),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      height: 1.3,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700)),
            )),
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  Widget _inset(List<Widget> children) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDefault)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _infoRow(IconData? icon, String label, String value,
          {bool prominent = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) ...[
            Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 18, color: AppColors.brandPrimary)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: TextStyle(
                          fontSize: prominent ? 16 : 13,
                          height: 1.5,
                          fontWeight:
                              prominent ? FontWeight.w600 : FontWeight.w500,
                          color: AppColors.textPrimary)),
                ]),
          ),
        ]),
      );

  String _address(dynamic value) {
    if (value is! Map) return farmText(value);
    final full = [
      value['full_address'],
      value['address'],
      value['address_line1']
    ].map(farmText).firstWhere((text) => text.isNotEmpty, orElse: () => '');
    final locality = [
      value['barangay'],
      value['city'] ?? value['city_municipality'],
      value['province'],
      value['postal_code']
    ].map(farmText).where((text) => text.isNotEmpty).join(', ');
    return [
      farmText(value['farm_name']),
      farmText(value['recipient_name']),
      full.isEmpty ? locality : full,
      farmText(value['contact_number'] ?? value['phone'])
    ].where((v) => v.isNotEmpty).join('\n');
  }

  List<Widget> _content(FarmOrder order) {
    final view = FarmOrderView(order);
    final data = order.data;
    final address =
        _address(data['shipping_address'] ?? data['shipping_address_snapshot']);
    final pickup = _address(data['pickup_location']);
    return [
      FarmOrderOverview(order: order),
      _section(
          'Gamefowl items', [FarmOrderItems(order: order, showBirds: true)]),
      if (view.fulfillment.isNotEmpty ||
          address.isNotEmpty ||
          pickup.isNotEmpty)
        _section(
            'Fullfilment Method',
            [
              if (view.fulfillment.isNotEmpty)
                Text(
                  view.fulfillment == 'pickup'
                      ? 'Pickup'
                      : view.fulfillment == 'delivery'
                          ? 'Delivery'
                          : view.fulfillment,
                  style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              if (address.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _inset([
                      _infoRow(Icons.location_on_outlined, 'Delivery address',
                          address)
                    ])),
              if (pickup.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _inset([
                      _infoRow(
                          Icons.storefront_outlined, 'Pickup location', pickup)
                    ])),
            ],
            icon: Icons.local_shipping_outlined),
      _section(
          'Order Summary',
          [
            if (data['chicken_subtotal'] != null)
              FarmOrderAmountRow(
                  'Chicken subtotal', farmMoney(data['chicken_subtotal'])),
            if (data['final_shipping_fee'] != null)
              FarmOrderAmountRow(
                  'Final shipping fee', farmMoney(data['final_shipping_fee']))
            else if (data['shipping_estimate_min'] != null &&
                data['shipping_estimate_max'] != null)
              FarmOrderAmountRow('Estimated shipping',
                  '${farmMoney(data['shipping_estimate_min'])} - ${farmMoney(data['shipping_estimate_max'])}')
            else
              const FarmOrderAmountRow('Shipping fee', 'Not confirmed'),
            const Divider(height: 24),
            FarmOrderAmountRow(view.totalLabel, view.total, emphasis: true),
            const Divider(height: 24),
            if (data['deposit_due'] != null)
              FarmOrderAmountRow('Deposit', farmMoney(data['deposit_due'])),
            if (data['amount_paid'] != null)
              FarmOrderAmountRow(
                  'Confirmed payments', farmMoney(data['amount_paid'])),
            const SizedBox(height: 8),
            _inset([
              FarmOrderAmountRow(
                  'Remaining balance', farmMoney(data['remaining_balance']),
                  emphasis: true)
            ]),
          ],
          icon: Icons.receipt_long_outlined),
      if ([
        'earliest_release_date',
        'pickup_date',
        'balance_opens_at',
        'balance_due_at'
      ].any((key) => farmText(data[key]).isNotEmpty))
        _section(
            'Schedule',
            [
              if (['earliest_release_date', 'pickup_date']
                  .any((key) => farmText(data[key]).isNotEmpty))
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (farmText(data['earliest_release_date']).isNotEmpty)
                        Expanded(
                            child: _infoRow(
                                Icons.calendar_today_outlined,
                                'Earliest release',
                                farmDate(data['earliest_release_date']))),
                      if (farmText(data['earliest_release_date']).isNotEmpty &&
                          farmText(data['pickup_date']).isNotEmpty)
                        const SizedBox(width: 12),
                      if (farmText(data['pickup_date']).isNotEmpty)
                        Expanded(
                            child: _infoRow(Icons.event_outlined, 'Pickup date',
                                farmDate(data['pickup_date']))),
                    ],
                  ),
                ),
              if (['balance_opens_at', 'balance_due_at']
                  .any((key) => farmText(data[key]).isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _inset([
                    const Text('Balance payment window',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandPrimary)),
                    const SizedBox(height: 6),
                    for (final entry in const {
                      'balance_opens_at': 'Balance opens',
                      'balance_due_at': 'Balance due'
                    }.entries)
                      if (farmText(data[entry.key]).isNotEmpty)
                        _infoRow(Icons.access_time_rounded, entry.value,
                            farmDate(data[entry.key])),
                  ]),
                ),
            ],
            icon: Icons.calendar_month_outlined),
      if (data['held_at'] != null || farmText(data['hold_reason']).isNotEmpty)
        _section('Order hold', [
          if (data['held_at'] != null) Text(farmDate(data['held_at'])),
          if (farmText(data['hold_reason']).isNotEmpty)
            Text(farmText(data['hold_reason'])),
        ]),
      _section('Tracking', [FarmOrderTracking(order: order)]),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: AppBar(
            title: const Text('Farm order details'),
            titleTextStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textPrimary,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            elevation: 0,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.white,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            )),
        body: RefreshIndicator(
            onRefresh: () => _load(reconcile: true),
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  _section('Unable to refresh order', [
                    Text(_error!),
                    TextButton(
                        onPressed: _loading ? null : _load,
                        child: const Text('Retry'))
                  ]),
                if (_order != null) ..._content(_order!),
              ],
            )),
        bottomNavigationBar: _order?.canPay == true
            ? SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: _loading || _paying ? null : _continuePayment,
                      child: Text(_order!.paymentActionLabel),
                    )))
            : null,
      );
}
