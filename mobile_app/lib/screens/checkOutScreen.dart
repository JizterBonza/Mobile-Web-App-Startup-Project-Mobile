import 'package:flutter/material.dart';
import '../constants/constants.dart';
import '../services/order_service.dart';
import '../services/api_service.dart';
import '../utils/snackbar_helper.dart';
import 'customerDashboardScreen.dart';

class CheckOutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedCartItems;

  const CheckOutScreen({
    super.key,
    required this.selectedCartItems,
  });

  @override
  State<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shippingAddressController = TextEditingController();
  final _orderInstructionController = TextEditingController();

  String? _selectedPaymentMethod;
  bool _isLoading = false;
  bool _isLoadingProfile = true;
  String? _userName;
  String? _userPhone;

  final List<String> _paymentMethods = [
    'Cash on Delivery',
    'GCash',
    'PayMaya',
    'Bank Transfer',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _shippingAddressController.dispose();
    _orderInstructionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userName = await ApiService.getUserName();
      final userPhone = await ApiService.getUserMobileNumber();
      final userAddress = await ApiService.getUserAddress();

      if (mounted) {
        setState(() {
          _userName = userName ?? 'User';
          _userPhone = userPhone ?? '';
          _shippingAddressController.text = userAddress ?? '';
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  // Get effective price - use item_price if different from price_snapshot
  double _getEffectivePrice(Map<String, dynamic> item) {
    final priceSnapshot = double.parse(item['price_snapshot'].toString());
    final itemPrice = double.parse(item['item_price'].toString());
    return priceSnapshot != itemPrice ? itemPrice : priceSnapshot;
  }

  // Standard shipping fee
  static const double _standardShippingFee = 50.00;

  double get _subtotal {
    return widget.selectedCartItems.fold(0.0, (sum, item) {
      final effectivePrice = _getEffectivePrice(item);
      return sum + (effectivePrice * (item['quantity'] as int));
    });
  }

  double get _shippingFee {
    return _standardShippingFee;
  }

  double get _tax {
    return _subtotal * 0.08; // 8% tax
  }

  double get _total {
    return _subtotal + _shippingFee;
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPaymentMethod == null || _selectedPaymentMethod!.isEmpty) {
      SnackbarHelper.showError(
        context,
        'Please select a payment method',
      );
      return;
    }

    if (_shippingAddressController.text.trim().isEmpty) {
      SnackbarHelper.showError(
        context,
        'Please enter a shipping address',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Format items for order creation with all required fields
    final orderItems = widget.selectedCartItems.map((cartItem) {
      return {
        'item_id': cartItem['item_id'].toString(),
        'shop_id': cartItem['shop_id'].toString(),
        'quantity': cartItem['quantity'] as int,
        'price_at_purchase': _getEffectivePrice(cartItem),
      };
    }).toList();

    // Show loading indicator
    SnackbarHelper.showLoading(context, 'Placing your order...');

    try {
      final orderService = OrderService();
      final result = await orderService.createOrder(
        items: orderItems,
        subtotal: _subtotal,
        shippingFee: _shippingFee,
        totalAmount: _total,
        shippingAddress: _shippingAddressController.text.trim(),
        orderInstruction: _orderInstructionController.text.trim().isEmpty
            ? null
            : _orderInstructionController.text.trim(),
        paymentMethod: _selectedPaymentMethod!,
      );

      SnackbarHelper.hide(context);

      if (result['success'] == true) {
        // Show success message
        SnackbarHelper.showSuccess(
          context,
          result['message'] ?? 'Order placed successfully!',
          duration: Duration(seconds: 3),
        );

        // Navigate to customer dashboard after a short delay
        await Future.delayed(Duration(seconds: 1));

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerDashboardScreen(),
            ),
            (route) => false,
          );
        }
      } else {
        SnackbarHelper.showError(
          context,
          result['message'] ?? 'Failed to place order',
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      SnackbarHelper.hide(context);
      SnackbarHelper.showError(
        context,
        'Error placing order: ${e.toString()}',
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Checkout',
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
      body: _isLoadingProfile
          ? _buildLoadingState()
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Order Items Section
                    _buildOrderItemsSection(),

                    // Shipping Address Section
                    _buildShippingAddressSection(),

                    // Payment Method Section
                    _buildPaymentMethodSection(),

                    // Order Instructions Section
                    _buildOrderInstructionsSection(),

                    // Order Summary Section
                    _buildOrderSummarySection(),

                    // Place Order Button
                    _buildPlaceOrderButton(),

                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.mediumGreen),
          ),
          SizedBox(height: 16),
          Text(
            'Loading checkout...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsSection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.mediumGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Order Items',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...widget.selectedCartItems.asMap().entries.map((entry) {
            final item = entry.value;
            final isLast = entry.key == widget.selectedCartItems.length - 1;
            return _buildOrderItem(item, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item, bool isLast) {
    final effectivePrice = _getEffectivePrice(item);
    final quantity = item['quantity'] as int;
    final itemTotal = effectivePrice * quantity;

    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image placeholder
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.mediumGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.mediumGreen.withOpacity(0.2),
              ),
            ),
            child: Icon(
              Icons.shopping_bag,
              color: AppColors.mediumGreen,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['item_name'] ?? 'Unknown Item',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'Quantity: $quantity',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '₱${effectivePrice.toStringAsFixed(2)} × $quantity',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          // Item total
          Text(
            '₱${itemTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.mediumGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingAddressSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: AppColors.mediumGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Shipping Address',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _shippingAddressController,
            decoration: InputDecoration(
              hintText: 'Enter your shipping address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.mediumGreen, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a shipping address';
              }
              return null;
            },
          ),
          if (_userName != null || _userPhone != null)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    _userName ?? 'User',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_userPhone != null && _userPhone!.isNotEmpty) ...[
                    SizedBox(width: 16),
                    Icon(Icons.phone_outlined,
                        size: 16, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      _userPhone!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payment_outlined,
                color: AppColors.mediumGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ..._paymentMethods.map((method) {
            return _buildPaymentMethodOption(method);
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOption(String method) {
    final isSelected = _selectedPaymentMethod == method;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPaymentMethod = method;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.mediumGreen.withOpacity(0.1)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.mediumGreen : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Radio<String>(
                value: method,
                groupValue: _selectedPaymentMethod,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethod = value;
                  });
                },
                activeColor: AppColors.mediumGreen,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  method,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: Colors.grey[900],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInstructionsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_outlined,
                color: AppColors.mediumGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Order Instructions (Optional)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _orderInstructionController,
            decoration: InputDecoration(
              hintText: 'Add any special instructions for delivery...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.mediumGreen, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummarySection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_outlined,
                color: AppColors.mediumGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Item breakdown with quantities
          ...widget.selectedCartItems.map((item) {
            final effectivePrice = _getEffectivePrice(item);
            final quantity = item['quantity'] as int;
            final itemTotal = effectivePrice * quantity;
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item['item_name'] ?? 'Unknown Item'} (×$quantity)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₱${itemTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[900],
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 12),
          Divider(height: 1),
          SizedBox(height: 12),
          _buildSummaryRow('Subtotal', '₱${_subtotal.toStringAsFixed(2)}'),
          SizedBox(height: 8),
          _buildSummaryRow(
              'Shipping Fee', '₱${_shippingFee.toStringAsFixed(2)}'),
          SizedBox(height: 8),
          Divider(height: 1),
          SizedBox(height: 12),
          _buildSummaryRow(
            'Total',
            '₱${_total.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: Colors.grey[isTotal ? 900 : 700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? AppColors.mediumGreen : Colors.grey[900],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceOrderButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _placeOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mediumGreen,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: Colors.grey[400],
        ),
        child: _isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Place Order - ₱${_total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
