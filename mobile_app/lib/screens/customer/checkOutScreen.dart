import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../models/addressModel.dart';
import '../../provider/address_provider.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../services/voucher_service.dart';
import '../../utils/cart_item_pricing.dart';
import '../../utils/media_url.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import 'customerDashboardScreen.dart';
import 'paymentWebViewScreen.dart';
import '../common/editAddressScreen.dart';

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
  final _orderInstructionController = TextEditingController();
  final _voucherController = TextEditingController();

  int? _selectedPaymentMethodId;
  int? _selectedDeliveryMethodId;
  String? _selectedDeliveryMethodDescription;
  String? _selectedDeliveryMethodInfo;
  bool _isLoading = false;
  bool _isLoadingProfile = true;
  bool _isLoadingDeliveryMethods = true;
  bool _isLoadingPaymentMethods = true;
  bool _isLoadingCalculation = true;
  bool _isValidatingVoucher = false;

  double _subtotal = 0.0;
  double _deliveryBaseFee = 0.0;
  double _deliveryKmFee = 0.0;
  double _deliveryDistanceKm = 0.0;
  bool _isReducedBase = false;
  double _shippingFee = 0.0;
  double _heavySurcharge = 0.0;
  int _heavySurchargeUnits = 0;
  double _totalWeightKg = 0.0;
  double _multiStoreFee = 0.0;
  double _movPenaltyFee = 0.0;
  double _totalFees = 0.0;
  double _total = 0.0;
  double _voucherDiscount = 0.0;
  bool _voucherDiscountIncludedInTotal = false;
  int _storeCount = 0;
  bool _isPickup = false;
  int _calculationRequestId = 0;

  String? _appliedVoucherCode;
  String? _voucherSuccessMessage;
  String? _voucherErrorMessage;

  // Address selection
  List<AddressModel> _addresses = [];
  AddressModel? _selectedAddress;

  // Delivery methods from API
  List<Map<String, dynamic>> _deliveryMethods = [];

  // Payment methods from API
  List<Map<String, dynamic>> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadDeliveryMethods();
    _loadPaymentMethods();
  }

  @override
  void dispose() {
    _orderInstructionController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  double get _displayTotal {
    if (_voucherDiscount > 0 && !_voucherDiscountIncludedInTotal) {
      final adjusted = _total - _voucherDiscount;
      return adjusted < 0 ? 0 : adjusted;
    }
    return _total;
  }

  Future<void> _loadUserProfile() async {
    try {
      // Fetch addresses from provider
      if (mounted) {
        final addressProvider = context.read<AddressProvider>();
        await addressProvider.fetchAddresses();
        _addresses = addressProvider.addresses;
        _selectedAddress = addressProvider.defaultAddress ??
            (_addresses.isNotEmpty ? _addresses.first : null);
      }

      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
        _maybeRecalculateOrder();
      }
    } catch (e) {
      print('Error loading user profile: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
        _maybeRecalculateOrder();
      }
    }
  }

  Future<void> _loadDeliveryMethods() async {
    try {
      final orderService = OrderService();
      final result = await orderService.fetchDeliveryMethods();

      if (mounted) {
        if (result['success'] == true && result['data'] != null) {
          final methods = (result['data'] as List)
              .where((method) => method['status'] == true)
              .map((method) => {
                    'id': method['id'],
                    'description': method['description'],
                    'info': method['info'],
                  })
              .toList();

          final selectedMethod = methods.isNotEmpty ? methods.first : null;
          setState(() {
            _deliveryMethods = List<Map<String, dynamic>>.from(methods);
            if (selectedMethod != null && _selectedDeliveryMethodId == null) {
              _selectedDeliveryMethodId = selectedMethod['id'] is int
                  ? selectedMethod['id'] as int
                  : int.tryParse(selectedMethod['id'].toString());
              _selectedDeliveryMethodDescription =
                  selectedMethod['description']?.toString();
              _selectedDeliveryMethodInfo = selectedMethod['info']?.toString();
            }
            _isLoadingDeliveryMethods = false;
          });
          _maybeRecalculateOrder();
        } else {
          setState(() {
            _isLoadingDeliveryMethods = false;
          });
        }
      }
    } catch (e) {
      print('Error loading delivery methods: $e');
      if (mounted) {
        setState(() {
          _isLoadingDeliveryMethods = false;
        });
      }
    }
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final paymentService = PaymentService();
      final result = await paymentService.fetchPaymentMethods();

      if (mounted) {
        if (result['success'] == true && result['data'] != null) {
          final methods = (result['data'] as List)
              .map((method) => {
                    'id': method['id'],
                    'name': method['name']?.toString() ?? '',
                  })
              .where((method) => method['name']?.toString().isNotEmpty == true)
              .toList();

          setState(() {
            _paymentMethods = List<Map<String, dynamic>>.from(methods);
            _isLoadingPaymentMethods = false;
          });
        } else {
          setState(() {
            _isLoadingPaymentMethods = false;
          });
        }
      }
    } catch (e) {
      print('Error loading payment methods: $e');
      if (mounted) {
        setState(() {
          _isLoadingPaymentMethods = false;
        });
      }
    }
  }

  double _getEffectivePrice(Map<String, dynamic> item) {
    return CartItemPricing.fromCartMap(item).effectivePrice;
  }

  Future<void> _maybeRecalculateOrder() async {
    if (_selectedAddress == null || _selectedDeliveryMethodId == null) {
      if (mounted) {
        setState(() {
          _isLoadingCalculation = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingCalculation = true;
    });
    await _loadOrderCalculation();
  }

  Future<void> _loadOrderCalculation() async {
    final requestId = ++_calculationRequestId;

    try {
      final orderItems = widget.selectedCartItems.map((cartItem) {
        return {
          'cart_id': cartItem['id'] is int
              ? cartItem['id']
              : int.tryParse(cartItem['id'].toString()) ?? cartItem['id'],
          'item_id': cartItem['item_id'].toString(),
          'shop_id': cartItem['shop_id'].toString(),
          'quantity': cartItem['quantity'] is int
              ? cartItem['quantity'] as int
              : int.tryParse(cartItem['quantity'].toString()) ?? 1,
          'price_at_purchase': _getEffectivePrice(cartItem),
        };
      }).toList();

      final orderService = OrderService();
      final result = await orderService.calculateOrder(
        items: orderItems,
        shippingAddressId: _selectedAddress?.id,
        deliveryMethodId: _selectedDeliveryMethodId,
        voucherCode: _appliedVoucherCode,
      );

      if (!mounted || requestId != _calculationRequestId) return;

      if (result['success'] == true) {
        final feeDiscount =
            (result['voucher_discount_amount'] as num?)?.toDouble() ?? 0.0;
        setState(() {
          _subtotal = (result['subtotal'] as num).toDouble();
          _deliveryBaseFee = (result['delivery_base_fee'] as num).toDouble();
          _deliveryKmFee = (result['delivery_km_fee'] as num).toDouble();
          _deliveryDistanceKm =
              (result['delivery_distance_km'] as num).toDouble();
          _isReducedBase = result['is_reduced_base'] == true;
          _shippingFee = (result['shipping_fee'] as num).toDouble();
          _heavySurcharge = (result['heavy_surcharge'] as num).toDouble();
          _heavySurchargeUnits = result['heavy_surcharge_units'] as int;
          _totalWeightKg = (result['total_weight_kg'] as num).toDouble();
          _multiStoreFee = (result['multi_store_fee'] as num).toDouble();
          _movPenaltyFee = (result['mov_penalty_fee'] as num).toDouble();
          _totalFees = (result['total_fees'] as num).toDouble();
          _total = (result['total_amount'] as num).toDouble();
          _storeCount = result['store_count'] as int;
          _isPickup = result['is_pickup'] == true;
          // calculate-fee total_amount already reflects voucher when present.
          _voucherDiscount = feeDiscount;
          _voucherDiscountIncludedInTotal = true;
          _isLoadingCalculation = false;
        });
      } else {
        print('Error calculating order: ${result['message']}');
        setState(() {
          _isLoadingCalculation = false;
        });
        SnackbarHelper.showError(
          context,
          result['message']?.toString() ?? 'Failed to calculate order fees',
        );
      }
    } catch (e) {
      print('Error loading order calculation: $e');
      if (!mounted || requestId != _calculationRequestId) return;
      setState(() {
        _isLoadingCalculation = false;
      });
      SnackbarHelper.showError(
        context,
        'Failed to calculate order fees',
      );
    }
  }

  /// Groups selected cart items by shop_id. Returns a list of maps:
  /// [{ shop_id, shop_name, items }, ...]
  List<Map<String, dynamic>> get _itemsGroupedByShop {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in widget.selectedCartItems) {
      final shopId = item['shop_id']?.toString() ?? 'unknown';
      map.putIfAbsent(shopId, () => []).add(item);
    }
    return map.entries.map((e) {
      final items = e.value;
      final shopName = items.isNotEmpty && items.first['shop_name'] != null
          ? items.first['shop_name'].toString()
          : 'Shop ${e.key}';
      return {
        'shop_id': e.key,
        'shop_name': shopName,
        'items': items,
      };
    }).toList();
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDeliveryMethodId == null) {
      SnackbarHelper.showError(
        context,
        'Please select a delivery method',
      );
      return;
    }

    // Payment method selection UI is hidden; fall back to the first available
    // payment method when the user has not explicitly selected one.
    if (_selectedAddress == null) {
      SnackbarHelper.showError(
        context,
        'Please select a shipping address',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Format items for order creation with all required fields
    final orderItems = widget.selectedCartItems.map((cartItem) {
      return {
        'cart_id': cartItem['id'] as int,
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
        shippingFee: _totalFees,
        totalAmount: _displayTotal,
        shippingAddress: _selectedAddress!.fullAddress,
        shippingAddressId: _selectedAddress!.id,
        orderInstruction: _orderInstructionController.text.trim().isEmpty
            ? null
            : _orderInstructionController.text.trim(),
        deliveryMethodId: _selectedDeliveryMethodId!,
        paymentMethod: null,
        voucherCode: _appliedVoucherCode,
      );

      SnackbarHelper.hide(context);

      if (result['success'] == true) {
        final checkoutUrl = result['checkout_url'];

        if (checkoutUrl != null && checkoutUrl.toString().isNotEmpty) {
          if (!mounted) return;

          final data = result['data'];
          final orderId = data is Map
              ? (data['id'] ?? data['order_id'])?.toString()
              : result['order_id']?.toString();

          if (orderId == null || orderId.isEmpty) {
            SnackbarHelper.showError(
              context,
              'Order created but order ID was not returned.',
            );
            setState(() => _isLoading = false);
            return;
          }

          final paymentResult = await Navigator.push<PaymentResult>(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentWebViewScreen(
                checkoutUrl: checkoutUrl.toString(),
                orderId: orderId,
              ),
            ),
          );

          if (!mounted) return;

          switch (paymentResult) {
            case PaymentResult.success:
              SnackbarHelper.showSuccess(
                context,
                'Payment completed successfully!',
                duration: Duration(seconds: 3),
              );
              break;
            case PaymentResult.failed:
              SnackbarHelper.showError(
                context,
                'Payment failed. Please try again.',
              );
              setState(() => _isLoading = false);
              return;
            case PaymentResult.cancelled:
              SnackbarHelper.showWarning(
                context,
                'Payment was cancelled. Your order is pending payment.',
              );
              break;
            case null:
              SnackbarHelper.showInfo(
                context,
                result['message'] ?? 'Order placed. Please complete payment.',
              );
              break;
          }
        } else {
          if (mounted) {
            SnackbarHelper.showSuccess(
              context,
              result['message'] ?? 'Order placed successfully!',
              duration: Duration(seconds: 3),
            );
          }
        }

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
      backgroundColor: AppColors.surfaceLight,
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

                    // Delivery Method Section
                    _buildDeliveryMethodSection(),

                    // Shipping Address Section
                    _buildShippingAddressSection(),

                    // Payment Method Section (hidden per product requirement;
                    // payment method defaults to the first available option when
                    // the order is placed).
                    // _buildPaymentMethodSection(),

                    // Order Instructions Section
                    _buildOrderInstructionsSection(),

                    // Voucher Section
                    _buildVoucherSection(),

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
    return const GenericListSkeleton(count: 4, itemHeight: 120);
  }

  Widget _buildOrderItemsSection() {
    final groups = _itemsGroupedByShop;
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
                color: AppColors.primaryGreen,
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
          ...groups.asMap().entries.expand((groupEntry) {
            final groupIndex = groupEntry.key;
            final group = groupEntry.value;
            final shopName = group['shop_name'] as String;
            final items = group['items'] as List<Map<String, dynamic>>;
            final isLastGroup = groupIndex == groups.length - 1;
            return [
              _buildShopHeader(shopName),
              ...items.asMap().entries.map((entry) {
                final isLastItemInGroup = entry.key == items.length - 1;
                final isLastOverall = isLastGroup && isLastItemInGroup;
                return _buildOrderItem(entry.value, isLastOverall);
              }),
              if (!isLastGroup) SizedBox(height: 12),
            ];
          }),
        ],
      ),
    );
  }

  Widget _buildShopHeader(String shopName) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.store_outlined,
            color: AppColors.primaryGreen,
            size: 18,
          ),
          SizedBox(width: 6),
          Text(
            shopName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item, bool isLast) {
    final pricing = CartItemPricing.fromCartMap(item);
    final effectivePrice = pricing.effectivePrice;
    final quantity = item['quantity'] as int;
    final itemTotal = effectivePrice * quantity;
    final imageUrl = resolveItemImageUrl(item['item_images']);

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
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primaryGreen.withOpacity(0.2),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.shopping_bag,
                      color: AppColors.primaryGreen,
                      size: 24,
                    ),
                  )
                : Icon(
                    Icons.shopping_bag,
                    color: AppColors.primaryGreen,
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
                CartItemPriceDisplay(
                  pricing: pricing,
                  primaryFontSize: 14,
                  strikethroughFontSize: 12,
                  compact: true,
                ),
                SizedBox(height: 2),
                Text(
                  '× $quantity',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
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
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryMethodSection() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                Icons.local_shipping_outlined,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Delivery Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_isLoadingDeliveryMethods)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                  ),
                ),
              ),
            )
          else if (_deliveryMethods.isEmpty)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentAmber.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 20,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No delivery methods available. Please try again later.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.accentAmberDark,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedDeliveryMethodId,
                  isExpanded: true,
                  hint: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Select delivery method',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  borderRadius: BorderRadius.circular(8),
                  icon:
                      Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
                  items: _deliveryMethods.map((method) {
                    final description = method['description'] as String;
                    return DropdownMenuItem<int>(
                      value: method['id'] as int,
                      child: Row(
                        children: [
                          Icon(
                            _getDeliveryMethodIcon(description),
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[900],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    setState(() {
                      _selectedDeliveryMethodId = newValue;
                      final selectedMethod = _deliveryMethods
                          .firstWhere((m) => m['id'] == newValue);
                      _selectedDeliveryMethodDescription =
                          selectedMethod['description'] as String;
                      _selectedDeliveryMethodInfo =
                          selectedMethod['info'] as String;
                    });
                    _maybeRecalculateOrder();
                  },
                ),
              ),
            ),
          if (_selectedDeliveryMethodInfo != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedDeliveryMethodInfo ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getDeliveryMethodIcon(String description) {
    final lowerDesc = description.toLowerCase();
    if (lowerDesc.contains('contact') || lowerDesc.contains('no contact')) {
      return Icons.contactless_outlined;
    } else if (lowerDesc.contains('express') || lowerDesc.contains('fast')) {
      return Icons.flash_on_outlined;
    } else if (lowerDesc.contains('pickup') || lowerDesc.contains('pick up')) {
      return Icons.store_outlined;
    }
    return Icons.local_shipping_outlined;
  }

  Widget _buildShippingAddressSection() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                color: AppColors.primaryGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Shipping Address',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              // Add new address button
              TextButton.icon(
                onPressed: _navigateToAddAddress,
                icon: Icon(Icons.add, size: 18),
                label: Text('Add New'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Address selection
          _addresses.isEmpty ? _buildNoAddressState() : _buildAddressDropdown(),
        ],
      ),
    );
  }

  Widget _buildNoAddressState() {
    return GestureDetector(
      onTap: _navigateToAddAddress,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryGreen.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_location_alt_outlined,
                color: AppColors.primaryGreen,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Shipping Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tap to add your delivery location',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.primaryGreen,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Address dropdown
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AddressModel>(
              value: _selectedAddress,
              isExpanded: true,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              borderRadius: BorderRadius.circular(8),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              items: _addresses.map((address) {
                return DropdownMenuItem<AddressModel>(
                  value: address,
                  child: _buildAddressDropdownItem(address),
                );
              }).toList(),
              onChanged: (AddressModel? newValue) {
                setState(() {
                  _selectedAddress = newValue;
                });
                _maybeRecalculateOrder();
              },
              selectedItemBuilder: (BuildContext context) {
                return _addresses.map((address) {
                  return _buildSelectedAddressDisplay(address);
                }).toList();
              },
            ),
          ),
        ),
        // Selected address details
        if (_selectedAddress != null) ...[
          SizedBox(height: 12),
          _buildSelectedAddressCard(),
        ],
      ],
    );
  }

  Widget _buildAddressDropdownItem(AddressModel address) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getLabelIcon(address.label),
              color: AppColors.primaryGreen,
              size: 16,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      address.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                    if (address.isDefault) ...[
                      SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  address.fullAddress,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAddressDisplay(AddressModel address) {
    return Row(
      children: [
        Icon(
          _getLabelIcon(address.label),
          color: AppColors.primaryGreen,
          size: 18,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            address.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedAddressCard() {
    final address = _selectedAddress!;
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipient info
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  address.recipientName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              if (address.phone.isNotEmpty) ...[
                Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  address.phone,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8),
          // Full address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: Colors.grey[600]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  address.fullAddress,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getLabelIcon(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'office':
      case 'work':
        return Icons.business_outlined;
      case 'parents house':
        return Icons.family_restroom_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  Future<void> _navigateToAddAddress() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const EditAddressScreen(),
      ),
    );

    // If address was added successfully, refresh addresses
    if (result != null && mounted) {
      final addressProvider = context.read<AddressProvider>();
      await addressProvider.fetchAddresses();

      setState(() {
        _addresses = addressProvider.addresses;
        // Select the newly added address or default
        _selectedAddress = addressProvider.defaultAddress ??
            (_addresses.isNotEmpty ? _addresses.first : null);
      });
      _maybeRecalculateOrder();
    }
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
                color: AppColors.primaryGreen,
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
          if (_isLoadingPaymentMethods)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: AppColors.primaryGreen,
                ),
              ),
            )
          else if (_paymentMethods.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No payment methods available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            )
          else
            ..._paymentMethods.map((method) {
              return _buildPaymentMethodOption(method);
            }),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOption(Map<String, dynamic> method) {
    final methodId = method['id'] as int?;
    final methodName = method['name']?.toString() ?? '';
    final isSelected = _selectedPaymentMethodId == methodId;

    if (methodId == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPaymentMethodId = methodId;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryGreen.withOpacity(0.1)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primaryGreen : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Radio<int>(
                value: methodId,
                groupValue: _selectedPaymentMethodId,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethodId = value;
                  });
                },
                activeColor: AppColors.primaryGreen,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  methodName,
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

  bool get _isContactlessDelivery {
    if (_selectedDeliveryMethodDescription == null) return false;
    final lowerDesc = _selectedDeliveryMethodDescription!.toLowerCase();
    return lowerDesc.contains('contact') || lowerDesc.contains('no contact');
  }

  Future<void> _applyVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty || _isValidatingVoucher) return;

    if (_selectedAddress == null || _selectedDeliveryMethodId == null) {
      setState(() {
        _voucherErrorMessage =
            'Select a shipping address and delivery method before applying a voucher.';
        _voucherSuccessMessage = null;
      });
      return;
    }

    if (_isLoadingCalculation || _subtotal <= 0) {
      setState(() {
        _voucherErrorMessage =
            'Wait for order fees to finish calculating, then try again.';
        _voucherSuccessMessage = null;
      });
      return;
    }

    // Validate against pre-voucher totals (fee total without discount).
    final preVoucherTotal = _voucherDiscountIncludedInTotal && _voucherDiscount > 0
        ? _total + _voucherDiscount
        : _total;

    setState(() {
      _isValidatingVoucher = true;
      _voucherErrorMessage = null;
      _voucherSuccessMessage = null;
    });

    final result = await VoucherService().validateCode(
      code: code,
      subtotal: _subtotal,
      shippingFee: _totalFees,
      totalAmount: preVoucherTotal,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final discount =
          (result['voucher_discount_amount'] as num?)?.toDouble() ?? 0.0;
      final appliedCode =
          (result['voucher_code']?.toString() ?? code).trim();
      final name = result['name']?.toString();

      setState(() {
        _appliedVoucherCode = appliedCode;
        _voucherDiscount = discount;
        // Prefer server total from validate until calculate-fee returns.
        final validatedTotal =
            (result['total_amount'] as num?)?.toDouble();
        if (validatedTotal != null && validatedTotal > 0) {
          _total = validatedTotal;
          _voucherDiscountIncludedInTotal = true;
        } else {
          _voucherDiscountIncludedInTotal = false;
        }
        _voucherController.text = appliedCode;
        _voucherErrorMessage = null;
        _voucherSuccessMessage =
            name != null && name.isNotEmpty ? name : null;
        _isValidatingVoucher = false;
      });
      await _maybeRecalculateOrder();
    } else {
      setState(() {
        _appliedVoucherCode = null;
        _voucherDiscount = 0.0;
        _voucherDiscountIncludedInTotal = true;
        _voucherSuccessMessage = null;
        _voucherErrorMessage =
            result['message']?.toString() ?? 'Invalid voucher code.';
        _isValidatingVoucher = false;
      });
    }
  }

  void _clearVoucher() {
    setState(() {
      _voucherController.clear();
      _appliedVoucherCode = null;
      _voucherDiscount = 0.0;
      _voucherDiscountIncludedInTotal = true;
      _voucherSuccessMessage = null;
      _voucherErrorMessage = null;
    });
    _maybeRecalculateOrder();
  }

  Widget _buildVoucherSection() {
    final hasApplied = _appliedVoucherCode != null;
    final canApply = _voucherController.text.trim().isNotEmpty &&
        !_isValidatingVoucher &&
        !hasApplied;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                Icons.local_offer_outlined,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Voucher',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _voucherController,
                  enabled: !hasApplied && !_isValidatingVoucher,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Enter voucher code',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
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
                      borderSide: BorderSide(
                        color: AppColors.primaryGreen,
                        width: 2,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: hasApplied
                        ? AppColors.primaryGreen.withOpacity(0.05)
                        : AppColors.surfaceLight,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: hasApplied
                        ? IconButton(
                            tooltip: 'Remove voucher',
                            onPressed: _clearVoucher,
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: canApply ? _applyVoucher : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isValidatingVoucher
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          hasApplied ? 'Applied' : 'Apply',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
          if (_voucherSuccessMessage != null) ...[
            SizedBox(height: 8),
            Text(
              _voucherSuccessMessage!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (_voucherErrorMessage != null) ...[
            SizedBox(height: 8),
            Text(
              _voucherErrorMessage!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderInstructionsSection() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                color: AppColors.primaryGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    text: 'Order Instructions ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                    children: [
                      TextSpan(
                        text: _isContactlessDelivery
                            ? '(Required)'
                            : '(Optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: _isContactlessDelivery
                              ? AppColors.error
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isContactlessDelivery) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accentAmber.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please provide instructions for contactless delivery (e.g., where to leave the package)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accentAmberDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 16),
          TextFormField(
            controller: _orderInstructionController,
            decoration: InputDecoration(
              hintText: _isContactlessDelivery
                  ? 'E.g., Leave at the front door, behind the gate...'
                  : 'Add any special instructions for delivery...',
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
                borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.error.withOpacity(0.6), width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.error.withOpacity(0.6), width: 2),
              ),
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            maxLines: 3,
            validator: (value) {
              if (_isContactlessDelivery &&
                  (value == null || value.trim().isEmpty)) {
                return 'Please provide delivery instructions for contactless delivery';
              }
              return null;
            },
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
                color: AppColors.primaryGreen,
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
          // Item breakdown grouped by shop
          ..._itemsGroupedByShop.expand((group) {
            final shopName = group['shop_name'] as String;
            final items = group['items'] as List<Map<String, dynamic>>;
            return [
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  shopName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              ...items.map((item) {
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
            ];
          }),
          SizedBox(height: 12),
          Divider(height: 1),
          SizedBox(height: 12),
          if (_isLoadingCalculation)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                  ),
                ),
              ),
            )
          else if (_selectedAddress == null || _selectedDeliveryMethodId == null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _selectedAddress == null
                    ? 'Select a shipping address to calculate fees.'
                    : 'Select a delivery method to calculate fees.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            )
          else ...[
            _buildSummaryRow('Subtotal', '₱${_subtotal.toStringAsFixed(2)}'),
            ..._buildFeeBreakdownRows(),
            SizedBox(height: 8),
            Divider(height: 1),
            SizedBox(height: 12),
            _buildSummaryRow(
              'Total',
              '₱${_displayTotal.toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildFeeBreakdownRows() {
    final rows = <Widget>[];

    void addFeeRow(String label, double amount, {String? subtitle}) {
      if (amount <= 0) return;
      rows.add(SizedBox(height: 8));
      rows.add(_buildSummaryRow(
        label,
        '₱${amount.toStringAsFixed(2)}',
        subtitle: subtitle,
      ));
    }

    if (!_isPickup && _shippingFee > 0) {
      final deliveryParts = <String>[];
      if (_deliveryBaseFee > 0 || _deliveryKmFee > 0) {
        deliveryParts.add(
          '₱${_deliveryBaseFee.toStringAsFixed(0)} base + '
          '₱${_deliveryKmFee.toStringAsFixed(0)}/km',
        );
      }
      if (_deliveryDistanceKm > 0) {
        deliveryParts.add('${_deliveryDistanceKm.toStringAsFixed(1)} km');
      }
      if (_isReducedBase) {
        deliveryParts.add('reduced base');
      }
      addFeeRow(
        'Delivery Fee',
        _shippingFee,
        subtitle: deliveryParts.isNotEmpty ? deliveryParts.join(' · ') : null,
      );
    }

    addFeeRow(
      'Heavy Item Surcharge',
      _heavySurcharge,
      subtitle: _heavySurcharge > 0
          ? '${_totalWeightKg.toStringAsFixed(1)} kg · $_heavySurchargeUnits units'
          : null,
    );
    addFeeRow(
      'Multi-Store Fee',
      _multiStoreFee,
      subtitle: _multiStoreFee > 0 && _storeCount > 1
          ? '$_storeCount stores'
          : null,
    );
    addFeeRow('Minimum Order Fee', _movPenaltyFee);

    if (rows.isEmpty && _totalFees > 0) {
      rows.add(SizedBox(height: 8));
      rows.add(_buildSummaryRow(
        'Fees',
        '₱${_totalFees.toStringAsFixed(2)}',
      ));
    }

    if (_voucherDiscount > 0) {
      rows.add(SizedBox(height: 8));
      rows.add(_buildSummaryRow(
        'Voucher discount',
        '-₱${_voucherDiscount.toStringAsFixed(2)}',
        subtitle: _appliedVoucherCode,
      ));
    }

    return rows;
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
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
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
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
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
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
            color: isTotal ? AppColors.primaryGreen : Colors.grey[900],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceOrderButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: (_isLoading || _isLoadingCalculation) ? null : _placeOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
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
                _isLoadingCalculation
                    ? 'Calculating...'
                    : 'Place Order - ₱${_displayTotal.toStringAsFixed(2)}',
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
