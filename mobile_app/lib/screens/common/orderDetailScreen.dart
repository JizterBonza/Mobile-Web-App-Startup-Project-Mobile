import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../provider/order_status_provider.dart';
import '../../widgets/order/order_header_widget.dart';
import '../../widgets/order/order_timeline_widget.dart';
import '../../widgets/order/order_items_widget.dart';
import '../../widgets/order/delivery_details_widget.dart';
import '../../widgets/order/payment_summary_widget.dart';
import '../customer/paymentWebViewScreen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService();
  bool _isCancelling = false;
  bool _isInitiatingPayment = false;
  Map<String, String> _paymentMethodNames = {};

  Future<void> _loadPaymentMethodNames() async {
    final names = await PaymentService.getPaymentMethodNames();
    if (mounted) setState(() => _paymentMethodNames = names);
  }

  @override
  void initState() {
    super.initState();
    _loadPaymentMethodNames();
  }

  String _getPaymentMethodDisplayName(String? paymentMethodId) {
    if (paymentMethodId == null || paymentMethodId.isEmpty) return 'N/A';
    return _paymentMethodNames[paymentMethodId] ?? paymentMethodId;
  }

  Future<void> _payNow(String orderId) async {
    setState(() => _isInitiatingPayment = true);

    try {
      final paymentService = PaymentService();
      final result = await paymentService.initiateCheckout(orderId: orderId);

      if (!mounted) return;

      if (result['success'] == true &&
          result['checkout_url'] != null &&
          result['checkout_url'].toString().isNotEmpty) {
        final paymentResult = await Navigator.push<PaymentResult>(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebViewScreen(
              checkoutUrl: result['checkout_url'].toString(),
            ),
          ),
        );

        if (!mounted) return;

        switch (paymentResult) {
          case PaymentResult.success:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Payment completed successfully!'),
                  ],
                ),
                backgroundColor: AppColors.mediumGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            );
            Navigator.pop(context, true);
            break;
          case PaymentResult.failed:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Payment failed. Please try again.'),
                  ],
                ),
                backgroundColor: Colors.red[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            );
            break;
          case PaymentResult.cancelled:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Payment cancelled.'),
                  ],
                ),
                backgroundColor: Colors.orange[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            );
            break;
          case null:
            break;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child:
                      Text(result['message'] ?? 'Could not initiate payment'),
                ),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('An error occurred'),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInitiatingPayment = false);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange[700], size: 28),
            SizedBox(width: 12),
            Text('Cancel Order'),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
          style: TextStyle(color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No, Keep It',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final result = await _orderService.cancelOrder(orderId);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Order cancelled successfully'),
              ],
            ),
            backgroundColor: AppColors.mediumGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                    child: Text(result['message'] ?? 'Failed to cancel order')),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('An error occurred'),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderStatusProvider>(
      builder: (context, orderStatusProvider, child) {
        final orderCode = widget.order['order_code']?.toString() ?? 'N/A';

        // Parse order_status as ID (number) and get description from provider
        final orderStatusId = widget.order['order_status'];
        int? statusId;
        if (orderStatusId is int) {
          statusId = orderStatusId;
        } else if (orderStatusId is String) {
          statusId = int.tryParse(orderStatusId);
        } else if (orderStatusId != null) {
          statusId = int.tryParse(orderStatusId.toString());
        }

        // Get status description from provider using ID
        final orderStatusDesc = statusId != null
            ? orderStatusProvider.getOrderStatusDescription(statusId)
            : null;
        final orderStatus = orderStatusDesc ?? 'Pending';

        final orderedAt = widget.order['ordered_at']?.toString() ?? '';
        final orderId = widget.order['id']?.toString() ??
            widget.order['order_id']?.toString() ??
            '';
        final canCancel = orderStatus.toLowerCase() == 'pending';
        final paymentStatus =
            widget.order['payment_status']?.toString().toLowerCase() ??
                'pending';
        final canPay = canCancel && paymentStatus != 'paid';
        final orderItems = widget.order['order_items'] as List? ?? [];
        final shippingAddress =
            widget.order['shipping_address']?.toString() ?? 'No address';
        final orderInstruction = widget.order['order_instruction']?.toString();
        final showBottomBar = canCancel || canPay;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text(
              'Order Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.grey[700]),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OrderHeaderWidget(
                  orderCode: orderCode,
                  orderStatus: orderStatus,
                  orderedAt: orderedAt,
                ),
                SizedBox(height: 16),
                OrderTimelineWidget(currentStatus: orderStatus),
                SizedBox(height: 16),
                OrderItemsWidget(orderItems: orderItems),
                SizedBox(height: 16),
                DeliveryDetailsWidget(
                  shippingAddress: shippingAddress,
                  orderInstruction: orderInstruction,
                ),
                SizedBox(height: 16),
                PaymentSummaryWidget(
                  subtotal: widget.order['subtotal'],
                  shippingFee: widget.order['shipping_fee'],
                  totalAmount: widget.order['total_amount'],
                  paymentMethod: _getPaymentMethodDisplayName(
                      widget.order['payment_method']?.toString()),
                  paymentStatus: paymentStatus,
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
          bottomNavigationBar:
              showBottomBar ? _buildBottomBar(orderId, canPay) : null,
        );
      },
    );
  }

  Widget _buildBottomBar(String orderId, bool canPay) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isCancelling ? null : () => _cancelOrder(orderId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[600],
                  side: BorderSide(color: Colors.red[400]!),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCancelling
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red[600],
                        ),
                      )
                    : Text(
                        'Cancel Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: canPay
                  ? ElevatedButton.icon(
                      onPressed:
                          _isInitiatingPayment ? null : () => _payNow(orderId),
                      icon: _isInitiatingPayment
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.payment, size: 20),
                      label: Text(
                        'Pay Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mediumGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.mediumGreen.withOpacity(0.6),
                        disabledForegroundColor: Colors.white70,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Contact support coming soon!'),
                            backgroundColor: AppColors.mediumGreen,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mediumGreen,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Contact Support',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
