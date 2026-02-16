import 'package:flutter/material.dart';
import '../../constants/constants.dart';

class CartScreenV2 extends StatefulWidget {
  const CartScreenV2({super.key});

  @override
  State<CartScreenV2> createState() => _CartScreenV2State();
}

class _CartScreenV2State extends State<CartScreenV2> {
  // Mock data structure: Zone -> Shop -> Item
  late List<ZoneData> _zones;

  @override
  void initState() {
    super.initState();
    _initializeMockData();
  }

  void _initializeMockData() {
    _zones = [
      ZoneData(
        id: 'zone1',
        name: 'Zone A - North District',
        shops: [
          ShopData(
            id: 'shop1',
            name: 'Green Garden Supplies',
            items: [
              ItemData(
                id: 'item1',
                name: 'Organic Fertilizer',
                price: 24.99,
                quantity: 2,
              ),
              ItemData(
                id: 'item2',
                name: 'Garden Spade',
                price: 18.50,
                quantity: 1,
              ),
              ItemData(
                id: 'item3',
                name: 'Watering Can',
                price: 15.99,
                quantity: 3,
              ),
            ],
          ),
          ShopData(
            id: 'shop2',
            name: 'Farm Fresh Tools',
            items: [
              ItemData(
                id: 'item4',
                name: 'Pruning Shears',
                price: 12.99,
                quantity: 2,
              ),
              ItemData(
                id: 'item5',
                name: 'Garden Gloves',
                price: 8.50,
                quantity: 4,
              ),
            ],
          ),
        ],
      ),
      ZoneData(
        id: 'zone2',
        name: 'Zone B - South District',
        shops: [
          ShopData(
            id: 'shop3',
            name: 'AgriTech Solutions',
            items: [
              ItemData(
                id: 'item6',
                name: 'Seed Packets',
                price: 5.99,
                quantity: 10,
              ),
              ItemData(
                id: 'item7',
                name: 'Plant Pots',
                price: 3.50,
                quantity: 6,
              ),
              ItemData(
                id: 'item8',
                name: 'Soil Mix',
                price: 19.99,
                quantity: 2,
              ),
            ],
          ),
        ],
      ),
      ZoneData(
        id: 'zone3',
        name: 'Zone C - East District',
        shops: [
          ShopData(
            id: 'shop4',
            name: 'Harvest Market',
            items: [
              ItemData(
                id: 'item9',
                name: 'Compost Bin',
                price: 45.00,
                quantity: 1,
              ),
            ],
          ),
          ShopData(
            id: 'shop5',
            name: 'Garden Essentials',
            items: [
              ItemData(
                id: 'item10',
                name: 'Hose Pipe',
                price: 32.99,
                quantity: 1,
              ),
              ItemData(
                id: 'item11',
                name: 'Sprinkler',
                price: 28.50,
                quantity: 2,
              ),
            ],
          ),
        ],
      ),
    ];
  }

  // Handle Zone checkbox toggle
  void _toggleZone(String zoneId) {
    setState(() {
      final zone = _zones.firstWhere((z) => z.id == zoneId);
      zone.isSelected = !zone.isSelected;

      // Cascade to all shops and items in this zone
      for (var shop in zone.shops) {
        shop.isSelected = zone.isSelected;
        for (var item in shop.items) {
          item.isSelected = zone.isSelected;
        }
      }
    });
  }

  // Handle Shop checkbox toggle
  void _toggleShop(String zoneId, String shopId) {
    setState(() {
      final zone = _zones.firstWhere((z) => z.id == zoneId);
      final shop = zone.shops.firstWhere((s) => s.id == shopId);
      shop.isSelected = !shop.isSelected;

      // Cascade to all items in this shop
      for (var item in shop.items) {
        item.isSelected = shop.isSelected;
      }

      // Update zone selection state
      _updateZoneSelection(zone);
    });
  }

  // Handle Item checkbox toggle
  void _toggleItem(String zoneId, String shopId, String itemId) {
    setState(() {
      final zone = _zones.firstWhere((z) => z.id == zoneId);
      final shop = zone.shops.firstWhere((s) => s.id == shopId);
      final item = shop.items.firstWhere((i) => i.id == itemId);
      item.isSelected = !item.isSelected;

      // Update shop selection state
      _updateShopSelection(shop);

      // Update zone selection state
      _updateZoneSelection(zone);
    });
  }

  // Update shop selection based on item selections
  void _updateShopSelection(ShopData shop) {
    final allSelected = shop.items.every((item) => item.isSelected);
    final someSelected = shop.items.any((item) => item.isSelected);
    shop.isSelected = allSelected;
    shop.isIndeterminate = someSelected && !allSelected;
  }

  // Update zone selection based on shop/item selections
  void _updateZoneSelection(ZoneData zone) {
    final allSelected = zone.shops.every((shop) =>
        shop.isSelected && shop.items.every((item) => item.isSelected));
    final someSelected = zone.shops.any(
        (shop) => shop.isSelected || shop.items.any((item) => item.isSelected));

    zone.isSelected = allSelected;
    zone.isIndeterminate = someSelected && !allSelected;

    // Update shop indeterminate states
    for (var shop in zone.shops) {
      _updateShopSelection(shop);
    }
  }

  // Calculate zone subtotal
  double _calculateZoneSubtotal(ZoneData zone) {
    double total = 0.0;
    for (var shop in zone.shops) {
      if (shop.isSelected) {
        // If shop is selected, include all items
        for (var item in shop.items) {
          total += item.price * item.quantity;
        }
      } else {
        // Only include selected items
        for (var item in shop.items) {
          if (item.isSelected) {
            total += item.price * item.quantity;
          }
        }
      }
    }
    return total;
  }

