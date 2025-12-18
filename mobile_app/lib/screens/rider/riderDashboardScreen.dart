import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../services/order_service.dart';
import '../../services/api_service.dart';
import '../../provider/provider.dart';
import '../../widgets/dashboard_header.dart';
import '../../widgets/order_item_card.dart';
import '../../widgets/rider_statistics_grid.dart';
import '../../widgets/rider_quick_actions.dart';
import '../../widgets/active_deliveries_section.dart';
import '../../widgets/view_header.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/order_details_dialog.dart';
import '../../widgets/update_status_dialog.dart';
import '../common/profileScreen.dart';
import 'riderDeliveryScreen.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  int _selectedIndex = 0;
  final OrderService _orderService = OrderService();
  List<Map<String, dynamic>> _allOrders = [];
  bool _isLoadingOrders = true;
  String? _orderError;
  String? _userName;
  bool _useSampleActiveDeliveries = false;

  // Sample active deliveries for home view
  final List<Map<String, dynamic>> _sampleActiveDeliveries = [
    {
      'id': '1',
      'order_id': '1',
      'order_code': 'ORD-2024-101',
      'user_id': '1',
      'order_status': 'in-transit',
      'ordered_at':
          DateTime.now().subtract(Duration(hours: 1)).toIso8601String(),
      'updated_at':
          DateTime.now().subtract(Duration(minutes: 30)).toIso8601String(),
      'subtotal': '1250.00',
      'shipping_fee': '50.00',
      'total_amount': '1300.00',
      'shipping_address':
          '123 Main Street, Barangay San Antonio, Quezon City, Metro Manila',
      'drop_location_lat': 14.6760,
      'drop_location_long': 121.0437,
      'order_instruction': 'Please ring the doorbell twice.',
      'payment_method': 'Cash on Delivery',
      'payment_status': 'pending',
      'user': {
        'id': '1',
        'first_name': 'Maria',
        'last_name': 'Garcia',
        'mobile_number': '+63 912 345 6789',
        'email': 'maria.garcia@example.com',
      },
      'order_items': [
        {
          'item_name': 'Organic Fertilizer 5kg',
          'quantity': 2,
          'item_price': '450.00',
        },
        {
          'item_name': 'Garden Spade',
          'quantity': 1,
          'item_price': '350.00',
        },
      ],
    },
    {
      'id': '2',
      'order_id': '2',
      'order_code': 'ORD-2024-102',
      'user_id': '2',
      'order_status': 'processing',
      'ordered_at':
          DateTime.now().subtract(Duration(minutes: 45)).toIso8601String(),
      'updated_at':
          DateTime.now().subtract(Duration(minutes: 20)).toIso8601String(),
      'subtotal': '890.50',
      'shipping_fee': '45.00',
      'total_amount': '935.50',
      'shipping_address':
          '456 Oak Avenue, Barangay Poblacion, Makati City, Metro Manila',
      'drop_location_lat': 14.5547,
      'drop_location_long': 121.0244,
      'order_instruction': 'Call before delivery.',
      'payment_method': 'GCash',
      'payment_status': 'paid',
      'user': {
        'id': '2',
        'first_name': 'Juan',
        'last_name': 'dela Cruz',
        'mobile_number': '+63 912 345 6790',
        'email': 'juan.delacruz@example.com',
      },
      'order_items': [
        {
          'item_name': 'Tomato Seeds Pack',
          'quantity': 3,
          'item_price': '150.00',
        },
        {
          'item_name': 'Potting Soil 10kg',
          'quantity': 2,
          'item_price': '220.25',
        },
      ],
    },
    {
      'id': '3',
      'order_id': '3',
      'order_code': 'ORD-2024-103',
      'user_id': '3',
      'order_status': 'in-transit',
      'ordered_at':
          DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
      'updated_at':
          DateTime.now().subtract(Duration(hours: 1)).toIso8601String(),
      'subtotal': '2100.00',
      'shipping_fee': '75.00',
      'total_amount': '2175.00',
      'shipping_address':
          '789 Pine Road, Barangay Kapitolyo, Pasig City, Metro Manila',
      'drop_location_lat': 14.5764,
      'drop_location_long': 121.0851,
      'order_instruction': 'Fragile items. Handle with care.',
      'payment_method': 'Cash on Delivery',
      'payment_status': 'pending',
      'user': {
        'id': '3',
        'first_name': 'Anna',
        'last_name': 'Santos',
        'mobile_number': '+63 912 345 6791',
        'email': 'anna.santos@example.com',
      },
      'order_items': [
        {
          'item_name': 'Watering Can Large',
          'quantity': 2,
          'item_price': '350.00',
        },
        {
          'item_name': 'Garden Rake',
          'quantity': 1,
          'item_price': '450.00',
        },
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      _userName = await ApiService.getUserName();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading user name: $e');
    }
  }

  Future<void> _loadOrders({bool useCache = true}) async {
    setState(() {
      _isLoadingOrders = true;
      _orderError = null;
    });

    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);

    await ordersProvider.fetchOrders(useCache: useCache);

    setState(() {
      _allOrders = ordersProvider.orders;
      _isLoadingOrders = ordersProvider.isLoading;
      _orderError = ordersProvider.error;
      if (ordersProvider.fromCache && _allOrders.isNotEmpty) {
        _orderError = 'Using cached data (connection lost)';
      }
      // Use sample active deliveries if no real active deliveries
      final hasActiveDeliveries = _allOrders.any((order) {
        final status = order['order_status']?.toString().toLowerCase() ?? '';
        return status == 'in-transit' ||
            status == 'in transit' ||
            status == 'processing';
      });
      _useSampleActiveDeliveries = !hasActiveDeliveries;
    });
  }

  Future<void> _onRefresh() async {
    await _loadOrders(useCache: false);
    await Future.delayed(Duration(milliseconds: 500));
  }

  PageRoute _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale:
                Tween<double>(begin: 0.98, end: 1.0).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      transitionDuration: Duration(milliseconds: 150),
      reverseTransitionDuration: Duration(milliseconds: 150),
    );
  }

  List<Map<String, dynamic>> get _activeDeliveries {
    final realActiveDeliveries = _allOrders
        .where((order) =>
            order['order_status']?.toString().toLowerCase() == 'in-transit' ||
            order['order_status']?.toString().toLowerCase() == 'in transit' ||
            order['order_status']?.toString().toLowerCase() == 'processing')
        .toList();

    // If no real active deliveries and not loading, use sample data
    if (realActiveDeliveries.isEmpty &&
        !_isLoadingOrders &&
        _useSampleActiveDeliveries) {
      return _sampleActiveDeliveries;
    }

    return realActiveDeliveries;
  }

  List<Map<String, dynamic>> get _completedDeliveries {
    return _allOrders
        .where((order) =>
            order['order_status']?.toString().toLowerCase() == 'delivered')
        .toList();
  }

  List<Map<String, dynamic>> get _pendingDeliveries {
    return _allOrders
        .where((order) =>
            order['order_status']?.toString().toLowerCase() == 'pending')
        .toList();
  }

  Map<String, dynamic> get _stats {
    final totalDeliveries = _allOrders.length;
    final pendingCount = _pendingDeliveries.length;
    final completedCount = _completedDeliveries.length;
    final activeCount = _activeDeliveries.length;

    // Calculate total earnings from completed deliveries
    double totalEarnings = 0.0;
    for (var order in _completedDeliveries) {
      final shippingFee =
          double.tryParse(order['shipping_fee']?.toString() ?? '0.0') ?? 0.0;
      totalEarnings += shippingFee;
    }

    return {
      'totalDeliveries': totalDeliveries,
      'pending': pendingCount,
      'active': activeCount,
      'completed': completedCount,
      'earnings': totalEarnings,
    };
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '₱0.00';
    try {
      if (price is num) {
        return '₱${price.toStringAsFixed(2)}';
      } else if (price is String) {
        final parsed = double.tryParse(price);
        return parsed != null ? '₱${parsed.toStringAsFixed(2)}' : '₱0.00';
      }
    } catch (e) {
      print('Error formatting price: $e');
    }
    return '₱0.00';
  }

  String _formatOrderDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.tryParse(dateString);
      if (dateTime != null) {
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
      }
    } catch (e) {
      print('Error formatting date: $e');
    }
    return dateString;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return AppColors.mediumGreen;
      case 'in transit':
      case 'in-transit':
        return Colors.orange[600]!;
      case 'pending':
        return Colors.grey[600]!;
      case 'processing':
        return Colors.blue[600]!;
      case 'cancelled':
      case 'canceled':
        return Colors.red[600]!;
      default:
        return Colors.grey[500]!;
    }
  }

  Map<String, dynamic> _convertOrderToCardFormat(Map<String, dynamic> order) {
    final user = order['user'] as Map<String, dynamic>?;
    final customerName = user != null
        ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()
        : 'Unknown Customer';

    return {
      'id': order['order_code']?.toString() ?? 'N/A',
      'customer': customerName,
      'status': order['order_status']?.toString() ?? 'Pending',
      'date': _formatOrderDate(order['ordered_at']?.toString() ?? ''),
      'total':
          double.tryParse(order['total_amount']?.toString() ?? '0.0') ?? 0.0,
      'items': (order['order_items'] as List?)?.length ?? 0,
      'phone': user?['mobile_number']?.toString() ?? '',
      'address': order['shipping_address']?.toString() ?? '',
      'order_id': order['order_id']?.toString() ?? order['id']?.toString(),
    };
  }

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
        return _buildHomeView();
      case 1:
        return _buildDeliveriesView();
      case 2:
        return _buildHistoryView();
      case 3:
        return _buildProfileNavigation();
      default:
        return _buildHomeView();
    }
  }

  Widget _buildHomeView() {
    final stats = _stats;
    final activeDeliveries = _activeDeliveries.take(3).toList();

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.mediumGreen,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            SizedBox(height: 24),

            // Statistics cards
            _buildStatisticsCards(stats),
            SizedBox(height: 24),

            // Quick actions
            _buildQuickActions(),
            SizedBox(height: 24),

            // Active deliveries
            _buildActiveDeliveriesSection(activeDeliveries),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return DashboardHeader(
      greeting: 'Good Morning!',
      title: 'Welcome, $_userName!',
      subtitle: 'Manage your deliveries',
      icon: Icons.delivery_dining,
      onIconTap: () {
        // Could navigate to profile or settings
      },
    );
  }

  Widget _buildStatisticsCards(Map<String, dynamic> stats) {
    return RiderStatisticsGrid(
      stats: stats,
      formatPrice: _formatPrice,
    );
  }

  Widget _buildQuickActions() {
    return RiderQuickActions(
      onNewDelivery: () {
        Navigator.push(
          context,
          _createFadeRoute(RiderDeliveryScreen()),
        ).then((_) {
          // Refresh orders when returning
          _loadOrders(useCache: false);
        });
      },
      onViewAll: () {
        setState(() {
          _selectedIndex = 1; // Switch to Deliveries tab
        });
      },
      onHistory: () {
        setState(() {
          _selectedIndex = 2; // Switch to History tab
        });
      },
    );
  }

  Widget _buildActiveDeliveriesSection(List<Map<String, dynamic>> deliveries) {
    return ActiveDeliveriesSection(
      deliveries: deliveries,
      isLoading: _isLoadingOrders,
      error: _orderError,
      useSampleData: _useSampleActiveDeliveries,
      onRetry: () => _loadOrders(useCache: false),
      onViewAll: () {
        setState(() {
          _selectedIndex = 1; // Switch to Deliveries tab
        });
      },
      onLoadSampleData: () {
        setState(() {
          _useSampleActiveDeliveries = true;
        });
      },
      onUpdateStatus: (order) => _showUpdateStatusDialog(order),
      onViewDetails: (order) => _showOrderDetails(order),
      convertOrderToCardFormat: _convertOrderToCardFormat,
    );
  }

  Widget _buildDeliveriesView() {
    final allDeliveries = _allOrders;

    return Column(
      children: [
        ViewHeader(
          title: 'All Deliveries',
          onBack: () {
            setState(() {
              _selectedIndex = 0;
            });
          },
          trailing: _orderError != null
              ? IconButton(
                  icon: Icon(Icons.refresh, color: AppColors.mediumGreen),
                  onPressed: () => _loadOrders(useCache: false),
                  tooltip: 'Retry',
                )
              : null,
        ),
        Expanded(
          child: _isLoadingOrders
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.mediumGreen,
                  ),
                )
              : allDeliveries.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.inbox_outlined,
                      message: 'No deliveries found',
                      subtitle: _orderError,
                    )
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: AppColors.mediumGreen,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: allDeliveries.length,
                        itemBuilder: (context, index) {
                          final order = allDeliveries[index];
                          final cardData = _convertOrderToCardFormat(order);

                          return OrderItemCard(
                            order: cardData,
                            showDetails: true,
                            onUpdateStatus: () {
                              _showUpdateStatusDialog(order);
                            },
                            onViewDetails: () {
                              _showOrderDetails(order);
                            },
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildHistoryView() {
    final completedDeliveries = _completedDeliveries;

    return Column(
      children: [
        ViewHeader(
          title: 'Delivery History',
          onBack: () {
            setState(() {
              _selectedIndex = 0;
            });
          },
        ),
        Expanded(
          child: completedDeliveries.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.history_outlined,
                  message: 'No completed deliveries yet',
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppColors.mediumGreen,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: completedDeliveries.length,
                    itemBuilder: (context, index) {
                      final order = completedDeliveries[index];
                      final cardData = _convertOrderToCardFormat(order);

                      return OrderItemCard(
                        order: cardData,
                        showDetails: true,
                        onViewDetails: () {
                          _showOrderDetails(order);
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildProfileNavigation() {
    return ProfileScreen(hideBottomNavigation: true);
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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Deliveries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _showUpdateStatusDialog(Map<String, dynamic> order) {
    final orderId = order['order_id']?.toString() ?? order['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid order ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => UpdateStatusDialog(
        order: order,
        onStatusSelected: (status) {
          _updateOrderStatus(orderId, status);
        },
      ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      final result = await _orderService.updateOrderStatus(
        orderId: orderId,
        status: status,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated successfully'),
            backgroundColor: AppColors.mediumGreen,
          ),
        );
        await _loadOrders(useCache: false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => OrderDetailsDialog(
        order: order,
        formatOrderDate: _formatOrderDate,
        formatPrice: _formatPrice,
      ),
    );
  }
}
