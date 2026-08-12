import 'package:flutter/material.dart';
import '../../constants/constants.dart';
import 'order_helpers.dart';

class PaymentSummaryWidget extends StatelessWidget {
  final Map<String, dynamic> order;
  final String paymentMethod;
  final String paymentStatus;

  const PaymentSummaryWidget({
    super.key,
    required this.order,
    required this.paymentMethod,
    required this.paymentStatus,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = OrderHelpers.orderField(order, 'subtotal');
    final totalAmount = OrderHelpers.orderField(order, 'total_amount');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          if (paymentMethod.isNotEmpty) ...[
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  OrderHelpers.capitalizeFirst(paymentMethod),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          ],
          if (paymentStatus.isNotEmpty) ...[
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Status',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: paymentStatus.toLowerCase() == 'paid'
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.accentAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    OrderHelpers.formatPaymentStatus(paymentStatus),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: paymentStatus.toLowerCase() == 'paid'
                          ? AppColors.success
                          : AppColors.accentAmberDark,
                    ),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 16),
          Divider(color: Colors.grey[200]),
          SizedBox(height: 16),
          _buildPriceRow('Subtotal', subtotal),
          ..._buildFeeBreakdownRows(),
          SizedBox(height: 16),
          Divider(color: Colors.grey[300]),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              Text(
                OrderHelpers.formatPrice(totalAmount),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreenDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeeBreakdownRows() {
    final rows = <Widget>[];
    final isPickup = OrderHelpers.orderFeeFlag(order, 'is_pickup');
    final shippingFee = OrderHelpers.orderFeeAmount(order, 'shipping_fee');
    final deliveryBaseFee =
        OrderHelpers.orderFeeAmount(order, 'delivery_base_fee');
    final deliveryKmFee = OrderHelpers.orderFeeAmount(order, 'delivery_km_fee');
    final deliveryDistanceKm =
        OrderHelpers.orderFeeAmount(order, 'delivery_distance_km');
    final isReducedBase = OrderHelpers.orderFeeFlag(order, 'is_reduced_base');
    final heavySurcharge = OrderHelpers.orderFeeAmount(order, 'heavy_surcharge');
    final heavySurchargeUnits =
        OrderHelpers.orderFeeCount(order, 'heavy_surcharge_units');
    final totalWeightKg = OrderHelpers.orderFeeAmount(order, 'total_weight_kg');
    final multiStoreFee = OrderHelpers.orderFeeAmount(order, 'multi_store_fee');
    final movPenaltyFee = OrderHelpers.orderFeeAmount(order, 'mov_penalty_fee');
    final totalFees = OrderHelpers.orderFeeAmount(order, 'total_fees');
    final storeCount = OrderHelpers.orderFeeCount(order, 'store_count');

    void addFeeRow(String label, double amount, {String? subtitle}) {
      if (amount <= 0) return;
      rows.add(SizedBox(height: 10));
      rows.add(_buildPriceRow(label, amount, subtitle: subtitle));
    }

    if (!isPickup && shippingFee > 0) {
      final deliveryParts = <String>[];
      if (deliveryBaseFee > 0 || deliveryKmFee > 0) {
        deliveryParts.add(
          '₱${deliveryBaseFee.toStringAsFixed(0)} base + '
          '₱${deliveryKmFee.toStringAsFixed(0)}/km',
        );
      }
      if (deliveryDistanceKm > 0) {
        deliveryParts.add('${deliveryDistanceKm.toStringAsFixed(1)} km');
      }
      if (isReducedBase) {
        deliveryParts.add('reduced base');
      }
      addFeeRow(
        'Delivery Fee',
        shippingFee,
        subtitle: deliveryParts.isNotEmpty ? deliveryParts.join(' · ') : null,
      );
    }

    addFeeRow(
      'Heavy Item Surcharge',
      heavySurcharge,
      subtitle: heavySurcharge > 0
          ? '${totalWeightKg.toStringAsFixed(1)} kg · $heavySurchargeUnits units'
          : null,
    );
    addFeeRow(
      'Multi-Store Fee',
      multiStoreFee,
      subtitle: multiStoreFee > 0 && storeCount > 1
          ? '$storeCount stores'
          : null,
    );
    addFeeRow('Minimum Order Fee', movPenaltyFee);

    if (rows.isEmpty && totalFees > 0) {
      rows.add(SizedBox(height: 10));
      rows.add(_buildPriceRow('Fees', totalFees));
    } else if (rows.isEmpty && shippingFee > 0) {
      rows.add(SizedBox(height: 10));
      rows.add(_buildPriceRow('Handling Fee', shippingFee));
    }

    return rows;
  }

  Widget _buildPriceRow(
    String label,
    dynamic price, {
    String? subtitle,
  }) {
    if (subtitle != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Text(
            OrderHelpers.formatPrice(price),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          OrderHelpers.formatPrice(price),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}
