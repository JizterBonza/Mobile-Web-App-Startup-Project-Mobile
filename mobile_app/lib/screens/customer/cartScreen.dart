import 'package:flutter/material.dart';

import '../../constants/constants.dart';

import '../../services/cart_services.dart';

import '../../services/api_service.dart';

import '../../utils/cart_item_pricing.dart';

import '../../utils/snackbar_helper.dart';

import 'customerDashboardScreen.dart';

import 'checkOutScreen.dart';

class CartScreen extends StatefulWidget {

  const CartScreen({super.key});

  @override

  State<CartScreen> createState() => _CartScreenState();

}

class _CartScreenState extends State<CartScreen> {

  List<Map<String, dynamic>> _cartItems = [];

  final Set<String> _selectedItems = {};

  bool _isLoading = true;

  String? _errorMessage;

  int _int(dynamic value, [int fallback = 0]) {

    if (value is int) return value;

    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? fallback;

  }

  int? _parseId(dynamic value) {

    if (value is Map) {

      return _parseId(

        value['id'] ?? value['cart_id'] ?? value['cartId'],

      );

    }

    final id = _int(value, -1);

    return id > 0 ? id : null;

  }

  /// Retrieves the parent cart ID only.

  /// Never treats a cart-line ID or product ID as the parent cart ID.

  int? _rawCartId(Map<String, dynamic> item) {

    final nestedCart = item['cart'];

    return _parseId(

      item['cart_id'] ??
          item['cartId'] ??
          item['parent_cart_id'] ??
          item['parentCartId'] ??
          (nestedCart is Map
              ? nestedCart['id'] ??
                  nestedCart['cart_id'] ??
                  nestedCart['cartId'] ??
                  nestedCart['parent_cart_id'] ??
                  nestedCart['parentCartId']
              : null),

    );

  }

  int? _resolveParentCartId(List<Map<String, dynamic>> items) {

    if (items.isEmpty) return null;

    final firstId = _rawCartId(items.first);

    if (firstId == null) return null;

    // All selected items must belong to the same parent cart.

    for (final item in items) {

      if (_rawCartId(item) != firstId) {

        debugPrint(

          'CHECKOUT ERROR: Items do not share the same parent cart ID.',

        );

        return null;

      }

    }

    return firstId;

  }

  bool _validQty(Map<String, dynamic> item) {

    final qty = _int(item['quantity']);

    final stock = _int(item['item_quantity']);

    return qty > 0 && stock > 0 && qty <= stock;

  }

  bool _outOfStock(Map<String, dynamic> item) {

    return _int(item['item_quantity']) <= 0;

  }

  double _price(Map<String, dynamic> item) {

    return CartItemPricing.fromCartMap(item).effectivePrice;

  }

  String _key(Map<String, dynamic> item) {

    return item['id']?.toString() ?? '';

  }

  Map<String, List<Map<String, dynamic>>> _groupItems() {

    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in _cartItems) {

      final shopId = item['shop_id']?.toString() ?? 'unknown';

      grouped.putIfAbsent(shopId, () => []).add(item);

    }

