import 'package:flutter/material.dart';
import '../../constants/constants.dart';
import '../../services/cart_services.dart';
import '../../services/api_service.dart';
import '../../utils/cart_item_pricing.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import 'checkOutScreen.dart';
import 'customerDashboardScreen.dart';

class CartScreenV2 extends StatefulWidget {
  const CartScreenV2({super.key});

  @override
  State<CartScreenV2> createState() => _CartScreenV2State();
}

class _CartScreenV2State extends State<CartScreenV2> {
  List<ZoneData> _zones = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = await ApiService.getUserId();
      if (userId == null || userId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not logged in';
        });
        return;
      }

      final apiData = await CartService().fetchCartItemsForV2(userId);
      setState(() {
        _zones = _transformApiData(apiData);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load cart items: ${e.toString()}';
      });
    }
  }

  /// Transforms the flat API response into a Zone -> Shop -> Item hierarchy.
  List<ZoneData> _transformApiData(List<Map<String, dynamic>> apiData) {
    final Map<String, ZoneData> zoneMap = {};

    for (var cartItem in apiData) {
      final item = cartItem['item'] as Map<String, dynamic>? ?? {};
      final shop = item['shop'] as Map<String, dynamic>? ?? {};
      final zone = shop['zone'] as Map<String, dynamic>? ?? {};

      final zoneId = zone['id']?.toString() ?? 'unknown';
      final zoneName = zone['name']?.toString() ?? 'Unknown Zone';

      final shopId =
          shop['id']?.toString() ?? item['shop_id']?.toString() ?? 'unknown';
      final shopName = shop['shop_name']?.toString() ??
          item['shop_name']?.toString() ??
          'Unknown Shop';
      final shopAddress = shop['shop_address']?.toString();

      if (!zoneMap.containsKey(zoneId)) {
        zoneMap[zoneId] = ZoneData(id: zoneId, name: zoneName, shops: []);
      }

      final zoneData = zoneMap[zoneId]!;
      final shopIndex = zoneData.shops.indexWhere((s) => s.id == shopId);
      ShopData shopData;
      if (shopIndex == -1) {
        shopData = ShopData(
          id: shopId,
          name: shopName,
          address: shopAddress,
          items: [],
        );
        zoneData.shops.add(shopData);
      } else {
        shopData = zoneData.shops[shopIndex];
      }

      final priceSnapshot =
          CartItemPricing.parseDouble(cartItem['price_snapshot']);
      final itemPrice = CartItemPricing.parseDouble(item['item_price']);
      final stock = int.tryParse(item['item_quantity'].toString()) ?? 0;
      final quantity = cartItem['quantity'] is int
          ? cartItem['quantity'] as int
          : int.tryParse(cartItem['quantity'].toString()) ?? 1;

      double? discountedPrice;
      if (cartItem['discounted_price'] != null) {
        discountedPrice =
            CartItemPricing.parseDouble(cartItem['discounted_price']);
      }
      final discountDetails = cartItem['discount_details'];
      if (discountedPrice == null && discountDetails is Map) {
        final nested = discountDetails['discounted_price'];
        if (nested != null) {
          discountedPrice = CartItemPricing.parseDouble(nested);
        }
      }

      double? discountPercent;
      if (discountDetails is Map &&
          discountDetails['discount_percent'] != null) {
        discountPercent =
            CartItemPricing.parseDouble(discountDetails['discount_percent']);
      }

      shopData.items.add(ItemData(
        id: cartItem['id'].toString(),
        itemId: (item['id'] ?? cartItem['item_id']).toString(),
        name: item['item_name']?.toString() ?? 'Unknown Item',
        price: itemPrice,
        priceSnapshot: priceSnapshot,
        discountedPrice: discountedPrice,
        discountStatus: cartItem['discount_status']?.toString(),
        discountPercent: discountPercent,
        stock: stock,
        quantity: quantity,
      ));
    }

    return zoneMap.values.toList();
  }

  // ---------------------------------------------------------------------------
  // Selection logic
  // ---------------------------------------------------------------------------

  void _toggleZone(String zoneId) {
    setState(() {
      final zone = _zones.firstWhere((z) => z.id == zoneId);
      final newState = !zone.isSelected;
      zone.isSelected = newState;

      for (var shop in zone.shops) {
        shop.isSelected = newState;
        for (var item in shop.items) {
          item.isSelected = newState && item.isQuantityValid;
        }
      }
      _updateZoneSelection(zone);
    });
  }

  void _toggleShop(String zoneId, String shopId) {
    setState(() {
      final zone = _zones.firstWhere((z) => z.id == zoneId);
      final shop = zone.shops.firstWhere((s) => s.id == shopId);
      final newState = !shop.isSelected;
      shop.isSelected = newState;

      for (var item in shop.items) {
        item.isSelected = newState && item.isQuantityValid;
      }
      _updateZoneSelection(zone);
    });
  }

  void _toggleItem(String zoneId, String shopId, String itemId) {
    setState(() {
      final zone = _zones.firstWhere((z) => z.id == zoneId);
      final shop = zone.shops.firstWhere((s) => s.id == shopId);
      final item = shop.items.firstWhere((i) => i.id == itemId);

      if (!item.isQuantityValid) return;
      item.isSelected = !item.isSelected;

      _updateShopSelection(shop);
      _updateZoneSelection(zone);
    });
  }

  void _updateShopSelection(ShopData shop) {
    final validItems = shop.items.where((i) => i.isQuantityValid).toList();
    if (validItems.isEmpty) {
      shop.isSelected = false;
      shop.isIndeterminate = false;
      return;
    }
    final allSelected = validItems.every((i) => i.isSelected);
    final someSelected = validItems.any((i) => i.isSelected);
    shop.isSelected = allSelected;
    shop.isIndeterminate = someSelected && !allSelected;
  }

  void _updateZoneSelection(ZoneData zone) {
    for (var shop in zone.shops) {
      _updateShopSelection(shop);
    }
    final shopsWithValidItems =
        zone.shops.where((s) => s.items.any((i) => i.isQuantityValid)).toList();
    if (shopsWithValidItems.isEmpty) {
      zone.isSelected = false;
      zone.isIndeterminate = false;
      return;
    }
    final allSelected = shopsWithValidItems.every((s) => s.isSelected);
    final someSelected =
        shopsWithValidItems.any((s) => s.isSelected || s.isIndeterminate);
    zone.isSelected = allSelected;
    zone.isIndeterminate = someSelected && !allSelected;
  }

  // ---------------------------------------------------------------------------
  // Calculations
  // ---------------------------------------------------------------------------

  double _calculateZoneSubtotal(ZoneData zone) {
    double total = 0.0;
    for (var shop in zone.shops) {
      for (var item in shop.items) {
        if (item.isSelected && item.isQuantityValid) {
          total += item.effectivePrice * item.quantity;
        }
      }
    }
    return total;
  }

  int _getSelectedItemsCount(ZoneData zone) {
    int count = 0;
    for (var shop in zone.shops) {
      for (var item in shop.items) {
        if (item.isSelected && item.isQuantityValid) {
          count++;
        }
      }
    }
    return count;
  }

  int _getTotalItemsCount() {
    int count = 0;
    for (var zone in _zones) {
      for (var shop in zone.shops) {
        count += shop.items.length;
      }
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Cart operations
  // ---------------------------------------------------------------------------

  void _updateQuantity(
      String zoneId, String shopId, String itemId, int newQuantity) {
    if (newQuantity < 1) return;

    setState(() {
      final zone = _zones.firstWhere((z) => z.id == zoneId);
      final shop = zone.shops.firstWhere((s) => s.id == shopId);
      final item = shop.items.firstWhere((i) => i.id == itemId);
      item.quantity = newQuantity;

      if (!item.isQuantityValid && item.isSelected) {
        item.isSelected = false;
        _updateShopSelection(shop);
        _updateZoneSelection(zone);
      }
    });
  }

  Future<void> _removeItem(String zoneId, String shopId, String itemId) async {
    SnackbarHelper.showLoading(context, 'Removing item...');

    try {
      final result = await CartService().removeCartItem(itemId);
      if (!mounted) return;
      SnackbarHelper.hide(context);

      if (result['success'] == true) {
        setState(() {
          final zone = _zones.firstWhere((z) => z.id == zoneId);
          final shop = zone.shops.firstWhere((s) => s.id == shopId);
          shop.items.removeWhere((i) => i.id == itemId);

          if (shop.items.isEmpty) {
            zone.shops.removeWhere((s) => s.id == shopId);
          }
          if (zone.shops.isEmpty) {
            _zones.removeWhere((z) => z.id == zoneId);
          } else {
            _updateZoneSelection(zone);
          }
        });

        SnackbarHelper.showSuccess(
          context,
          result['message'] ?? 'Item removed from cart',
          duration: const Duration(seconds: 2),
        );
      } else {
        SnackbarHelper.showError(
          context,
          result['message'] ?? 'Failed to remove item',
        );
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.hide(context);
      SnackbarHelper.showError(context, 'Error removing item: ${e.toString()}');
    }
  }

  Future<void> _clearAllItems() async {
    final totalItems = _getTotalItemsCount();
    if (totalItems == 0) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content:
            Text('Are you sure you want to remove all $totalItems item(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child:
                const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldClear != true || !mounted) return;

    final allCartItemIds = <String>[];
    for (var zone in _zones) {
      for (var shop in zone.shops) {
        for (var item in shop.items) {
          allCartItemIds.add(item.id);
        }
      }
    }

    SnackbarHelper.showLoading(context, 'Removing all items...');

    try {
      final result = await CartService().clearAllCartItems(allCartItemIds);
      if (!mounted) return;
      SnackbarHelper.hide(context);

      if (result['success'] == true) {
        setState(() {
          _zones.clear();
        });
        SnackbarHelper.showSuccess(
          context,
          result['message'] ?? 'All items removed from cart',
          duration: const Duration(seconds: 2),
        );
      } else {
        SnackbarHelper.showError(
          context,
          result['message'] ?? 'Failed to clear cart',
        );
        _loadCartItems();
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.hide(context);
      SnackbarHelper.showError(context, 'Error clearing cart: ${e.toString()}');
    }
  }

  // ---------------------------------------------------------------------------
  // Checkout helpers
  // ---------------------------------------------------------------------------

  /// Converts selected valid items in a zone back to the flat map format
  /// that [CheckOutScreen] expects.
  List<Map<String, dynamic>> _getSelectedItemsForCheckout(ZoneData zone) {
    final List<Map<String, dynamic>> items = [];
    for (var shop in zone.shops) {
      for (var item in shop.items) {
        if (item.isSelected && item.isQuantityValid) {
          items.add({
            'id': int.tryParse(item.id) ?? item.id,
            'item_id': int.tryParse(item.itemId) ?? item.itemId,
            'shop_id': int.tryParse(shop.id) ?? shop.id,
            'shop_name': shop.name,
            'quantity': item.quantity,
            'price_snapshot': item.priceSnapshot.toStringAsFixed(2),
            'item_name': item.name,
            'item_price': item.price.toStringAsFixed(2),
            'item_quantity': item.stock.toString(),
            if (item.discountedPrice != null)
              'discounted_price': item.discountedPrice!.toStringAsFixed(2),
            if (item.discountStatus != null)
              'discount_status': item.discountStatus,
            if (item.discountPercent != null)
              'discount_details': {
                'discount_percent': item.discountPercent!.toStringAsFixed(2),
                if (item.discountedPrice != null)
                  'discounted_price': item.discountedPrice!.toStringAsFixed(2),
              },
          });
        }
      }
    }
    return items;
  }

  void _handleZoneCheckout(ZoneData zone) {
    final selectedItems = _getSelectedItemsForCheckout(zone);

    if (selectedItems.isEmpty) {
      SnackbarHelper.showError(
        context,
        'Please select valid items to checkout',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckOutScreen(selectedCartItems: selectedItems),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[700]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Shopping Cart',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (!_isLoading && _zones.isNotEmpty)
            TextButton(
              onPressed: _clearAllItems,
              child: Text(
                'Clear All',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _zones.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadCartItems,
                      color: AppColors.primaryGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _zones.length,
                        itemBuilder: (context, index) {
                          return _buildZoneCard(_zones[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildLoadingState() {
    return const GenericListSkeleton(count: 4, itemHeight: 100);
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'An error occurred',
              style: TextStyle(fontSize: 16, color: Colors.grey[900]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadCartItems,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some items to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomerDashboardScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue Shopping',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(ZoneData zone) {
    final subtotal = _calculateZoneSubtotal(zone);
    final selectedCount = _getSelectedItemsCount(zone);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zone Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildCheckbox(
                  value: zone.isSelected,
                  isIndeterminate: zone.isIndeterminate,
                  onChanged: () => _toggleZone(zone.id),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.location_on,
                  color: AppColors.primaryGreen,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$selectedCount ${selectedCount == 1 ? 'item' : 'items'} selected',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₱${subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),

          // Shops List
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: zone.shops.map((shop) {
                return _buildShopCard(zone.id, shop);
              }).toList(),
            ),
          ),

          // Zone Checkout Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    selectedCount > 0 ? () => _handleZoneCheckout(zone) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[400],
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart_checkout, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      selectedCount > 0
                          ? 'Checkout - ₱${subtotal.toStringAsFixed(2)}'
                          : 'Select items to checkout',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(String zoneId, ShopData shop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                _buildCheckbox(
                  value: shop.isSelected,
                  isIndeterminate: shop.isIndeterminate,
                  onChanged: () => _toggleShop(zoneId, shop.id),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.store,
                  color: AppColors.accentAmber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      if (shop.address != null && shop.address!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            shop.address!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${shop.items.length} ${shop.items.length == 1 ? 'item' : 'items'}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Items List
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: shop.items.map((item) {
                return _buildItemCard(zoneId, shop.id, item);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(String zoneId, String shopId, ItemData item) {
    final lineTotal = item.effectivePrice * item.quantity;
    final isValid = item.isQuantityValid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border.all(
          color: !isValid
              ? AppColors.error.withOpacity(0.4)
              : item.isSelected
                  ? AppColors.primaryGreen
                  : Colors.grey[300]!,
          width: !isValid || item.isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Checkbox
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _buildCheckbox(
              value: isValid && item.isSelected,
              isIndeterminate: false,
              onChanged:
                  isValid ? () => _toggleItem(zoneId, shopId, item.id) : null,
              enabled: isValid,
            ),
          ),
          const SizedBox(width: 12),

          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Price display
                CartItemPriceDisplay(pricing: item.pricing),

                // Stock warning
                if (item.isOutOfStock)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Out of stock',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  )
                else if (!isValid)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Only ${item.stock} available',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // Quantity controls & line total
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: item.quantity <= 1 || item.isOutOfStock
                                ? null
                                : () => _updateQuantity(
                                    zoneId, shopId, item.id, item.quantity - 1),
                            color: item.quantity <= 1
                                ? Colors.grey[400]
                                : Colors.grey[700],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: item.quantity >= item.stock ||
                                    item.isOutOfStock
                                ? null
                                : () => _updateQuantity(
                                    zoneId, shopId, item.id, item.quantity + 1),
                            color: item.quantity >= item.stock
                                ? Colors.grey[400]
                                : AppColors.primaryGreen,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isValid)
                      Text(
                        '₱${lineTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: item.isSelected
                              ? AppColors.primaryGreen
                              : Colors.grey[700],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => _removeItem(zoneId, shopId, item.id),
            tooltip: 'Remove item',
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required bool isIndeterminate,
    VoidCallback? onChanged,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onChanged : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: !enabled
              ? Colors.grey[200]
              : value
                  ? AppColors.primaryGreen
                  : isIndeterminate
                      ? AppColors.primaryGreen.withOpacity(0.5)
                      : Colors.white,
          border: Border.all(
            color: !enabled
                ? Colors.grey[400]!
                : value || isIndeterminate
                    ? AppColors.primaryGreen
                    : Colors.grey[400]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: value
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : isIndeterminate
                ? const Icon(Icons.remove, color: Colors.white, size: 16)
                : null,
      ),
    );
  }
}

// =============================================================================
// Data Models for CartScreenV2
// =============================================================================

class ZoneData {
  final String id;
  final String name;
  final List<ShopData> shops;
  bool isSelected;
  bool isIndeterminate;

  ZoneData({
    required this.id,
    required this.name,
    required this.shops,
    this.isSelected = false,
    this.isIndeterminate = false,
  });
}

class ShopData {
  final String id;
  final String name;
  final String? address;
  final List<ItemData> items;
  bool isSelected;
  bool isIndeterminate;

  ShopData({
    required this.id,
    required this.name,
    this.address,
    required this.items,
    this.isSelected = false,
    this.isIndeterminate = false,
  });
}

class ItemData {
  final String id;
  final String itemId;
  final String name;
  final double price;
  final double priceSnapshot;
  final double? discountedPrice;
  final String? discountStatus;
  final double? discountPercent;
  final int stock;
  int quantity;
  bool isSelected;

  ItemData({
    required this.id,
    required this.itemId,
    required this.name,
    required this.price,
    required this.priceSnapshot,
    this.discountedPrice,
    this.discountStatus,
    this.discountPercent,
    required this.stock,
    required this.quantity,
    this.isSelected = false,
  });

  CartItemPricing get pricing => CartItemPricing(
        priceSnapshot: priceSnapshot,
        itemPrice: price,
        discountedPrice: discountedPrice,
        discountStatus: discountStatus,
        discountPercent: discountPercent,
      );

  double get effectivePrice => pricing.effectivePrice;

  bool get isQuantityValid => quantity <= stock && stock > 0;

  bool get isOutOfStock => stock <= 0;
}
