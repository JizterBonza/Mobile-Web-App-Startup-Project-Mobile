import 'package:flutter/material.dart';
import '../../constants/constants.dart';
import 'order_helpers.dart';

class PaymentSummaryWidget extends StatelessWidget {
  final dynamic subtotal;
  final dynamic shippingFee;
  final dynamic totalAmount;
  final String paymentMethod;
  final String paymentStatus;

  const PaymentSummaryWidget({
    super.key,
    required this.subtotal,
    required this.shippingFee,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
  });

  @override
  Widget build(BuildContext context) {
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
              Row(
                children: [
                  Icon(
                    paymentMethod.toLowerCase().contains('cash')
                        ? Icons.money
                        : Icons.credit_card,
                    size: 18,
                    color: AppColors.mediumGreen,
                  ),
                  SizedBox(width: 6),
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
          ),
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
                      ? AppColors.mediumGreen.withOpacity(0.1)
                      : Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  OrderHelpers.capitalizeFirst(paymentStatus),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: paymentStatus.toLowerCase() == 'paid'
                        ? AppColors.mediumGreen
                        : Colors.amber[800],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(color: Colors.grey[200]),
          SizedBox(height: 16),
          _buildPriceRow('Subtotal', subtotal),
          SizedBox(height: 10),
          _buildPriceRow('Shipping Fee', shippingFee),
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
                  color: AppColors.mediumGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, dynamic price) {
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
