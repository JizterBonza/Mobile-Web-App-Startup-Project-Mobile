import 'package:flutter/material.dart';

import '../../constants/constants.dart';
import '../../models/gamefowl_request_draft.dart';
import '../../widgets/custom_elevated_button.dart';

class GamefowlCheckoutScreen extends StatelessWidget {
  const GamefowlCheckoutScreen({super.key, required this.request});

  final GamefowlRequestDraft request;

  GamefowlProductSummary get _product => request.product;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back,
              size: 24, color: AppColors.textSecondary),
        ),
        title: const Text('Checkout',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            )),
      ),
      body: Column(children: [
        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _orderRequested(),
            const SizedBox(height: 12),
            _deliveryCard(
              context,
              title: 'Delivery Method',
              icon: Icons.local_shipping_outlined,
              value: 'Standard',
              fieldKey: 'checkout-delivery-method',
            ),
            const SizedBox(height: 12),
            _deliveryCard(
              context,
              title: 'Delivery Address',
              icon: Icons.location_on_outlined,
              value: 'Customer Address',
              fieldKey: 'checkout-delivery-address',
            ),
            const SizedBox(height: 12),
            _orderSummary(),
          ]),
        )),
        SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: CustomElevatedButton(
                text: _product.price == null
                    ? 'Place Order'
                    : 'Place Order • ${_product.formattedPrice}',
                width: double.infinity,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Order placement is not available yet.')),
                ),
              ),
            )),
      ]),
    );
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.borderDefault),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );

  Widget _heading(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary));

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: AppColors.borderDefault),
      );

  Widget _thumbnail({double height = 64}) {
    const placeholder = Center(
        child: Icon(Icons.image_outlined,
            size: 24, color: AppColors.textSecondary));
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 64,
        height: height,
        color: AppColors.borderDefault,
        child: _product.imageUrl == null
            ? placeholder
            : Image.network(
                _product.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }

  Widget _pricedItem({bool thumbnail = false}) => LayoutBuilder(
        builder: (context, constraints) {
          final description =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _heading(_product.title),
            if (_product.traits.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_product.traits,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.brandPrimary)),
            ],
          ]);
          final price = Text(_product.formattedPrice,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary));
          const quantity = Text('x1',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
          if (constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(12) > 18) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (thumbnail)
                    Row(children: [
                      _thumbnail(),
                      const SizedBox(width: 12),
                      Expanded(child: description)
                    ])
                  else
                    description,
                  const SizedBox(height: 8),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        quantity,
                        const SizedBox(width: 12),
                        Flexible(child: price)
                      ]),
                ]);
          }
          return Row(children: [
            if (thumbnail) ...[_thumbnail(), const SizedBox(width: 12)],
            Expanded(child: description),
            const SizedBox(width: 12),
            Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [quantity, const SizedBox(height: 8), price]),
          ]);
        },
      );

  Widget _orderRequested() => _card(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('Order Requested'),
          _divider(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8)),
            child: _pricedItem(thumbnail: true),
          ),
          const SizedBox(height: 12),
          _heading('Gamefowl Details'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderDefault),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _thumbnail(height: 96),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _detail('Chosen Gamefowl', request.chosenGamefowl),
                    const SizedBox(height: 8),
                    const Text('Gamefowl Specific Information',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    _detail('Wingband No.', request.wingbandNo),
                    _detail('Feather Color', request.featherColor),
                    _detail('Feet Color', request.feetColor),
                    if (request.mediaName?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      _detail('Media', request.mediaName!),
                    ],
                  ])),
            ]),
          ),
        ],
      ));

  Widget _detail(String label, String value) => Text(
        '$label: ${value.trim().isEmpty ? '—' : value.trim()}',
        style: const TextStyle(
            fontSize: 12, height: 1.5, color: AppColors.textSecondary),
      );

  Widget _deliveryCard(BuildContext context,
          {required String title,
          required IconData icon,
          required String value,
          required String fieldKey}) =>
      _card(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, size: 24, color: AppColors.brandPrimary),
            const SizedBox(width: 8),
            Expanded(child: _heading(title)),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(fieldKey),
            value: value,
            items: [DropdownMenuItem(value: value, child: Text(value))],
            onChanged: null,
            isExpanded: true,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontSize: 14, color: AppColors.textSecondary),
            icon: const Icon(Icons.keyboard_arrow_down,
                size: 24, color: AppColors.textSecondary),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
            ),
          ),
        ],
      ));

  Widget _orderSummary() => _card(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading('Order Summary'),
          _divider(),
          _pricedItem(),
          _divider(),
          _amountRow('Subtotal', _product.formattedPrice),
          const SizedBox(height: 8),
          _amountRow('Handling Fee', '₱0.00'),
          _divider(),
          _amountRow('Total Amount', _product.formattedPrice, total: true),
        ],
      ));

  Widget _amountRow(String label, String amount, {bool total = false}) => Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: total ? 16 : 14,
                    fontWeight: total ? FontWeight.bold : FontWeight.normal,
                    color:
                        total ? AppColors.textPrimary : AppColors.textSecondary,
                  ))),
          const SizedBox(width: 12),
          Expanded(
              child: Text(amount,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: total ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color:
                        total ? AppColors.brandPrimary : AppColors.textPrimary,
                  ))),
        ],
      );
}
