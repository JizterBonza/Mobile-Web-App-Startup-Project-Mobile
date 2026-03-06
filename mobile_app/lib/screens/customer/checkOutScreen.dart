import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../models/addressModel.dart';
import '../../provider/address_provider.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../utils/snackbar_helper.dart';
import 'customerDashboardScreen.dart';
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

  int? _selectedPaymentMethodId;
  int? _selectedDeliveryMethodId;
  String? _selectedDeliveryMethodDescription;
  String? _selectedDeliveryMethodInfo;
  bool _isLoading = false;
  bool _isLoadingProfile = true;
  bool _isLoadingDeliveryMethods = true;
  bool _isLoadingPaymentMethods = true;

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
    super.dispose();
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

          setState(() {
            _deliveryMethods = List<Map<String, dynamic>>.from(methods);
            _isLoadingDeliveryMethods = false;
          });
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

    if (_selectedPaymentMethodId == null) {
      SnackbarHelper.showError(
        context,
        'Please select a payment method',
      );
      return;
    }

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
        shippingFee: _shippingFee,
        totalAmount: _total,
        shippingAddress: _selectedAddress!.fullAddress,
        shippingAddressId: _selectedAddress!.id,
        orderInstruction: _orderInstructionController.text.trim().isEmpty
            ? null
            : _orderInstructionController.text.trim(),
        deliveryMethodId: _selectedDeliveryMethodId!,
        paymentMethod: _selectedPaymentMethodId!.toString(),
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

                    // Delivery Method Section
                    _buildDeliveryMethodSection(),

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
          ...groups.asMap().entries.expand((groupEntry) {
            final groupIndex = groupEntry.key;
            final group = groupEntry.value;
            final shopName = group['shop_name'] as String;
            final items = group['items'] as List<Map<String, dynamic>>;
            final isLastGroup = groupIndex == groups.length - 1;
            return [
              _buildShopHeader(shopName),
              ...items.asMap().entries.map((entry) {
                final isLastItemInGroup =
                    entry.key == items.length - 1;
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
            color: AppColors.mediumGreen,
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
                color: AppColors.mediumGreen,
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
                        AlwaysStoppedAnimation<Color>(AppColors.mediumGreen),
                  ),
                ),
              ),
            )
          else if (_deliveryMethods.isEmpty)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 20,
                    color: Colors.orange[700],
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No delivery methods available. Please try again later.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
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
                            color: AppColors.mediumGreen,
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
                  },
                ),
              ),
            ),
          if (_selectedDeliveryMethodInfo != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mediumGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.mediumGreen.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.mediumGreen,
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
                  foregroundColor: AppColors.mediumGreen,
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
          color: AppColors.mediumGreen.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.mediumGreen.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.mediumGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_location_alt_outlined,
                color: AppColors.mediumGreen,
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
                    color: AppColors.mediumGreen,
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
              color: AppColors.mediumGreen,
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
            color: Colors.grey[50],
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
              color: AppColors.mediumGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getLabelIcon(address.label),
              color: AppColors.mediumGreen,
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
                          color: AppColors.mediumGreen,
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
          color: AppColors.mediumGreen,
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
        color: AppColors.mediumGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.mediumGreen.withOpacity(0.2),
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
          if (_isLoadingPaymentMethods)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: AppColors.mediumGreen,
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
              Radio<int>(
                value: methodId,
                groupValue: _selectedPaymentMethodId,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethodId = value;
                  });
                },
                activeColor: AppColors.mediumGreen,
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
                              ? Colors.red[600]
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
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange[700],
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please provide instructions for contactless delivery (e.g., where to leave the package)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
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
                borderSide: BorderSide(color: AppColors.mediumGreen, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red[400]!, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red[400]!, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
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
