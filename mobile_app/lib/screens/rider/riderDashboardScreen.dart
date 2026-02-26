import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../constants/constants.dart';
import '../../services/order_service.dart';
import '../../services/api_service.dart';
import '../../provider/provider.dart';
import '../../utils/connectivity_helper.dart';
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
import 'riderPickupMap.dart';
import 'riderDeliveryMap.dart';
import 'riderAllDeliveriesScreen.dart';
import 'riderEarningsScreen.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeOrderStatusProvider();
    _loadOrders();
    _loadUserName();
    _autoUploadPendingPods();
  }

  Future<void> _initializeOrderStatusProvider() async {
    final orderStatusProvider =
        Provider.of<OrderStatusProvider>(context, listen: false);
    await orderStatusProvider.initialize();
  }

  Future<void> _loadUserName() async {
    try {
      _userName = await ApiService.getUserName();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading user name: $e');
    }
  }

  /// Automatically upload pending POD photos if internet is available
  /// This runs silently in the background after login
  Future<void> _autoUploadPendingPods() async {
    try {
      // Check if internet is available
      final hasInternet = await ConnectivityHelper.hasInternetConnection();
      if (!hasInternet) {
        print('POD AUTO-UPLOAD: No internet connection, skipping upload');
        return;
      }

      // Get PodProvider
      final podProvider = Provider.of<PodProvider>(context, listen: false);

      // Check if there are pending photos and not already uploading
      final pendingCount = podProvider.getPendingCount();
      if (pendingCount == 0) {
        print('POD AUTO-UPLOAD: No pending photos to upload');
        return;
      }

      if (podProvider.isUploading) {
        print('POD AUTO-UPLOAD: Upload already in progress, skipping');
        return;
      }

      print(
          'POD AUTO-UPLOAD: Starting automatic upload of $pendingCount pending photo(s)');

      // Upload in background (don't await, let it run silently)
      podProvider.uploadAllPendingPods().then((result) {
        if (result['success'] == true) {
          final data = result['data'] as Map<String, dynamic>?;
          final successCount = data?['successCount'] ?? 0;
          final total = data?['total'] ?? 0;
          print(
              'POD AUTO-UPLOAD: Completed - $successCount of $total photo(s) uploaded');
        } else {
          print('POD AUTO-UPLOAD: Failed - ${result['message']}');
        }
      }).catchError((e) {
        print('POD AUTO-UPLOAD: Error during upload - $e');
      });
    } catch (e) {
      // Silently fail - don't interrupt the login flow
      print(
          'POD AUTO-UPLOAD: Error checking connectivity or starting upload - $e');
    }
  }

  Future<void> _loadOrders({bool useCache = true}) async {
    setState(() {
      _isLoadingOrders = true;
      _orderError = null;
    });

    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);

    // Use fetchRiderOrders to get orders assigned to this rider
    await ordersProvider.fetchRiderOrders(useCache: useCache);

    setState(() {
      _allOrders = ordersProvider.orders;
      _isLoadingOrders = ordersProvider.isLoading;
      _orderError = ordersProvider.error;
      if (ordersProvider.fromCache && _allOrders.isNotEmpty) {
        _orderError = 'Using cached data (connection lost)';
      }
    });
  }

  Future<void> _onRefresh() async {
    await _loadOrders(useCache: false);
    // Trigger automatic POD upload on refresh if internet is available
    _autoUploadPendingPods();
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

  List<Map<String, dynamic>> _getActiveDeliveries(
      OrderStatusProvider orderStatusProvider) {
    // Active deliveries exclude delivered orders
    return _allOrders.where((order) {
      final orderStatusId = order['order_status'];
      int? statusId;
      if (orderStatusId is int) {
        statusId = orderStatusId;
      } else if (orderStatusId is String) {
        statusId = int.tryParse(orderStatusId);
      } else if (orderStatusId != null) {
        statusId = int.tryParse(orderStatusId.toString());
      }

      if (statusId == null) return false;

      final statusDesc = orderStatusProvider
              .getOrderStatusDescription(statusId)
              ?.toLowerCase() ??
          '';
      return statusDesc != 'delivered';
    }).toList();
  }

  List<Map<String, dynamic>> _getCompletedDeliveries(
      OrderStatusProvider orderStatusProvider) {
    return _allOrders.where((order) {
      final orderStatusId = order['order_status'];
      int? statusId;
      if (orderStatusId is int) {
        statusId = orderStatusId;
      } else if (orderStatusId is String) {
        statusId = int.tryParse(orderStatusId);
      } else if (orderStatusId != null) {
        statusId = int.tryParse(orderStatusId.toString());
      }

      if (statusId == null) return false;

      final statusDesc = orderStatusProvider
              .getOrderStatusDescription(statusId)
              ?.toLowerCase() ??
          '';
      return statusDesc == 'delivered';
    }).toList();
  }

  List<Map<String, dynamic>> _getPendingDeliveries(
      OrderStatusProvider orderStatusProvider) {
    return _allOrders.where((order) {
      final orderStatusId = order['order_status'];
      int? statusId;
      if (orderStatusId is int) {
        statusId = orderStatusId;
      } else if (orderStatusId is String) {
        statusId = int.tryParse(orderStatusId);
      } else if (orderStatusId != null) {
        statusId = int.tryParse(orderStatusId.toString());
      }

      if (statusId == null) return false;

      final statusDesc = orderStatusProvider
              .getOrderStatusDescription(statusId)
              ?.toLowerCase() ??
          '';
      return statusDesc == 'pending';
    }).toList();
  }

  Map<String, dynamic> _getStats(OrderStatusProvider orderStatusProvider) {
    final totalDeliveries = _allOrders.length;
    final pendingDeliveries = _getPendingDeliveries(orderStatusProvider);
    final completedDeliveries = _getCompletedDeliveries(orderStatusProvider);
    final activeDeliveries = _getActiveDeliveries(orderStatusProvider);

    final pendingCount = pendingDeliveries.length;
    final completedCount = completedDeliveries.length;
    final activeCount = activeDeliveries.length;

    // Calculate total earnings from completed deliveries
    double totalEarnings = 0.0;
    for (var order in completedDeliveries) {
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

  Map<String, dynamic> _convertOrderToCardFormat(
      Map<String, dynamic> order, OrderStatusProvider orderStatusProvider) {
    final user = order['user'] as Map<String, dynamic>?;
    // Use recipient_name from address if available, fallback to user name
    final recipientName = order['recipient_name']?.toString().isNotEmpty == true
        ? order['recipient_name'].toString()
        : (user != null
            ? '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()
            : 'Unknown Customer');
    // Use recipient_contact from address if available, fallback to user mobile
    final recipientContact =
        order['recipient_contact']?.toString().isNotEmpty == true
            ? order['recipient_contact'].toString()
            : (user?['mobile_number']?.toString() ?? '');

    // Parse order_status as ID (number) and get description from provider
    final orderStatusId = order['order_status'];
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

    return {
      'id': order['order_code']?.toString() ?? 'N/A',
      'customer': recipientName.isNotEmpty ? recipientName : 'Unknown Customer',
      'status': orderStatus,
      'date': _formatOrderDate(order['ordered_at']?.toString() ?? ''),
      'total':
          double.tryParse(order['total_amount']?.toString() ?? '0.0') ?? 0.0,
      'items': (order['order_items'] as List?)?.length ?? 0,
      'phone': recipientContact,
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
      case 2:
        return _buildHistoryView();
      case 3:
        return _buildProfileNavigation();
      default:
        return _buildHomeView();
    }
  }

  Widget _buildHomeView() {
    return Consumer<OrderStatusProvider>(
      builder: (context, orderStatusProvider, child) {
        final stats = _getStats(orderStatusProvider);
        final activeDeliveries =
            _getActiveDeliveries(orderStatusProvider).take(3).toList();

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
                _buildStatisticsCards(stats, orderStatusProvider),
                SizedBox(height: 24),

                // Quick actions
                _buildQuickActions(),
                SizedBox(height: 24),

                // Active deliveries
                _buildActiveDeliveriesSection(
                    activeDeliveries, orderStatusProvider),
                SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
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

  Widget _buildStatisticsCards(
      Map<String, dynamic> stats, OrderStatusProvider orderStatusProvider) {
    return RiderStatisticsGrid(
      stats: stats,
      formatPrice: _formatPrice,
      onEarningsTap: () {
        Navigator.push(
          context,
          _createFadeRoute(const RiderEarningsScreen()),
        ).then((_) {
          _loadOrders(useCache: false);
        });
      },
    );
  }

  Widget _buildQuickActions() {
    return RiderQuickActions(
      onPickupMap: () {
        Navigator.push(
          context,
          _createFadeRoute(const RiderPickupMapScreen()),
        );
      },
      onDeliveryMap: () {
        Navigator.push(
          context,
          _createFadeRoute(const RiderDeliveryMapScreen()),
        );
      },
    );
  }

  Widget _buildActiveDeliveriesSection(List<Map<String, dynamic>> deliveries,
      OrderStatusProvider orderStatusProvider) {
    return ActiveDeliveriesSection(
      deliveries: deliveries,
      isLoading: _isLoadingOrders,
      error: _orderError,
      onRetry: () => _loadOrders(useCache: false),
      onViewAll: () {
        _navigateToDeliveries();
      },
      onUpdateStatus: (order) => _showUpdateStatusDialog(order),
      onViewDetails: (order) => _showOrderDetails(order),
      convertOrderToCardFormat: (order) =>
          _convertOrderToCardFormat(order, orderStatusProvider),
    );
  }

  void _navigateToDeliveries() {
    Navigator.push(
      context,
      _createFadeRoute(const RiderAllDeliveriesScreen()),
    ).then((result) {
      // Refresh orders when returning
      _loadOrders(useCache: false);
      // If a tab index was returned, switch to that tab
      if (result != null && result is int) {
        setState(() {
          _selectedIndex = result;
        });
      }
    });
  }

  Widget _buildHistoryView() {
    return Consumer<OrderStatusProvider>(
      builder: (context, orderStatusProvider, child) {
        final completedDeliveries =
            _getCompletedDeliveries(orderStatusProvider);

        return Column(
          children: [
            ViewHeader(
              title: 'Delivery History',
              onBack: () {
                _loadOrders(useCache: false);
                setState(() {
                  _selectedIndex = 0; // Switch to Home tab
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
                          final cardData = _convertOrderToCardFormat(
                              order, orderStatusProvider);

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
      },
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
          if (index == 1) {
            // Navigate to Deliveries screen
            _navigateToDeliveries();
            return;
          }
          // Reload API data when switching to Home or History tabs
          if (index != _selectedIndex && index != 3) {
            _loadOrders(useCache: false);
          }
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
    // Get order ID
    final orderId = order['order_id']?.toString() ?? order['id']?.toString();

    // Check if order is delivered and retrieve photo from Hive
    String? deliveryPhotoPath;
    final orderStatusProvider =
        Provider.of<OrderStatusProvider>(context, listen: false);
    final orderStatusId = order['order_status'];
    int? statusId;
    if (orderStatusId is int) {
      statusId = orderStatusId;
    } else if (orderStatusId is String) {
      statusId = int.tryParse(orderStatusId);
    } else if (orderStatusId != null) {
      statusId = int.tryParse(orderStatusId.toString());
    }

    final statusDesc = statusId != null
        ? orderStatusProvider.getOrderStatusDescription(statusId)?.toLowerCase()
        : null;
    final status = statusDesc ?? '';

    if (status == 'delivered' && orderId != null) {
      try {
        final box = Hive.box('delivery_photos');
        // Search for photo with matching orderId
        for (int i = 0; i < box.length; i++) {
          final photoData = box.getAt(i);
          if (photoData is Map && photoData['orderId'] == orderId) {
            final imagePath = photoData['imagePath']?.toString();
            if (imagePath != null && File(imagePath).existsSync()) {
              deliveryPhotoPath = imagePath;
              break;
            }
          }
        }
      } catch (e) {
        print('Error retrieving delivery photo: $e');
      }
    }

    showDialog(
      context: context,
      builder: (context) => OrderDetailsDialog(
        order: order,
        formatOrderDate: _formatOrderDate,
        formatPrice: _formatPrice,
        deliveryPhotoPath: deliveryPhotoPath,
      ),
    );
  }
}
