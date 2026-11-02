import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/constants.dart';
import '../../models/addressModel.dart';
import '../../models/farm_checkout.dart';
import '../../models/gamefowl_request_draft.dart';
import '../../provider/address_provider.dart';
import '../../provider/farm_checkout_controller.dart';
import '../../services/farm_checkout_service.dart';
import '../../widgets/custom_elevated_button.dart';
import '../common/editAddressScreen.dart';
import 'paymentWebViewScreen.dart';

class GamefowlCheckoutScreen extends StatefulWidget {
  const GamefowlCheckoutScreen(
      {super.key,
      this.request,
      this.orderId,
      this.service,
      this.paymentOpener});

  final GamefowlRequestDraft? request;
  final int? orderId;
  final FarmCheckoutService? service;
  final Future<void> Function(BuildContext, String, int)? paymentOpener;

  @override
  State<GamefowlCheckoutScreen> createState() => _GamefowlCheckoutScreenState();
}

class _GamefowlCheckoutScreenState extends State<GamefowlCheckoutScreen>
    with WidgetsBindingObserver {
  late final FarmCheckoutController _checkout;
  List<AddressModel> _addresses = [];
  AddressModel? _address;
  bool _loadingAddresses = true;
  bool _browserOpen = false;
  String? _addressError;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkout = FarmCheckoutController(widget.service ?? FarmCheckoutService())
      ..addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initialize();
      if (widget.orderId == null) _loadAddresses();
    });
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _checkout.quote?.expired == true) setState(() {});
    });
  }

  Future<void> _initialize() => _checkout.initialize(
        request: widget.request,
        orderId: widget.orderId,
      );

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_browserOpen &&
        _checkout.order != null) {
      _checkout.refreshOrder();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    _checkout.removeListener(_changed);
    _checkout.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _loadingAddresses = true;
      _addressError = null;
    });
    try {
      final provider = context.read<AddressProvider>();
      await provider.fetchAddresses();
      if (!mounted) return;
      final addresses =
          provider.addresses.where((a) => a.isActive && a.id != null).toList();
      final defaults = addresses.where((a) => a.isDefault);
      setState(() {
        _addresses = addresses;
        _address = defaults.isNotEmpty
            ? defaults.first
            : (addresses.isEmpty ? null : addresses.first);
        _addressError = provider.error;
      });
      await _checkout.selectAddress(_address?.id);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _addressError = 'Unable to load addresses. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  Future<void> _addAddress() async {
    final saved = await Navigator.push<Map<String, dynamic>>(
        context, MaterialPageRoute(builder: (_) => const EditAddressScreen()));
    if (saved != null && mounted) await _loadAddresses();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await _checkout.submit();
    if (!mounted || _checkout.order == null || _checkout.message != null) {
      return;
    }
    // Creation is already persisted; payment can be resumed from Orders.
    await _payDeposit();
  }

  Future<void> _payDeposit() => _pay('deposit');

  Future<void> _payBalance() => _pay('balance');

  Future<void> _pay(String purpose) async {
    if (_browserOpen || _checkout.submitting) return;
    await _checkout.refreshOrder(purpose: purpose);
    if (!mounted || _checkout.message != null) return;
    final url = purpose == 'balance'
        ? await _checkout.startBalance()
        : await _checkout.startDeposit();
    if (!mounted || url == null) return;
    _browserOpen = true;
    try {
      if (widget.paymentOpener != null) {
        await widget.paymentOpener!(context, url, _checkout.order!.id);
      } else {
        await Navigator.push<PaymentWebViewResult>(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentWebViewScreen(
                  checkoutUrl: url, orderId: _checkout.order!.id.toString()),
            ));
      }
    } finally {
      _browserOpen = false;
      if (mounted) await _checkout.refreshOrder();
    }
  }

  Widget _card(String title, List<Widget> children,
          {IconData? icon, Widget? action}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ]),
        child: DefaultTextStyle.merge(
            style: const TextStyle(
                fontSize: 14, height: 1.5, color: AppColors.textSecondary),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: AppColors.brandPrimary),
                      const SizedBox(width: 8)
                    ],
                    Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 18,
                                height: 1.2,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary))),
                    if (action != null) ...[const SizedBox(width: 8), action],
                  ]),
                  const SizedBox(height: 16),
                  ...children,
                ])),
      );

  InputDecoration get _selectorDecoration => InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderDefault)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderDefault)),
      );

  Widget _sectionDivider() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: AppColors.borderDefault));

  Widget _productCard(int itemIndex) {
    final entry = widget.request!.items[itemIndex];
    final product = entry.product;
    final item = _checkout.items[itemIndex];
    final traits = product.bloodline == null
        ? product.traits
        : [product.title, product.age, product.sex]
            .whereType<String>()
            .join(' | ');
    return _card(
        'Order Requested',
        [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (product.imageUrl != null) ...[
              ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    product.imageUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                        width: 64,
                        height: 64,
                        child: Icon(Icons.image_outlined)),
                  )),
              const SizedBox(width: 12),
            ],
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(product.bloodline ?? product.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  if (traits.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(traits,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.brandPrimary)),
                  ],
                  const SizedBox(height: 8),
                  Text(
                      '${item.quantity} x ${item.sellingUnit.isEmpty ? entry.sellingUnit : item.sellingUnit}'),
                  Text(
                      '${item.birdCount} ${item.birdCount == 1 ? 'head' : 'heads'}'),
                ])),
          ]),
          const SizedBox(height: 12),
          Text('Chosen Gamefowl: ${product.productName ?? '-'}'),
        ],
        icon: Icons.shopping_bag_outlined,
        action: TextButton.icon(
          key: ValueKey('edit-request-$itemIndex'),
          onPressed: _checkout.submitting ? null : _editRequest,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit'),
        ));
  }

  void _editRequest() =>
      Navigator.pop(context, Map<String, String>.of(_checkout.errors));

  Widget _fulfillmentCard() => _card(
      'Delivery Method',
      [
        DropdownButtonFormField<String>(
          key: const ValueKey('checkout-delivery-method'),
          value: _checkout.fulfillment,
          decoration: _selectorDecoration,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
            DropdownMenuItem(value: 'pickup', child: Text('Pickup'))
          ],
          onChanged: _checkout.loading || _checkout.submitting
              ? null
              : (value) {
                  if (value != null) _checkout.selectFulfillment(value);
                },
        ),
        if (_checkout.fulfillment == 'pickup') ...[
          const SizedBox(height: 8),
          const Text('Collect your gamefowl at the farm. Shipping is free.'),
        ],
      ],
      icon: Icons.local_shipping_outlined);

  Widget _addressCard() => _card(
      'Delivery Address',
      [
        if (_loadingAddresses)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (_addressError != null) ...[
            Text(_addressError!),
            TextButton(
                onPressed: _loadAddresses,
                child: const Text('Retry addresses')),
          ],
          if (_addresses.isNotEmpty) ...[
            DropdownButtonFormField<AddressModel>(
              key: const ValueKey('checkout-delivery-address'),
              value: _address,
              decoration: _selectorDecoration,
              isExpanded: true,
              items: _addresses
                  .map((address) => DropdownMenuItem(
                      value: address,
                      child: Text(
                          '${address.label}${address.isDefault ? ' (Default)' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: _checkout.submitting
                  ? null
                  : (value) {
                      setState(() => _address = value);
                      _checkout.selectAddress(value?.id);
                    },
            ),
            if (_address != null) ...[
              const SizedBox(height: 12),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.brandPrimary.withOpacity(0.2))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_address!.recipientName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        if (_address!.phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(_address!.phone)
                        ],
                        const SizedBox(height: 8),
                        Text(_address!.fullAddress),
                      ])),
            ],
          ],
          if (_addresses.isEmpty)
            const Text('No delivery address yet. Tap + to add one.'),
        ],
      ],
      icon: Icons.location_on_outlined,
      action: IconButton(
        tooltip: 'Add Address',
        onPressed: _checkout.submitting ? null : _addAddress,
        icon: const Icon(Icons.add, color: AppColors.brandPrimary),
      ));

  Widget _birdCard(int itemIndex, int index) {
    final bird = _checkout.birds[itemIndex][index];
    final prefix = 'items.$itemIndex.birds.$index';
    return _card('Bird ${index + 1}: Specific Details', [
      Text('Wingband No.: ${bird.wingband.isEmpty ? '-' : bird.wingband}'),
      const SizedBox(height: 8),
      Text('Feather Color: ${bird.feather.isEmpty ? '-' : bird.feather}'),
      const SizedBox(height: 8),
      Text('Feet Color: ${bird.feet.isEmpty ? '-' : bird.feet}'),
      ..._checkout.errors.entries
          .where((entry) =>
              entry.key == prefix || entry.key.startsWith('$prefix.'))
          .map((entry) =>
              Text(entry.value, style: const TextStyle(color: Colors.red))),
    ]);
  }

  Widget _amount(String label, dynamic amount, {bool emphasis = false}) =>
      _summaryRow(label, farmMoney(amount), emphasis: emphasis);

  Widget _summaryRow(String label, String value, {bool emphasis = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(builder: (context, constraints) {
          final labelStyle = TextStyle(
              fontSize: emphasis ? 16 : 14,
              fontWeight: emphasis ? FontWeight.bold : FontWeight.normal,
              color:
                  emphasis ? AppColors.textPrimary : AppColors.textSecondary);
          final valueStyle = TextStyle(
              fontSize: emphasis ? 20 : 14,
              height: 1.4,
              fontWeight: emphasis ? FontWeight.bold : FontWeight.w600,
              color: emphasis ? AppColors.brandPrimary : AppColors.textPrimary);
          final painter = TextPainter(
            text: TextSpan(
                text: value,
                style: DefaultTextStyle.of(context).style.merge(valueStyle)),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final needsFullWidth =
              painter.width > (constraints.maxWidth - 12) * 0.6;
          painter.dispose();
          Widget amount() => Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: valueStyle,
                    maxLines: 1,
                    softWrap: false),
              ));
          if (needsFullWidth ||
              MediaQuery.textScalerOf(context).scale(14) > 21 ||
              constraints.maxWidth < 220) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(label, style: labelStyle),
                  const SizedBox(height: 8),
                  amount(),
                ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 4, child: Text(label, style: labelStyle)),
            const SizedBox(width: 12),
            Expanded(flex: 6, child: amount()),
          ]);
        }),
      );

  Widget _quoteCard() {
    final quote = _checkout.quote;
    if (quote == null) {
      return _card('Order Summary', [
        Text(_checkout.fulfillment == 'delivery' && _checkout.addressId == null
            ? 'Select a shipping address to calculate your quote.'
            : 'A server quote is required.'),
        if (_checkout.canQuote && !_checkout.loading)
          TextButton(
              onPressed: _checkout.refreshQuote,
              child: const Text('Refresh quote')),
      ]);
    }
    final data = quote.data;
    return _card(
        'Order Summary',
        [
          Text('${data['bird_count']} birds, ${data['box_count']} boxes'),
          _amount('Chicken subtotal', data['chicken_subtotal']),
          if (_checkout.fulfillment == 'pickup')
            _amount('Shipping', data['final_shipping_fee'])
          else ...[
            _summaryRow('Estimated shipping:',
                '${farmMoney(data['shipping_estimate_min'])} - ${farmMoney(data['shipping_estimate_max'])}'),
          ],
          _sectionDivider(),
          _summaryRow('Estimated total:',
              '${farmMoney(data['estimated_total_min'])} - ${farmMoney(data['estimated_total_max'])}'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.brandPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.brandPrimary.withOpacity(0.15))),
            child:
                _amount('Deposit due now', data['deposit_due'], emphasis: true),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    _checkout.fulfillment == 'delivery'
                        ? 'The deposit covers the gamefowl only. Estimated shipping is not collected now. Final delivery charges will be confirmed by the farm.'
                        : 'The deposit covers the gamefowl only. Pickup shipping is free.',
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary))),
          ]),
          if (data['earliest_release_date'] != null) ...[
            const SizedBox(height: 12),
            Text('Earliest release: ${data['earliest_release_date']}'),
          ],
          if (_checkout.fulfillment == 'pickup' &&
              data['pickup_location'] != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Pickup location: ${_pickupLocation(data['pickup_location'])}')),
          if (quote.expired) ...[
            const Text(
                'This quote expired. Refresh and review the current amounts.'),
            TextButton(
                onPressed: _checkout.refreshQuote,
                child: const Text('Refresh quote')),
          ],
        ],
        icon: Icons.receipt_outlined);
  }

  String _pickupLocation(dynamic value) {
    if (value is! Map) return value.toString();
    return [
      value['farm_name'] ?? value['name'],
      value['full_address'] ?? value['address'],
      value['barangay'],
      value['city'] ?? value['city_municipality'],
      value['province']
    ].where((v) => v != null && v.toString().trim().isNotEmpty).join(', ');
  }

  Widget _orderCard() {
    final order = _checkout.order!;
    return _card('Gamefowl order ${order.code}', [
      Text(
          order.data['payment_status'] == 'paid'
              ? 'Paid'
              : order.depositPaid
                  ? 'Deposit confirmed'
                  : order.closed
                      ? 'Order closed'
                      : 'Deposit payment pending',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      _amount('Deposit', order.data['deposit_due']),
      _amount('Confirmed payments', order.data['amount_paid']),
      if (order.data['final_shipping_fee'] != null)
        _amount('Final shipping fee', order.data['final_shipping_fee']),
      if (order.data['final_total'] != null)
        _amount('Total', order.data['final_total'], emphasis: true),
      if (order.data['remaining_balance'] != null)
        _amount('Remaining balance', order.data['remaining_balance']),
      if (order.data['final_total'] == null)
        const Text('Final shipping and balance may be confirmed later.'),
      if (_checkout.paymentUncertain)
        const Text(
            'Payment session is being verified. Keep this order; do not place another one.'),
      if (_checkout.paymentState == 'creation_failed')
        const Text(
            'The payment provider rejected session creation. You can try payment again.'),
      TextButton(
          onPressed: _checkout.submitting ? null : _checkout.refreshOrder,
          child: const Text('Refresh Status')),
      if (order.balancePayable && !order.closed && !_checkout.paymentUncertain)
        CustomElevatedButton(
            text: 'Pay remaining balance',
            isLoading: _checkout.submitting,
            onPressed: _payBalance)
      else if (!order.depositPaid &&
          !order.closed &&
          !_checkout.paymentUncertain)
        CustomElevatedButton(
            text: 'Pay Deposit',
            isLoading: _checkout.submitting,
            onPressed: _payDeposit),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final recoveryOnly = _checkout.hasAttempt && _checkout.order == null;
    final editing = !_checkout.locked && _checkout.items.isNotEmpty;
    final header = <Widget>[
      if (_checkout.loading) const LinearProgressIndicator(),
      if (_checkout.message != null)
        _card('Checkout notice', [
          Text(_checkout.message!),
          if (_checkout.items.isEmpty &&
              !_checkout.locked &&
              !_checkout.loading)
            TextButton(onPressed: _initialize, child: const Text('Retry')),
        ]),
      if (recoveryOnly)
        _card('Recover order submission', [
          const Text(
              'An earlier submission has not been resolved. Retry its original details safely.'),
          CustomElevatedButton(
              text: 'Retry original submission',
              isLoading: _checkout.submitting,
              onPressed: _submit),
        ]),
      if (_checkout.order != null) _orderCard(),
      if (editing) ...[
        for (var i = 0; i < _checkout.items.length; i++) ...[
          _productCard(i),
          for (var bird = 0; bird < _checkout.birds[i].length; bird++)
            _birdCard(i, bird),
        ],
      ],
    ];
    final trailing = <Widget>[
      if (editing) ...[
        if (_checkout.fulfillment == 'delivery') _addressCard(),
        _fulfillmentCard(),
        _quoteCard(),
        if (_checkout.errors.isNotEmpty)
          ..._checkout.errors.entries
              .where((e) =>
                  !RegExp(r'^items\.\d+\.birds\.\d+(\.|$)').hasMatch(e.key))
              .map((e) =>
                  Text(e.value, style: const TextStyle(color: Colors.red))),
      ],
    ];
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Checkout',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: header.length + trailing.length,
        itemBuilder: (_, index) => index < header.length
            ? header[index]
            : trailing[index - header.length],
      ),
      bottomNavigationBar: editing
          ? Material(
              color: Colors.white,
              elevation: 4,
              child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomElevatedButton(
                      text: _checkout.quote == null
                          ? 'Place Order'
                          : 'Place Order - Deposit ${farmMoney(_checkout.quote!.data['deposit_due'])}',
                      isLoading: _checkout.submitting,
                      onPressed: _checkout.canSubmit ? _submit : null,
                    ),
                  )))
          : null,
    );
  }
}
