import 'package:flutter/material.dart';
import '../constants/constants.dart';
import 'profileScreen.dart';
import '../widgets/stat_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/order_item_card.dart';
import '../widgets/product_inventory_item.dart';
import '../widgets/dashboard_header.dart';

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  int _selectedIndex = 0;

  // Sample shop data
  final Map<String, dynamic> _shopData = {
    'name': 'Green Farm Supply',
    'owner': 'John Smith',
  };

  // Sample statistics
  final Map<String, dynamic> _stats = {
    'totalOrders': 156,
    'revenue': 45230.50,
    'totalProducts': 48,
    'pendingOrders': 12,
  };

  final List<Map<String, dynamic>> _customerOrders = [
    {
      'id': '#ORD-2024-001',
      'customer': 'Maria Garcia',
      'status': 'Pending',
      'date': '2024-01-20',
      'total': 1250.00,
      'items': 3,
      'phone': '+63 912 345 6789',
      'address': '123 Main St, Manila',
    },
    {
      'id': '#ORD-2024-002',
      'customer': 'Juan dela Cruz',
      'status': 'Processing',
      'date': '2024-01-20',
      'total': 890.50,
      'items': 2,
      'phone': '+63 912 345 6790',
      'address': '456 Oak Ave, Quezon City',
    },
    {
      'id': '#ORD-2024-003',
      'customer': 'Anna Santos',
      'status': 'Shipped',
      'date': '2024-01-19',
      'total': 2100.00,
      'items': 5,
      'phone': '+63 912 345 6791',
      'address': '789 Pine Rd, Makati',
    },
    {
      'id': '#ORD-2024-004',
      'customer': 'Carlos Rodriguez',
      'status': 'Pending',
      'date': '2024-01-21',
      'total': 750.25,
      'items': 2,
      'phone': '+63 912 345 6792',
      'address': '321 Elm St, Pasig',
    },
    {
      'id': '#ORD-2024-005',
      'customer': 'Lisa Tan',
      'status': 'Delivered',
      'date': '2024-01-18',
      'total': 1850.75,
      'items': 4,
      'phone': '+63 912 345 6793',
      'address': '654 Maple Dr, Taguig',
    },
  ];

  final List<Map<String, dynamic>> _productInventory = [
    {
      'id': 'PROD-001',
      'name': 'Organic Fertilizer',
      'category': 'Fertilizers',
      'price': 24.99,
      'stock': 45,
      'minStock': 10,
      'unit': 'kg',
    },
    {
      'id': 'PROD-002',
      'name': 'Garden Spade',
      'category': 'Tools',
      'price': 18.50,
      'stock': 32,
      'minStock': 8,
      'unit': 'piece',
    },
    {
      'id': 'PROD-003',
      'name': 'Watering Can',
      'category': 'Tools',
      'price': 15.99,
      'stock': 28,
      'minStock': 10,
      'unit': 'piece',
    },
    {
      'id': 'PROD-004',
      'name': 'Tomato Seeds',
      'category': 'Seeds',
      'price': 8.99,
      'stock': 5,
      'minStock': 15,
      'unit': 'pack',
    },
    {
      'id': 'PROD-005',
      'name': 'Potting Soil',
      'category': 'Soil',
      'price': 12.50,
      'stock': 20,
      'minStock': 10,
      'unit': 'bag',
    },
    {
      'id': 'PROD-006',
      'name': 'Garden Hoe',
      'category': 'Tools',
      'price': 22.00,
      'stock': 15,
      'minStock': 5,
      'unit': 'piece',
    },
    {
      'id': 'PROD-007',
      'name': 'Pepper Seeds',
      'category': 'Seeds',
      'price': 7.50,
      'stock': 3,
      'minStock': 12,
      'unit': 'pack',
    },
    {
      'id': 'PROD-008',
      'name': 'Garden Rake',
      'category': 'Tools',
      'price': 19.99,
      'stock': 18,
      'minStock': 6,
      'unit': 'piece',
    },
  ];

  final List<Map<String, dynamic>> _lowStockProducts = [
    {
      'name': 'Organic Fertilizer',
      'stock': 5,
      'minStock': 10,
    },
    {
      'name': 'Garden Spade',
      'stock': 3,
      'minStock': 8,
    },
  ];

  final List<Map<String, dynamic>> _topProducts = [
    {
      'name': 'Organic Fertilizer',
      'sales': 125,
      'revenue': 3125.00,
    },
    {
      'name': 'Garden Spade',
      'sales': 89,
      'revenue': 1646.50,
    },
    {
      'name': 'Watering Can',
      'sales': 67,
      'revenue': 1073.33,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _getCurrentView(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _getCurrentView() {
    switch (_selectedIndex) {
      case 0:
        return _buildShopManagementView();
      case 1:
        return _buildOrdersView();
      case 2:
        return _buildInventoryView();
      case 3:
        return _buildProfileNavigation();
      default:
        return _buildShopManagementView();
    }
  }

  Widget _buildShopManagementView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          SizedBox(height: 24),

          // Statistics cards
          _buildStatisticsCards(),
          SizedBox(height: 24),

          // Quick actions
          _buildQuickActions(),
          SizedBox(height: 24),

          // Recent orders preview
          _buildRecentOrdersPreview(),
          SizedBox(height: 24),

          // Low stock alerts
          if (_lowStockProducts.isNotEmpty) ...[
            _buildLowStockAlerts(),
            SizedBox(height: 24),
          ],

          // Top selling products
          _buildTopProducts(),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return DashboardHeader(
      greeting: 'Good Morning!',
      title: _shopData['name'],
      subtitle: 'Owner: ${_shopData['owner']}',
      icon: Icons.store,
    );
  }

  Widget _buildStatisticsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        StatCard(
          title: 'Total Orders',
          value: '${_stats['totalOrders']}',
          icon: Icons.shopping_bag_outlined,
          color: Colors.blue,
        ),
        StatCard(
          title: 'Revenue',
          value: '₱${_stats['revenue'].toStringAsFixed(2)}',
          icon: Icons.attach_money,
          color: AppColors.mediumGreen,
        ),
        StatCard(
          title: 'Products',
          value: '${_stats['totalProducts']}',
          icon: Icons.inventory_2_outlined,
          color: Colors.orange,
        ),
        StatCard(
          title: 'Pending',
          value: '${_stats['pendingOrders']}',
          icon: Icons.pending_outlined,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: QuickActionButton(
                label: 'Add Product',
                icon: Icons.add_circle_outline,
                color: AppColors.mediumGreen,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Add product functionality coming soon!'),
                      backgroundColor: AppColors.mediumGreen,
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: QuickActionButton(
                label: 'View Orders',
                icon: Icons.list_alt,
                color: Colors.blue,
                onTap: () {
                  setState(() {
                    _selectedIndex = 1; // Switch to Orders tab
                  });
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: QuickActionButton(
                label: 'Inventory',
                icon: Icons.inventory_outlined,
                color: Colors.orange,
                onTap: () {
                  setState(() {
                    _selectedIndex = 2; // Switch to Inventory tab
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentOrdersPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Orders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedIndex = 1; // Switch to Orders tab
                });
              },
              child: Text(
                'View All',
                style: TextStyle(
                  color: AppColors.mediumGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children:
                _customerOrders.take(3).toList().asMap().entries.map((entry) {
              int index = entry.key;
              var order = entry.value;
              bool isLast = index == _customerOrders.take(3).length - 1;
              return OrderItemCard(
                order: order,
                isLast: isLast,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersView() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.grey[700]),
                onPressed: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              ),
              SizedBox(width: 8),
              Text(
                'Customer Orders',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _customerOrders.length,
            itemBuilder: (context, index) {
              final order = _customerOrders[index];
              return OrderItemCard(
                order: order,
                showDetails: true,
                onUpdateStatus: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Update order status functionality coming soon!'),
                      backgroundColor: AppColors.mediumGreen,
                    ),
                  );
                },
                onViewDetails: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('View details functionality coming soon!'),
                      backgroundColor: AppColors.mediumGreen,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryView() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.grey[700]),
                    onPressed: () {
                      setState(() {
                        _selectedIndex = 0;
                      });
                    },
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Product Inventory',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline,
                    color: AppColors.mediumGreen),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Add product functionality coming soon!'),
                      backgroundColor: AppColors.mediumGreen,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _productInventory.length,
            itemBuilder: (context, index) {
              final product = _productInventory[index];
              return ProductInventoryItem(
                product: product,
                onEdit: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Edit functionality coming soon!'),
                      backgroundColor: AppColors.mediumGreen,
                    ),
                  );
                },
                onRestock: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Restock functionality coming soon!'),
                      backgroundColor: Colors.orange[700],
                    ),
                  );
                },
                onDelete: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Delete functionality coming soon!'),
                      backgroundColor: Colors.red[700],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileNavigation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.mediumGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              size: 64,
              color: AppColors.mediumGreen,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Profile Management',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Manage your vendor profile',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
            icon: Icon(Icons.person),
            label: Text('Go to Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mediumGreen,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange[600], size: 20),
            SizedBox(width: 8),
            Text(
              'Low Stock Alerts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[300]!),
          ),
          child: Column(
            children: _lowStockProducts.map((product) {
              bool isLast = product == _lowStockProducts.last;
              return Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.orange[700],
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Stock: ${product['stock']} (Min: ${product['minStock']})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Restock functionality coming soon!'),
                            backgroundColor: Colors.orange[700],
                          ),
                        );
                      },
                      child: Text(
                        'Restock',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Selling Products',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: _topProducts.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> product = entry.value;
              bool isLast = index == _topProducts.length - 1;
              return Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.mediumGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mediumGreen,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${product['sales']} sales',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₱${product['revenue'].toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mediumGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.mediumGreen,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