    return grouped;

  }

  String _shopName(

    String shopId,

    List<Map<String, dynamic>> items,

  ) {

    final name = items.isNotEmpty ? items.first['shop_name'] : null;

    if (name != null && name.toString().trim().isNotEmpty) {

      return name.toString();

    }

    return 'Shop $shopId';

  }

  List<Map<String, dynamic>> _selectedForShop(

    List<Map<String, dynamic>> items,

  ) {

    return items

        .where(

          (item) =>

              _selectedItems.contains(_key(item)) && _validQty(item),

        )

        .toList();

  }

  double _subtotal(List<Map<String, dynamic>> items) {

    return _selectedForShop(items).fold<double>(

      0,

      (sum, item) => sum + _price(item) * _int(item['quantity']),

    );

  }

  Future<void> _loadCartItems() async {

    if (mounted) {

      setState(() {

        _isLoading = true;

        _errorMessage = null;

      });

    }

    try {

      final userId = await ApiService.getUserId();

      if (userId == null || userId.isEmpty) {

        throw Exception('User not logged in.');

      }

      final items = await CartService().fetchCartItemsFromAPI(userId);

      if (!mounted) return;

      // DEBUG: inspect the actual cart API data in Android Studio Logcat.

      debugPrint('========== CART DEBUG ==========');

      debugPrint('USER ID: $userId');

      debugPrint('CART ITEM COUNT: ${items.length}');

      for (final item in items) {

        debugPrint('FULL CART ITEM: $item');

        debugPrint('CART LINE ID: ${item['id']}');

        debugPrint('PARENT CART ID: ${item['cart_id']}');

        debugPrint('CART ID CAMEL CASE: ${item['cartId']}');

        debugPrint('NESTED CART: ${item['cart']}');

        debugPrint('RESOLVED PARENT ID: ${_rawCartId(item)}');

      }

      debugPrint('================================');

      setState(() {

        _cartItems = items;

        final validIds = items

            .where(_validQty)

            .map(_key)

            .toSet();

        _selectedItems.removeWhere(

          (id) => !validIds.contains(id),

        );

        _isLoading = false;

      });

    } catch (e, stackTrace) {

      debugPrint('CART LOAD ERROR: $e');

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {

        _isLoading = false;

        _errorMessage = 'Failed to load cart items: $e';

      });

    }

  }

  void _openCheckout(List<Map<String, dynamic>> items) {

    if (items.isEmpty) {

      SnackbarHelper.showError(

        context,

        'Please select valid items to checkout.',

      );

      return;

    }

    final cartId = _resolveParentCartId(items);

    debugPrint('========== CHECKOUT DEBUG ==========');

    debugPrint('SELECTED ITEMS: ${items.length}');

    debugPrint('RESOLVED PARENT CART ID: $cartId');

    for (final item in items) {

      debugPrint(

        'Selected item: lineId=${item['id']}, '

        'cartId=${_rawCartId(item)}, '

        'productId=${item['item_id']}',

      );

    }

    debugPrint('====================================');

    if (cartId == null) {

      SnackbarHelper.showError(

        context,

        'Unable to identify the parent cart ID. '

        'Please check the CART DEBUG logs in Android Studio.',

      );

      return;

    }

    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => CheckOutScreen(

          selectedCartItems: items,

          cartId: cartId,

        ),

      ),

    );

  }

  void _toggle(String id) {

    setState(() {

      if (_selectedItems.contains(id)) {

        _selectedItems.remove(id);

      } else {

        _selectedItems.add(id);

      }

    });

  }

  Future<void> _removeItem(Map<String, dynamic> item) async {

    final id = _key(item);

    if (id.isEmpty) {

      SnackbarHelper.showError(

        context,

        'Cart item ID is missing.',

      );

      return;

    }

    SnackbarHelper.showLoading(context, 'Removing item...');

    try {

      final result = await CartService().removeCartItem(id);

      if (!mounted) return;

      SnackbarHelper.hide(context);

      if (result['success'] == true) {

        setState(() {

          _cartItems.removeWhere((i) => _key(i) == id);

          _selectedItems.remove(id);

        });

        SnackbarHelper.showSuccess(

          context,

          result['message'] ?? 'Item removed from cart.',

        );

      } else {

        SnackbarHelper.showError(

          context,

          result['message'] ?? 'Failed to remove item.',

        );

      }

    } catch (e) {

      if (!mounted) return;

      SnackbarHelper.hide(context);

      SnackbarHelper.showError(

        context,

        'Error removing item: $e',

      );

    }

  }

  Future<void> _clearCart() async {

    if (_cartItems.isEmpty) return;

    final confirmed = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Clear Cart'),

        content: Text(

          'Remove all ${_cartItems.length} item(s)?',

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: const Text('Cancel'),

          ),

          ElevatedButton(

            onPressed: () => Navigator.pop(ctx, true),

            child: const Text('Clear All'),

          ),

        ],

      ),

    );

    if (confirmed != true || !mounted) return;

    SnackbarHelper.showLoading(

      context,

      'Removing all items...',

    );

    try {

      final result = await CartService().clearAllCartItems(

        _cartItems.map(_key).toList(),

      );

      if (!mounted) return;

      SnackbarHelper.hide(context);

      if (result['success'] == true) {

        setState(() {

          _cartItems.clear();

          _selectedItems.clear();

        });

        SnackbarHelper.showSuccess(

          context,

          result['message'] ?? 'All items removed from cart.',

        );

      } else {

        SnackbarHelper.showError(

          context,

          result['message'] ?? 'Failed to clear cart.',

        );

      }

    } catch (e) {

      if (!mounted) return;

      SnackbarHelper.hide(context);

      SnackbarHelper.showError(

        context,

        'Error clearing cart: $e',

      );

    }

  }

  void _changeQty(Map<String, dynamic> item, int delta) {

    final index = _cartItems.indexWhere(

      (i) => _key(i) == _key(item),

    );

    if (index < 0) return;

    final qty = _int(item['quantity']) + delta;

    if (qty <= 0) {

      _removeItem(item);

      return;

    }

    setState(() {

      _cartItems[index]['quantity'] = qty;

      if (!_validQty(_cartItems[index])) {

        _selectedItems.remove(_key(item));

      }

    });

  }

  @override

  void initState() {

    super.initState();

    _loadCartItems();

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.surfaceLight,

      appBar: AppBar(

        title: const Text('Shopping Cart'),

        backgroundColor: Colors.white,

        foregroundColor: Colors.black87,

        elevation: 0,

        actions: [

          TextButton(

            onPressed: _cartItems.isEmpty ? null : _clearCart,

            child: const Text('Clear All'),

          ),

        ],

      ),

      body: _isLoading

          ? const Center(

              child: CircularProgressIndicator(),

            )

          : _errorMessage != null

              ? Center(

                  child: Padding(

                    padding: const EdgeInsets.all(24),

                    child: Column(

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        Text(

                          _errorMessage!,

                          textAlign: TextAlign.center,

                        ),

                        const SizedBox(height: 12),

                        ElevatedButton(

                          onPressed: _loadCartItems,

                          child: const Text('Retry'),

                        ),

                      ],

                    ),

                  ),

                )

              : _cartItems.isEmpty

                  ? Center(

                      child: Column(

                        mainAxisSize: MainAxisSize.min,

                        children: [

                          const Icon(

                            Icons.shopping_cart_outlined,

                            size: 64,

                          ),

                          const SizedBox(height: 12),

                          const Text('Your cart is empty'),

                          const SizedBox(height: 12),

                          ElevatedButton(

                            onPressed: () {

                              Navigator.pushReplacement(

                                context,

                                MaterialPageRoute(

                                  builder: (_) =>

                                      CustomerDashboardScreen(),

                                ),

                              );

                            },

                            child: const Text('Continue Shopping'),

                          ),

                        ],

                      ),

                    )

                  : ListView(

                      padding: const EdgeInsets.all(16),

                      children: [

                        Text(

                          '${_cartItems.length} '

                          '${_cartItems.length == 1 ? 'item' : 'items'}',

                        ),

                        const SizedBox(height: 12),

                        ..._groupItems().entries.map((entry) {

                          final shopId = entry.key;

                          final items = entry.value;

                          final name = _shopName(shopId, items);

                          final selected = _selectedForShop(items);

                          final subtotal = _subtotal(items);

                          return Card(

                            margin: const EdgeInsets.only(bottom: 18),

                            clipBehavior: Clip.antiAlias,

                            child: Column(

                              crossAxisAlignment:

                                  CrossAxisAlignment.stretch,

                              children: [

                                Container(

                                  color: AppColors.brandPrimary

                                      .withOpacity(.1),

                                  padding: const EdgeInsets.all(14),

                                  child: Row(

                                    children: [

                                      const Icon(Icons.store),

                                      const SizedBox(width: 8),

                                      Expanded(

                                        child: Text(

                                          name,

                                          style: const TextStyle(

                                            fontWeight: FontWeight.bold,

                                          ),

                                        ),

                                      ),

                                      Text('${items.length} item(s)'),

                                    ],

                                  ),

                                ),

                                ...items.map((item) {

                                  final id = _key(item);

                                  final valid = _validQty(item);

                                  final qty = _int(item['quantity']);

                                  final stock =

                                      _int(item['item_quantity']);

                                  return Padding(

                                    padding: const EdgeInsets.all(12),

                                    child: Row(

                                      crossAxisAlignment:

                                          CrossAxisAlignment.start,

                                      children: [

                                        Checkbox(

                                          value: valid &&

                                              _selectedItems.contains(id),

                                          onChanged: valid

                                              ? (_) => _toggle(id)

                                              : null,

                                        ),

                                        Container(

                                          width: 56,

                                          height: 56,

                                          decoration: BoxDecoration(

                                            color: AppColors.brandPrimary

                                                .withOpacity(.1),

                                            borderRadius:

                                                BorderRadius.circular(8),

                                          ),

                                          child: Icon(

                                            Icons.shopping_bag_outlined,

                                            color: AppColors.brandPrimary,

                                          ),

                                        ),

                                        const SizedBox(width: 10),

                                        Expanded(

                                          child: Column(

                                            crossAxisAlignment:

                                                CrossAxisAlignment.start,

                                            children: [

                                              Text(

                                                item['item_name']

                                                        ?.toString() ??

                                                    'Unknown Item',

                                                style: const TextStyle(

                                                  fontWeight:

                                                      FontWeight.w600,

                                                ),

                                              ),

                                              const SizedBox(height: 5),

                                              CartItemPriceDisplay(

                                                pricing:

                                                    CartItemPricing

                                                        .fromCartMap(item),

                                                primaryFontSize: 17,

                                                strikethroughFontSize: 13,

                                              ),

                                              if (!valid)

                                                Text(

                                                  'Invalid quantity '

                                                  '($stock available)',

                                                  style: TextStyle(

                                                    color: AppColors.error,

                                                    fontSize: 12,

                                                  ),

                                                ),

                                              Row(

                                                children: [

                                                  IconButton(

                                                    onPressed: qty <= 1 ||

                                                            _outOfStock(item)

                                                        ? null

                                                        : () => _changeQty(

                                                              item,

                                                              -1,

                                                            ),

                                                    icon: const Icon(

                                                      Icons.remove,

                                                      size: 18,

                                                    ),

                                                  ),

                                                  Text('$qty'),

                                                  IconButton(

                                                    onPressed: qty >= stock ||

                                                            _outOfStock(item)

                                                        ? null

                                                        : () => _changeQty(

                                                              item,

                                                              1,

                                                            ),

                                                    icon: const Icon(

                                                      Icons.add,

                                                      size: 18,

                                                    ),

                                                  ),

                                                  const Spacer(),

                                                  IconButton(

                                                    onPressed: () =>

                                                        _removeItem(item),

                                                    icon: Icon(

                                                      Icons.delete_outline,

                                                      color: AppColors.error,

                                                    ),

                                                  ),

                                                ],

                                              ),

                                            ],

                                          ),

                                        ),

                                      ],

                                    ),

                                  );

                                }),

                                Padding(

                                  padding: const EdgeInsets.fromLTRB(

                                    14,

                                    4,

                                    14,

                                    14,

                                  ),

                                  child: Column(

                                    children: [

                                      Row(

                                        mainAxisAlignment:

                                            MainAxisAlignment.spaceBetween,

                                        children: [

                                          const Text('Selected subtotal'),

                                          Text(

                                            '₱${subtotal.toStringAsFixed(2)}',

                                            style: const TextStyle(

                                              fontWeight: FontWeight.bold,

                                            ),

                                          ),

                                        ],

                                      ),

                                      const SizedBox(height: 10),

                                      SizedBox(

                                        width: double.infinity,

                                        child: ElevatedButton(

                                          onPressed: selected.isEmpty

                                              ? null

                                              : () => _openCheckout(

                                                    selected,

                                                  ),

                                          style: ElevatedButton.styleFrom(

                                            backgroundColor:

                                                AppColors.brandPrimary,

                                            foregroundColor: Colors.white,

                                          ),

                                          child: Text(

                                            selected.isEmpty

                                                ? 'Select items to checkout'

                                                : 'Checkout from $name '

                                                    '(${selected.length})',

                                          ),

                                        ),

                                      ),

                                    ],

                                  ),

                                ),

                              ],

                            ),

                          );

                        }),

                      ],

                    ),

    );

  }

}
