import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../models/addressModel.dart';
import '../../provider/address_provider.dart';
import '../../provider/category_provider.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../services/voucher_service.dart';
import '../../utils/cart_item_pricing.dart';
import '../../utils/gamefowl_item.dart';
import '../../utils/media_url.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import 'customerDashboardScreen.dart';
import 'paymentWebViewScreen.dart';
import '../common/editAddressScreen.dart';

class CheckOutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedCartItems;

  /// Actual parent cart ID returned by the cart API, when available.
  final int? cartId;
  final OrderService? orderService;
  final PaymentService? paymentService;

  const CheckOutScreen({
    super.key,
    required this.selectedCartItems,
    this.cartId,
    this.orderService,
    this.paymentService,
  });

  @override
  State<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderInstructionController = TextEditingController();
  final _voucherController = TextEditingController();

  late final OrderService _orderService;
  late final PaymentService _paymentService;

  int? _selectedPaymentMethodId;
  int? _selectedDeliveryMethodId;
  int? _preferredDeliveryMethodId;

  String? _selectedDeliveryMethodDescription;
  String? _selectedDeliveryMethodInfo;

  bool _isLoading = false;
  bool _isLoadingProfile = true;
  bool _isLoadingDeliveryMethods = true;
  bool _isCheckingZoneCoverage = false;
  bool _isLoadingPaymentMethods = true;
  bool _isLoadingCalculation = true;
  bool _categoriesReady = false;
  bool _isLoadingCategories = true;
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
  int _coverageRequestId = 0;

  bool _coverageBlocksCheckout = false;
  String? _coverageMessage;

  String? _appliedVoucherCode;
  String? _voucherSuccessMessage;
  String? _voucherErrorMessage;

  // Address selection.
  List<AddressModel> _addresses = [];
  AddressModel? _selectedAddress;

  // Delivery methods from API and zone-eligible subset.
  List<Map<String, dynamic>> _allDeliveryMethods = [];
  List<Map<String, dynamic>> _deliveryMethods = [];

  // Payment methods from API.
  List<Map<String, dynamic>> _paymentMethods = [];

  bool get _hasGamefowlItems => widget.selectedCartItems.any(
        (item) => isGamefowlItem(
          item,
          categories: context.read<CategoryProvider?>()?.categories ?? const [],
        ),
      );

  bool get _isDirectGamefowlOrder => widget.selectedCartItems.any(
        (item) => item['is_direct_gamefowl_order'] == true,
      );

  @override
  void initState() {
    super.initState();

    _orderService = widget.orderService ?? OrderService();
    _paymentService = widget.paymentService ?? PaymentService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCategoriesForCheckout();
      _loadUserProfile();
      _loadDeliveryMethods();
      _loadPaymentMethods();
    });
  }

  Future<void> _loadCategoriesForCheckout() async {
    if (!_isLoadingCategories && mounted) {
      setState(() => _isLoadingCategories = true);
    }
    final provider = context.read<CategoryProvider?>();
    if (provider == null) {
      if (mounted) {
        setState(() {
          _categoriesReady = true;
          _isLoadingCategories = false;
        });
        await _maybeRecalculateOrder();
      }
      return;
    }
    if (provider.categories.isEmpty) await provider.fetchCategories();
    if (!mounted) return;
    setState(() {
      _categoriesReady = provider.categories.isNotEmpty;
      _isLoadingCategories = false;
      if (!_categoriesReady) _isLoadingCalculation = false;
    });
    if (_categoriesReady) await _maybeRecalculateOrder();
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

  int? _parseId(dynamic value) {
    if (value is int && value > 0) return value;

    if (value is num && value > 0 && value == value.toInt()) {
      return value.toInt();
    }

    final parsed = int.tryParse(value?.toString() ?? '');

    if (parsed != null && parsed > 0) {
      return parsed;
    }

    return null;
  }

  /// Resolve the parent cart ID only from fields that explicitly represent
  /// a cart. Never treat a product ID or cart-row ID as the parent cart ID.
  int? _resolveCheckoutCartId() {
    final explicitId = _parseId(widget.cartId);
    if (explicitId != null) return explicitId;

    for (final cartItem in widget.selectedCartItems) {
      final directId = _parseId(
        cartItem['cart_id'] ?? cartItem['cartId'],
      );
      if (directId != null) return directId;

      final nestedCart = cartItem['cart'];
      if (nestedCart is Map) {
        final nestedId = _parseId(
          nestedCart['id'] ?? nestedCart['cart_id'] ?? nestedCart['cartId'],
        );
        if (nestedId != null) return nestedId;
      }
    }

    return null;
  }

  int _parseQuantity(dynamic value) {
    if (value is int && value > 0) return value;

    if (value is num && value > 0) {
      return value.toInt();
    }

    final parsed = int.tryParse(value?.toString() ?? '');

    return parsed != null && parsed > 0 ? parsed : 1;
  }

  /// Builds the payload used for both fee calculation and order creation.
  ///
  /// Normal cart items include their real cart-row ID.
  List<Map<String, dynamic>> _buildOrderItemsPayload() {
    return widget.selectedCartItems.map((cartItem) {
      final isDirectGamefowl = cartItem['is_direct_gamefowl_order'] == true;
      final rawRequest = cartItem['gamefowl_request'];
      final gamefowlRequest = rawRequest is Map
          ? Map<String, dynamic>.from(rawRequest)
          : <String, dynamic>{};
      final rawProductData = gamefowlRequest['product_data'];
      final productData = rawProductData is Map
          ? Map<String, dynamic>.from(rawProductData)
          : <String, dynamic>{};
      final rawItem = cartItem['item'];
      final nestedItem = rawItem is Map
          ? Map<String, dynamic>.from(rawItem)
          : <String, dynamic>{};
      final rawProduct = cartItem['product'];
      final nestedProduct = rawProduct is Map
          ? Map<String, dynamic>.from(rawProduct)
          : <String, dynamic>{};
      final productDataItem = productData['item'] is Map
          ? Map<String, dynamic>.from(productData['item'] as Map)
          : <String, dynamic>{};
      final productDataProduct = productData['product'] is Map
          ? Map<String, dynamic>.from(productData['product'] as Map)
          : <String, dynamic>{};

      int? firstValidId(Iterable<dynamic> values) {
        for (final value in values) {
          final parsed = _parseId(value);
          if (parsed != null) return parsed;
        }
        return null;
      }

      // Never use cartItem['id'] as the item ID: on a cart line that value
      // can be the cart-row ID. Resolve the catalog/item ID from explicit
      // item fields or the original Gamefowl product payload instead.
      final itemId = firstValidId(<dynamic>[
        cartItem['item_id'],
        cartItem['itemId'],
        cartItem['product_item_id'],
        cartItem['catalog_item_id'],
        nestedItem['item_id'],
        nestedItem['id'],
        nestedProduct['item_id'],
        nestedProduct['id'],
        gamefowlRequest['item_id'],
        gamefowlRequest['product_item_id'],
        productData['item_id'],
        productData['product_item_id'],
        productData['catalog_item_id'],
        productDataItem['item_id'],
        productDataItem['id'],
        productDataProduct['item_id'],
        productDataProduct['id'],
        productData['product_id'],
        productData['id'],
      ]);

      final shopId = firstValidId(<dynamic>[
        cartItem['shop_id'],
        cartItem['shopId'],
        gamefowlRequest['shop_id'],
        productData['shop_id'],
        productData['shopId'],
        productData['store_id'],
      ]);

      if (itemId == null) {
        throw StateError(
          'Missing valid item_id for checkout item. '
          'Available keys: ${cartItem.keys.toList()}',
        );
      }
      if (shopId == null) {
        throw StateError(
          'Missing valid shop_id for checkout item. '
          'Available keys: ${cartItem.keys.toList()}',
        );
      }

      final item = <String, dynamic>{
        'item_id': itemId,
        'shop_id': shopId,
        'quantity': _parseQuantity(cartItem['quantity']),
        'price_at_purchase': _getEffectivePrice(cartItem),
      };

      final cartItemId = _parseId(cartItem['id']);
      if (cartItemId != null) item['cart_id'] = cartItemId;

      debugPrint(
        'CHECKOUT ITEM PAYLOAD: item_id=$itemId, shop_id=$shopId, '
        'direct_gamefowl=$isDirectGamefowl, keys=${cartItem.keys.toList()}',
      );
      return item;
    }).toList();
  }

  Future<void> _loadUserProfile() async {
    try {
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

        _refreshDeliveryEligibility();
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');

      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });

        _refreshDeliveryEligibility();
      }
    }
  }

  Future<void> _loadDeliveryMethods() async {
    try {
      final result = await _orderService.fetchDeliveryMethods();

      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final methods = (result['data'] as List)
            .where((method) => method['status'] == true)
            .map((method) {
              final id = _parseId(method['id']);

              if (id == null) return null;

              return <String, dynamic>{
                'id': id,
                'description': method['description']?.toString() ?? '',
                'info': method['info']?.toString() ?? '',
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        setState(() {
          _allDeliveryMethods = List<Map<String, dynamic>>.from(methods);
          _isLoadingDeliveryMethods = false;
        });

        _refreshDeliveryEligibility();
      } else {
        setState(() {
          _allDeliveryMethods = [];
          _deliveryMethods = [];
          _isLoadingDeliveryMethods = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading delivery methods: $e');

      if (mounted) {
        setState(() {
          _allDeliveryMethods = [];
          _deliveryMethods = [];
          _isLoadingDeliveryMethods = false;
        });
      }
    }
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final result = await _paymentService.fetchPaymentMethods();

      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final methods = (result['data'] as List)
            .map((method) => <String, dynamic>{
                  'id': method['id'],
                  'name': method['name']?.toString() ?? '',
                })
            .where(
              (method) => method['name']?.toString().isNotEmpty == true,
            )
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
    } catch (e) {
      debugPrint('Error loading payment methods: $e');

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

  List<int> get _checkoutShopIds {
    final ids = <int>{};

    for (final item in widget.selectedCartItems) {
      final id = _parseId(item['shop_id']);

      if (id != null) {
        ids.add(id);
      }
    }

    return ids.toList(growable: false);
  }

  bool _isPickupFromStore(Map<String, dynamic> method) {
    return method['description']?.toString().trim().toLowerCase() ==
        'pickup from store';
  }

  Future<void> _refreshDeliveryEligibility() async {
    if (!mounted || _isLoadingProfile || _isLoadingDeliveryMethods) {
      return;
    }

    final requestId = ++_coverageRequestId;
    ++_calculationRequestId;

    final previousMethodId = _preferredDeliveryMethodId;
    final address = _selectedAddress;

    if (address == null) {
      setState(() {
        _deliveryMethods = [];
        _selectedDeliveryMethodId = null;
        _selectedDeliveryMethodDescription = null;
        _selectedDeliveryMethodInfo = null;
        _coverageMessage = null;
        _coverageBlocksCheckout = false;
        _isCheckingZoneCoverage = false;
        _isLoadingCalculation = false;
      });

      return;
    }

    if (!address.hasLocation) {
      setState(() {
        _deliveryMethods = [];
        _selectedDeliveryMethodId = null;
        _selectedDeliveryMethodDescription = null;
        _selectedDeliveryMethodInfo = null;

        _coverageMessage =
            'This address needs map coordinates before delivery coverage can be checked. Please update the address location.';

        _coverageBlocksCheckout = true;
        _isCheckingZoneCoverage = false;
        _isLoadingCalculation = false;
      });

      return;
    }

    setState(() {
      _deliveryMethods = [];
      _selectedDeliveryMethodId = null;
      _selectedDeliveryMethodDescription = null;
      _selectedDeliveryMethodInfo = null;
      _coverageMessage = null;
      _coverageBlocksCheckout = false;
      _isCheckingZoneCoverage = true;
      _isLoadingCalculation = false;
    });

    try {
      final result = await _orderService.checkZoneCoverage(
        latitude: address.latitude!,
        longitude: address.longitude!,
        shopIds: _checkoutShopIds,
      );

      if (!mounted || requestId != _coverageRequestId) return;

      final coverageSucceeded = result['success'] == true;

      final allInsideZone =
          coverageSucceeded && result['all_inside_zone'] == true;

      final eligibleMethods = allInsideZone
          ? List<Map<String, dynamic>>.from(_allDeliveryMethods)
          : _allDeliveryMethods.where(_isPickupFromStore).toList();

      Map<String, dynamic>? selectedMethod;

      for (final method in eligibleMethods) {
        if (method['id'] == previousMethodId) {
          selectedMethod = method;
          break;
        }
      }

      selectedMethod ??=
          eligibleMethods.isNotEmpty ? eligibleMethods.first : null;

      String? message;

      if (!allInsideZone) {
        message = coverageSucceeded
            ? 'This address is outside one or more shop delivery zones. Pickup from Store is the only available option.'
            : 'Delivery coverage could not be verified. Pickup from Store is the only available option.';

        if (eligibleMethods.isEmpty) {
          message = '$message Pickup from Store is currently unavailable.';
        }
      }

      setState(() {
        _deliveryMethods = eligibleMethods;

        _selectedDeliveryMethodId = selectedMethod?['id'] as int?;

        _preferredDeliveryMethodId = _selectedDeliveryMethodId;

        _selectedDeliveryMethodDescription =
            selectedMethod?['description']?.toString();

        _selectedDeliveryMethodInfo = selectedMethod?['info']?.toString();

        _coverageMessage = message;
        _coverageBlocksCheckout = eligibleMethods.isEmpty;
        _isCheckingZoneCoverage = false;
      });

      _maybeRecalculateOrder();
    } catch (e) {
      debugPrint('Error checking delivery coverage: $e');

      if (!mounted || requestId != _coverageRequestId) return;

      final pickupMethods =
          _allDeliveryMethods.where(_isPickupFromStore).toList();

      final selectedMethod =
          pickupMethods.isNotEmpty ? pickupMethods.first : null;

      setState(() {
        _deliveryMethods = pickupMethods;
        _selectedDeliveryMethodId = selectedMethod?['id'] as int?;
        _preferredDeliveryMethodId = _selectedDeliveryMethodId;

        _selectedDeliveryMethodDescription =
            selectedMethod?['description']?.toString();

        _selectedDeliveryMethodInfo = selectedMethod?['info']?.toString();

        _coverageMessage =
            'Delivery coverage could not be verified. Pickup from Store is the only available option.'
            '${pickupMethods.isEmpty ? ' Pickup from Store is currently unavailable.' : ''}';

        _coverageBlocksCheckout = pickupMethods.isEmpty;
        _isCheckingZoneCoverage = false;
      });

      _maybeRecalculateOrder();
    }
  }

  Future<void> _maybeRecalculateOrder() async {
    if (!_categoriesReady ||
        _selectedAddress == null ||
        _selectedDeliveryMethodId == null ||
        _isCheckingZoneCoverage ||
        _coverageBlocksCheckout) {
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
    if (!_categoriesReady) return;
    if (_hasGamefowlItems) {
      if (mounted) setState(() => _isLoadingCalculation = false);
      return;
    }
    final requestId = ++_calculationRequestId;

    try {
      final orderItems = _buildOrderItemsPayload();

      final result = await _orderService.calculateOrder(
        items: orderItems,
        shippingAddressId: _selectedAddress?.id,
        deliveryMethodId: _selectedDeliveryMethodId,
        voucherCode: _appliedVoucherCode,
      );

      if (!mounted || requestId != _calculationRequestId) return;

      if (result['success'] == true) {
        double numberValue(dynamic value) {
          if (value is num) return value.toDouble();
          return double.tryParse(value?.toString() ?? '') ?? 0.0;
        }

        int intValue(dynamic value) {
          if (value is int) return value;
          if (value is num) return value.toInt();
          return int.tryParse(value?.toString() ?? '') ?? 0;
        }

        final feeDiscount = numberValue(result['voucher_discount_amount']);

        setState(() {
          _subtotal = numberValue(result['subtotal']);

          _deliveryBaseFee = numberValue(result['delivery_base_fee']);

          _deliveryKmFee = numberValue(result['delivery_km_fee']);

          _deliveryDistanceKm = numberValue(result['delivery_distance_km']);

          _isReducedBase = result['is_reduced_base'] == true;

          _shippingFee = numberValue(result['shipping_fee']);

          _heavySurcharge = numberValue(result['heavy_surcharge']);

          _heavySurchargeUnits = intValue(result['heavy_surcharge_units']);

          _totalWeightKg = numberValue(result['total_weight_kg']);

          _multiStoreFee = numberValue(result['multi_store_fee']);

          _movPenaltyFee = numberValue(result['mov_penalty_fee']);

          _totalFees = numberValue(result['total_fees']);

          _total = numberValue(result['total_amount']);

          _storeCount = intValue(result['store_count']);

          _isPickup = result['is_pickup'] == true;

          // The calculation API's total_amount already reflects
          // the voucher discount when a voucher is applied.
          _voucherDiscount = feeDiscount;
          _voucherDiscountIncludedInTotal = true;
          _isLoadingCalculation = false;
        });
      } else {
        debugPrint(
          'Error calculating order: ${result['message']}',
        );

        setState(() {
          _isLoadingCalculation = false;
        });

        SnackbarHelper.showError(
          context,
          result['message']?.toString() ?? 'Failed to calculate order fees',
        );
      }
    } catch (e) {
      debugPrint('Error loading order calculation: $e');

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

  /// Groups selected items by shop ID.
  List<Map<String, dynamic>> get _itemsGroupedByShop {
    final map = <String, List<Map<String, dynamic>>>{};

    for (final item in widget.selectedCartItems) {
      final shopId = item['shop_id']?.toString() ?? 'unknown';

      map.putIfAbsent(shopId, () => []).add(item);
    }

    return map.entries.map((entry) {
      final items = entry.value;

      final shopName = items.isNotEmpty && items.first['shop_name'] != null
          ? items.first['shop_name'].toString()
          : 'Shop ${entry.key}';

      return {
        'shop_id': entry.key,
        'shop_name': shopName,
        'items': items,
      };
    }).toList();
  }

  Future<void> _placeOrder() async {
    if (_isLoading) return;

    if (!_categoriesReady) {
      SnackbarHelper.showError(
          context, 'Item categories could not be verified. Please retry.');
      return;
    }

    if (_hasGamefowlItems) {
      SnackbarHelper.showError(
          context, 'Gamefowl is view only and cannot be checked out.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (widget.selectedCartItems.isEmpty) {
      SnackbarHelper.showError(
        context,
        'There are no items to checkout.',
      );
      return;
    }

    if (_isCheckingZoneCoverage) {
      SnackbarHelper.showInfo(
        context,
        'Please wait while delivery coverage is checked.',
      );
      return;
    }

    if (_selectedAddress == null) {
      SnackbarHelper.showError(
        context,
        'Please select a shipping address.',
      );
      return;
    }

    if (!_selectedAddress!.hasLocation) {
      SnackbarHelper.showError(
        context,
        'Please update your shipping address with a map location.',
      );
      return;
    }

    if (_coverageBlocksCheckout) {
      SnackbarHelper.showError(
        context,
        _coverageMessage ?? 'No eligible delivery method is available.',
      );
      return;
    }

    if (_selectedDeliveryMethodId == null) {
      SnackbarHelper.showError(
        context,
        'Please select a delivery method.',
      );
      return;
    }

    if (_isLoadingCalculation) {
      SnackbarHelper.showInfo(
        context,
        'Please wait while the order total is calculated.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    SnackbarHelper.showLoading(
      context,
      'Placing your order...',
    );

    try {
      final orderItems = _buildOrderItemsPayload();
      final checkoutCartId = _resolveCheckoutCartId();

      debugPrint('CHECKOUT CART ID: $checkoutCartId');
      debugPrint('CHECKOUT ORDER ITEMS: $orderItems');

      // Normal cart orders require a real parent cart ID. A direct Gamefowl
      // order may omit it; the Order API must support that request type.
      if (checkoutCartId == null && !_isDirectGamefowlOrder) {
        SnackbarHelper.hide(context);
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          SnackbarHelper.showError(
            context,
            'Cart ID is missing. Return to your cart and try again. '
            'The cart screen must pass the actual cart ID to checkout.',
          );
        }
        return;
      }

      final result = await _orderService.createOrder(
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

      if (!mounted) return;

      SnackbarHelper.hide(context);

      if (result['success'] != true) {
        setState(() {
          _isLoading = false;
        });

        SnackbarHelper.showError(
          context,
          result['message']?.toString() ?? 'Failed to place order.',
        );
        return;
      }

      // Read the order ID from common response structures.
      final responseData = result['data'];
      final nestedOrder = responseData is Map ? responseData['order'] : null;

      final rawOrderId = result['order_id'] ??
          result['id'] ??
          (responseData is Map
              ? responseData['order_id'] ?? responseData['id']
              : null) ??
          (nestedOrder is Map
              ? nestedOrder['order_id'] ?? nestedOrder['id']
              : null);

      final orderId = rawOrderId?.toString().trim();

      if (orderId == null || orderId.isEmpty) {
        setState(() {
          _isLoading = false;
        });

        SnackbarHelper.showError(
          context,
          'The order may have been created, but the server did not return an order ID. Please check your orders before trying again.',
        );
        return;
      }

      // Use checkout_url from the create-order response if provided.
      String? checkoutUrl;

      final rawCheckoutUrl = result['checkout_url'] ??
          (responseData is Map ? responseData['checkout_url'] : null) ??
          (nestedOrder is Map ? nestedOrder['checkout_url'] : null);

      if (rawCheckoutUrl != null &&
          rawCheckoutUrl.toString().trim().isNotEmpty) {
        checkoutUrl = rawCheckoutUrl.toString().trim();
      } else {
        // Otherwise, request a checkout URL using the created order ID.
        SnackbarHelper.showLoading(
          context,
          'Preparing secure payment...',
        );

        final paymentResponse = await _paymentService.initiateCheckout(
          orderId: orderId,
        );

        if (!mounted) return;

        SnackbarHelper.hide(context);

        if (paymentResponse['success'] == true) {
          final url = paymentResponse['checkout_url'];

          if (url != null && url.toString().trim().isNotEmpty) {
            checkoutUrl = url.toString().trim();
          }
        }

        if (checkoutUrl == null) {
          setState(() {
            _isLoading = false;
          });

          SnackbarHelper.showError(
            context,
            paymentResponse['message']?.toString() ??
                'Your order was created, but payment could not be started. Check your orders before retrying to avoid creating a duplicate order.',
          );
          return;
        }
      }

      final parsedUrl = Uri.tryParse(checkoutUrl);

      if (parsedUrl == null ||
          (parsedUrl.scheme != 'https' && parsedUrl.scheme != 'http') ||
          parsedUrl.host.isEmpty) {
        setState(() {
          _isLoading = false;
        });

        SnackbarHelper.showError(
          context,
          'The payment checkout URL returned by the server is invalid.',
        );
        return;
      }

      // Open the payment page and wait for its result.
      final paymentResult = await Navigator.push<PaymentWebViewResult>(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebViewScreen(
            checkoutUrl: checkoutUrl!,
            orderId: orderId,
          ),
        ),
      );

      if (!mounted) return;

      final paymentMessage = paymentResult?.response?['message']?.toString();

      switch (paymentResult?.result) {
        case PaymentResult.success:
          SnackbarHelper.showSuccess(
            context,
            paymentMessage ?? 'Payment completed successfully!',
            duration: const Duration(seconds: 3),
          );

          await Future.delayed(
            const Duration(seconds: 1),
          );

          if (!mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerDashboardScreen(),
            ),
            (route) => false,
          );
          return;

        case PaymentResult.failed:
          setState(() {
            _isLoading = false;
          });

          SnackbarHelper.showError(
            context,
            paymentMessage ??
                'Payment failed. Your order may still be pending payment.',
          );
          return;

        case PaymentResult.cancelled:
          setState(() {
            _isLoading = false;
          });

          SnackbarHelper.showWarning(
            context,
            paymentMessage ??
                'Payment was cancelled. Your order may still be pending payment.',
          );
          return;

        case null:
          // The payment screen closed without returning a result.
          setState(() {
            _isLoading = false;
          });

          SnackbarHelper.showInfo(
            context,
            'Your order was created. Please check its payment status before retrying.',
          );
          return;
      }
    } catch (e, stackTrace) {
      debugPrint('Error placing order or initiating payment: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      SnackbarHelper.hide(context);

      setState(() {
        _isLoading = false;
      });

      SnackbarHelper.showError(
        context,
        'Unable to complete checkout: ${e.toString()}',
      );
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
        iconTheme: IconThemeData(
          color: Colors.grey[700],
        ),
      ),
      body: _isLoadingProfile
          ? _buildLoadingState()
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOrderItemsSection(),
                    _buildShippingAddressSection(),
                    _buildDeliveryMethodSection(),

                    // Payment method UI remains hidden per the
                    // existing product requirement.
                    // _buildPaymentMethodSection(),

                    _buildOrderInstructionsSection(),
                    _buildVoucherSection(),
                    _buildOrderSummarySection(),
                    _buildPlaceOrderButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return const GenericListSkeleton(
      count: 4,
      itemHeight: 120,
    );
  }

  Widget _buildOrderItemsSection() {
    final groups = _itemsGroupedByShop;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Order Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ),
            ],
          ),
          if (_hasGamefowlItems) ...[
            const SizedBox(height: 6),
            const Text(
              'Gamefowl is view only and cannot be checked out.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
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

                return _buildOrderItem(
                  entry.value,
                  isLastOverall,
                );
              }),
              if (!isLastGroup) const SizedBox(height: 12),
            ];
          }),
        ],
      ),
    );
  }

  Widget _buildShopHeader(String shopName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.store_outlined,
            color: AppColors.brandPrimary,
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              shopName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(
    Map<String, dynamic> item,
    bool isLast,
  ) {
    final pricing = CartItemPricing.fromCartMap(item);
    final effectivePrice = pricing.effectivePrice;
    final quantity = _parseQuantity(item['quantity']);

    final itemTotal = effectivePrice * quantity;

    // Supports different image keys used by cart and product details.
    final imageUrl = resolveItemImageUrl(
      item['item_images'] ??
          item['image_url'] ??
          item['image'] ??
          item['product_image'] ??
          item['item_image'],
    );

    final gamefowlRequest = item['gamefowl_request'];

    return Container(
      padding: EdgeInsets.only(
        bottom: isLast ? 0 : 16,
      ),
      margin: EdgeInsets.only(
        bottom: isLast ? 0 : 16,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.brandPrimary.withOpacity(0.2),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.shopping_bag,
                          color: AppColors.brandPrimary,
                          size: 24,
                        ),
                      )
                    : Icon(
                        Icons.shopping_bag,
                        color: AppColors.brandPrimary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['item_name']?.toString() ??
                          item['product_name']?.toString() ??
                          item['name']?.toString() ??
                          'Unknown Item',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    CartItemPriceDisplay(
                      pricing: pricing,
                      primaryFontSize: 14,
                      strikethroughFontSize: 12,
                      compact: true,
                    ),
                    const SizedBox(height: 2),
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
              const SizedBox(width: 8),
              Text(
                '₱${itemTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),

          // Show the gamefowl request details on checkout.
          if (gamefowlRequest is Map) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gamefowl Request Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildGamefowlDetail(
                    'Chosen Gamefowl',
                    gamefowlRequest['gamefowl_name'],
                  ),
                  _buildGamefowlDetail(
                    'Wingband No.',
                    gamefowlRequest['wingband_no'],
                  ),
                  _buildGamefowlDetail(
                    'Feather Color',
                    gamefowlRequest['feather_color'],
                  ),
                  _buildGamefowlDetail(
                    'Feet Color',
                    gamefowlRequest['feet_color'],
                  ),
                  if (gamefowlRequest['media_name'] != null &&
                      gamefowlRequest['media_name'].toString().isNotEmpty)
                    _buildGamefowlDetail(
                      'Selected File',
                      gamefowlRequest['media_name'],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGamefowlDetail(
    String label,
    dynamic value,
  ) {
    final displayValue = value?.toString().trim() ?? '';

    if (displayValue.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryMethodSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          if (_coverageMessage != null &&
              !_isLoadingDeliveryMethods &&
              !_isCheckingZoneCoverage) ...[
            _buildCoverageMessage(),
            if (_deliveryMethods.isNotEmpty) const SizedBox(height: 12),
          ],
          if (_isLoadingDeliveryMethods || _isCheckingZoneCoverage)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.brandPrimary,
                    ),
                  ),
                ),
              ),
            )
          else if (_deliveryMethods.isEmpty && _coverageMessage == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accentAmber.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 20,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
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
          else if (_deliveryMethods.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[300]!,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  key: const ValueKey(
                    'checkout-delivery-method-dropdown',
                  ),
                  value: _selectedDeliveryMethodId,
                  isExpanded: true,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Select delivery method',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                  ),
                  items: _deliveryMethods.map((method) {
                    final description = method['description'] as String;

                    return DropdownMenuItem<int>(
                      value: method['id'] as int,
                      child: Row(
                        children: [
                          Icon(
                            _getDeliveryMethodIcon(description),
                            color: AppColors.brandPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              description,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue == null) return;

                    setState(() {
                      _selectedDeliveryMethodId = newValue;
                      _preferredDeliveryMethodId = newValue;

                      final selectedMethod = _deliveryMethods.firstWhere(
                        (method) => method['id'] == newValue,
                      );

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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.brandPrimary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 8),
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

  Widget _buildCoverageMessage() {
    return Container(
      key: const ValueKey('checkout-zone-coverage-message'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accentAmber.withOpacity(0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_outlined,
            size: 20,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _coverageMessage ?? '',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.accentAmberDark,
              ),
            ),
          ),
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
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
              TextButton.icon(
                onPressed: _navigateToAddAddress,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _addresses.isEmpty ? _buildNoAddressState() : _buildAddressDropdown(),
        ],
      ),
    );
  }

  Widget _buildNoAddressState() {
    return GestureDetector(
      onTap: _navigateToAddAddress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.brandPrimary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.brandPrimary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_location_alt_outlined,
                color: AppColors.brandPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Shipping Address',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap to add your delivery location',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.brandPrimary,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              borderRadius: BorderRadius.circular(8),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey[600],
              ),
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

                _refreshDeliveryEligibility();
              },
              selectedItemBuilder: (BuildContext context) {
                return _addresses.map((address) {
                  return _buildSelectedAddressDisplay(address);
                }).toList();
              },
            ),
          ),
        ),
        if (_selectedAddress != null) ...[
          const SizedBox(height: 12),
          _buildSelectedAddressCard(),
        ],
      ],
    );
  }

  Widget _buildAddressDropdownItem(AddressModel address) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getLabelIcon(address.label),
              color: AppColors.brandPrimary,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
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
                const SizedBox(height: 2),
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
          color: AppColors.brandPrimary,
          size: 18,
        ),
        const SizedBox(width: 8),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.brandPrimary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
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
                Icon(
                  Icons.phone_outlined,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
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
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
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

    if (result != null && mounted) {
      final addressProvider = context.read<AddressProvider>();

      await addressProvider.fetchAddresses();

      if (!mounted) return;

      setState(() {
        _addresses = addressProvider.addresses;

        _selectedAddress = addressProvider.defaultAddress ??
            (_addresses.isNotEmpty ? _addresses.first : null);
      });

      _refreshDeliveryEligibility();
    }
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          if (_isLoadingPaymentMethods)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: AppColors.brandPrimary,
                ),
              ),
            )
          else if (_paymentMethods.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No payment methods available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            )
          else
            ..._paymentMethods.map(_buildPaymentMethodOption),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOption(
    Map<String, dynamic> method,
  ) {
    final methodId = _parseId(method['id']);
    final methodName = method['name']?.toString() ?? '';
    final isSelected = _selectedPaymentMethodId == methodId;

    if (methodId == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPaymentMethodId = methodId;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brandPrimary.withOpacity(0.1)
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.brandPrimary : Colors.grey[300]!,
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
                activeColor: AppColors.brandPrimary,
              ),
              const SizedBox(width: 8),
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
    if (_selectedDeliveryMethodDescription == null) {
      return false;
    }

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

    final preVoucherTotal =
        _voucherDiscountIncludedInTotal && _voucherDiscount > 0
            ? _total + _voucherDiscount
            : _total;

    setState(() {
      _isValidatingVoucher = true;
      _voucherErrorMessage = null;
      _voucherSuccessMessage = null;
    });

    try {
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

        final appliedCode = (result['voucher_code']?.toString() ?? code).trim();

        final name = result['name']?.toString();

        setState(() {
          _appliedVoucherCode = appliedCode;
          _voucherDiscount = discount;

          final validatedTotal = (result['total_amount'] as num?)?.toDouble();

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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isValidatingVoucher = false;
        _voucherSuccessMessage = null;
        _voucherErrorMessage = 'Unable to validate voucher.';
      });

      debugPrint('Error validating voucher: $e');
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
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 12),
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
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: AppColors.brandPrimary,
                        width: 2,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                      ),
                    ),
                    filled: true,
                    fillColor: hasApplied
                        ? AppColors.brandPrimary.withOpacity(0.05)
                        : AppColors.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(
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
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: canApply ? _applyVoucher : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isValidatingVoucher
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          hasApplied ? 'Applied' : 'Apply',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_voucherSuccessMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _voucherSuccessMessage!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (_voucherErrorMessage != null) ...[
            const SizedBox(height: 8),
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.accentAmber.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          TextFormField(
            controller: _orderInstructionController,
            decoration: InputDecoration(
              hintText: _isContactlessDelivery
                  ? 'E.g., Leave at the front door, behind the gate...'
                  : 'Add any special instructions for delivery...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Colors.grey[300]!,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Colors.grey[300]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.brandPrimary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.error.withOpacity(0.6),
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.error.withOpacity(0.6),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          ..._itemsGroupedByShop.expand((group) {
            final shopName = group['shop_name'] as String;

            final items = group['items'] as List<Map<String, dynamic>>;

            return [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
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
                final quantity = _parseQuantity(item['quantity']);
                final itemTotal = effectivePrice * quantity;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
                      const SizedBox(width: 8),
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
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (_isLoadingCalculation)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.brandPrimary,
                    ),
                  ),
                ),
              ),
            )
          else if (_selectedAddress == null ||
              _selectedDeliveryMethodId == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
            _buildSummaryRow(
              'Subtotal',
              '₱${_subtotal.toStringAsFixed(2)}',
            ),
            ..._buildFeeBreakdownRows(),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 12),
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

    void addFeeRow(
      String label,
      double amount, {
      String? subtitle,
    }) {
      if (amount <= 0) return;

      rows.add(const SizedBox(height: 8));

      rows.add(
        _buildSummaryRow(
          label,
          '₱${amount.toStringAsFixed(2)}',
          subtitle: subtitle,
        ),
      );
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
        deliveryParts.add(
          '${_deliveryDistanceKm.toStringAsFixed(1)} km',
        );
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
      subtitle:
          _multiStoreFee > 0 && _storeCount > 1 ? '$_storeCount stores' : null,
    );

    addFeeRow(
      'Minimum Order Fee',
      _movPenaltyFee,
    );

    if (rows.isEmpty && _totalFees > 0) {
      rows.add(const SizedBox(height: 8));

      rows.add(
        _buildSummaryRow(
          'Fees',
          '₱${_totalFees.toStringAsFixed(2)}',
        ),
      );
    }

    if (_voucherDiscount > 0) {
      rows.add(const SizedBox(height: 8));

      rows.add(
        _buildSummaryRow(
          'Voucher discount',
          '-₱${_voucherDiscount.toStringAsFixed(2)}',
          subtitle: _appliedVoucherCode,
        ),
      );
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
                const SizedBox(height: 2),
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
          const SizedBox(width: 8),
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
            color: isTotal ? AppColors.brandPrimary : Colors.grey[900],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceOrderButton() {
    final isDisabled = _hasGamefowlItems ||
        _isLoading ||
        _isLoadingCalculation ||
        _isCheckingZoneCoverage ||
        _coverageBlocksCheckout ||
        _selectedDeliveryMethodId == null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        key: const ValueKey('checkout-place-order-button'),
        onPressed: _hasGamefowlItems
            ? null
            : !_categoriesReady && !_isLoadingCategories
                ? _loadCategoriesForCheckout
                : isDisabled || !_categoriesReady
                    ? null
                    : _placeOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: Colors.grey[400],
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
            : Text(
                _hasGamefowlItems
                    ? 'Gamefowl cannot be checked out'
                    : !_categoriesReady
                        ? _isLoadingCategories
                            ? 'Checking item categories...'
                            : 'Retry item check'
                        : _isCheckingZoneCoverage
                            ? 'Checking delivery coverage...'
                            : _isLoadingCalculation
                                ? 'Calculating...'
                                : 'Place Order - ₱${_displayTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