  // Get selected items count for zone
  int _getSelectedItemsCount(ZoneData zone) {
    int count = 0;
    for (var shop in zone.shops) {
      if (shop.isSelected) {
        count += shop.items.length;
      } else {
        count += shop.items.where((item) => item.isSelected).length;
      }
    }
    return count;
  }

  // Update item quantity
  void _updateQuantity(
      String zoneId, String shopId, String itemId, int newQuantity) {
    if (newQuantity < 1) {
      // Remove item if quantity goes below 1
      _removeItem(zoneId, shopId, itemId);
      return;
    }
    setState(() {
      final zone = _zones.firstWhere((z) => z.id == zoneId);
      final shop = zone.shops.firstWhere((s) => s.id == shopId);
      final item = shop.items.firstWhere((i) => i.id == itemId);
      item.quantity = newQuantity;
    });
  }

  // Remove item from cart
  void _removeItem(String zoneId, String shopId, String itemId) {
    setState(() {
      final zone = _zones.firstWhere((z) => z.id == zoneId);
      final shop = zone.shops.firstWhere((s) => s.id == shopId);
      shop.items.removeWhere((item) => item.id == itemId);

      // If shop has no items, remove the shop
      if (shop.items.isEmpty) {
        zone.shops.removeWhere((s) => s.id == shopId);
      }

      // If zone has no shops, remove the zone
      if (zone.shops.isEmpty) {
        _zones.removeWhere((z) => z.id == zoneId);
      }

      // Update selection states after removal
      if (zone.shops.isNotEmpty) {
        _updateZoneSelection(zone);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Cart V2 - Zone Based',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.grey),
      ),
      body: _zones.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _zones.length,
              itemBuilder: (context, index) {
                return _buildZoneCard(_zones[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
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
              color: AppColors.mediumGreen.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Zone Checkbox
                _buildCheckbox(
                  value: zone.isSelected,
                  isIndeterminate: zone.isIndeterminate,
                  onChanged: () => _toggleZone(zone.id),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.location_on,
                  color: AppColors.mediumGreen,
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
                    color: AppColors.mediumGreen,
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
                  backgroundColor: AppColors.mediumGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Checkout Zone - ₱${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                // Shop Checkbox
                _buildCheckbox(
                  value: shop.isSelected,
                  isIndeterminate: shop.isIndeterminate,
                  onChanged: () => _toggleShop(zoneId, shop.id),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.store,
                  color: AppColors.freshLeafGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shop.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Text(
                  '${shop.items.length} ${shop.items.length == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
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
    final subtotal = item.price * item.quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(
          color: item.isSelected ? AppColors.mediumGreen : Colors.grey[300]!,
          width: item.isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Item Checkbox
          _buildCheckbox(
            value: item.isSelected,
            isIndeterminate: false,
            onChanged: () => _toggleItem(zoneId, shopId, item.id),
          ),
          const SizedBox(width: 12),
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
                ),
                const SizedBox(height: 8),
                Text(
                  'Price: ₱${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                // Quantity controls
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
                            onPressed: () {
                              _updateQuantity(
                                  zoneId, shopId, item.id, item.quantity - 1);
                            },
                            color: Colors.grey[700],
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
                            onPressed: () {
                              _updateQuantity(
                                  zoneId, shopId, item.id, item.quantity + 1);
                            },
                            color: AppColors.mediumGreen,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₱${subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: item.isSelected
                            ? AppColors.mediumGreen
                            : Colors.grey[700],
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
  }

  Widget _buildCheckbox({
    required bool value,
    required bool isIndeterminate,
    required VoidCallback onChanged,
  }) {
    return GestureDetector(
      onTap: onChanged,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: value
              ? AppColors.mediumGreen
              : isIndeterminate
                  ? AppColors.mediumGreen.withOpacity(0.5)
                  : Colors.white,
          border: Border.all(
            color: value || isIndeterminate
                ? AppColors.mediumGreen
                : Colors.grey[400]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: value
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              )
            : isIndeterminate
                ? const Icon(
                    Icons.remove,
                    color: Colors.white,
                    size: 16,
                  )
                : null,
      ),
    );
  }

  void _handleZoneCheckout(ZoneData zone) {
    final subtotal = _calculateZoneSubtotal(zone);
    final selectedCount = _getSelectedItemsCount(zone);

    if (selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item to checkout'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Build selected items list for display
    final selectedItems = <String>[];
    for (var shop in zone.shops) {
      if (shop.isSelected) {
        for (var item in shop.items) {
          selectedItems.add('${item.name} (x${item.quantity})');
        }
      } else {
        for (var item in shop.items) {
          if (item.isSelected) {
            selectedItems.add('${item.name} (x${item.quantity})');
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Checkout: ${zone.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Items:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            ...selectedItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $item',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mediumGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₱${subtotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mediumGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Checkout initiated for ${zone.name} - ₱${subtotal.toStringAsFixed(2)}'),
                  backgroundColor: AppColors.mediumGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mediumGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }
}

// Data Models
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
  final List<ItemData> items;
  bool isSelected;
  bool isIndeterminate;

  ShopData({
    required this.id,
    required this.name,
    required this.items,
    this.isSelected = false,
    this.isIndeterminate = false,
  });
}

class ItemData {
  final String id;
  final String name;
  final double price;
  int quantity; // Made non-final to allow quantity updates
  bool isSelected;

  ItemData({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.isSelected = false,
  });
}
