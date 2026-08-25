import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../constants/constants.dart';
import '../../services/order_service.dart';
import '../../services/api_service.dart';
import '../../provider/provider.dart';
import '../../utils/connectivity_helper.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/order_item_card.dart';
import '../../widgets/rider_statistics_grid.dart';
import '../../widgets/rider_quick_actions.dart';
import '../../widgets/incoming_delivery_section.dart';
import '../../widgets/delivery_acceptance_confirmation_dialog.dart';
import '../../widgets/delivery_accepted_dialog.dart';
import '../../widgets/active_deliveries_section.dart';
import '../../widgets/view_header.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/order_details_dialog.dart';
import '../common/profileScreen.dart';
import '../common/notificationScreen.dart';
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
  List<Map<String, dynamic>> _readyForDeliveryOrders = [];
  int _readyForDeliveryCount = 0;
  bool _hasLoadedReadyForDelivery = false;
  List<Map<String, dynamic>> _activeDeliveryOrders = [];
  int _activeDeliveryCount = 0;
  bool _isLoadingActiveDeliveries = true;
  String? _activeDeliveryError;
  final Set<String> _acceptingReadyForDeliveryOrderIds = {};
  final Set<String> _acceptConfirmationOrderIds = {};
  String? _userName;

  int get _incomingDeliveryDisplayCount => _readyForDeliveryCount > 0
      ? _readyForDeliveryCount
      : _readyForDeliveryOrders.length;
  int get _activeDeliveryDisplayCount => _activeDeliveryCount > 0
      ? _activeDeliveryCount
      : _activeDeliveryOrders.length;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    // Defer provider loads until after the build phase completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeOrderStatusProvider();
      _loadOrders();
      _loadReadyForDeliveryOrders();
      _loadActiveDeliveries();
      _loadBadges();
      _autoUploadPendingPods();
    });
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

  Future<void> _loadBadges() async {
    if (!mounted) return;
    try {
      await Provider.of<BadgeProvider>(context, listen: false).fetchBadges();
    } catch (e) {
      print('Error loading badges: $e');
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
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);

    // Use fetchRiderOrders to get orders assigned to this rider
    await ordersProvider.fetchRiderOrders(useCache: useCache);

    if (!mounted) return;
    setState(() {
      _allOrders = ordersProvider.orders;
    });
  }

  Future<void> _loadReadyForDeliveryOrders() async {
    if (!mounted) return;

    try {
      final result = await _orderService.fetchReadyForDeliveryOrders();
      final rawOrders = result['orders'];
      final orders = rawOrders is List
          ? rawOrders
              .whereType<Map>()
              .map((order) => Map<String, dynamic>.from(order))
              .toList()
          : <Map<String, dynamic>>[];
      final rawCount = result['count'];
      final count = rawCount is num
          ? rawCount.toInt()
          : int.tryParse(rawCount?.toString() ?? '') ?? orders.length;

      if (!mounted) return;
      setState(() {
        _readyForDeliveryOrders = orders;
        _readyForDeliveryCount = count;
        _hasLoadedReadyForDelivery = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _readyForDeliveryOrders = [];
        _readyForDeliveryCount = 0;
        _hasLoadedReadyForDelivery = true;
      });
    }
  }

  Future<void> _loadActiveDeliveries() async {
    if (!mounted) return;
    setState(() {
      _isLoadingActiveDeliveries = true;
      _activeDeliveryError = null;
    });

    try {
      final result = await _orderService.fetchActiveDeliveries();
      final rawOrders = result['orders'];
      final orders = rawOrders is List
          ? rawOrders
              .whereType<Map>()
              .map((order) => Map<String, dynamic>.from(order))
              .toList()
          : <Map<String, dynamic>>[];
      final rawCount = result['count'];
      final parsedCount = rawCount is num
          ? rawCount.toInt()
          : int.tryParse(rawCount?.toString() ?? '');
      final count = parsedCount != null && parsedCount >= orders.length
          ? parsedCount
          : orders.length;

      if (!mounted) return;
      setState(() {
        _activeDeliveryOrders = orders;
        _activeDeliveryCount = count;
        _isLoadingActiveDeliveries = false;
        _activeDeliveryError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activeDeliveryOrders = [];
        _activeDeliveryCount = 0;
        _isLoadingActiveDeliveries = false;
        _activeDeliveryError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<int>? _readyForDeliveryOrderShopIds(Map<String, dynamic> order) {
    final rawShops = order['available_order_shops'];
    if (rawShops is! List || rawShops.isEmpty) return null;

    final ids = <int>[];
    final seenIds = <int>{};
    for (final rawShop in rawShops) {
      if (rawShop is! Map) return null;
      final rawId = rawShop['order_shop_id'];
      final id =
          rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
      if (id == null || id <= 0) return null;
      if (seenIds.add(id)) ids.add(id);
    }

    return ids.isEmpty ? null : ids;
  }

  Future<void> _acceptReadyForDeliveryOrder(
    Map<String, dynamic> order,
  ) async {
    final parsedOrderId = int.tryParse(order['order_id']?.toString() ?? '');
    if (parsedOrderId == null || parsedOrderId <= 0) {
      SnackbarHelper.showError(context, 'Invalid order ID.');
      return;
    }

    final orderId = parsedOrderId.toString();
    final orderShopIds = _readyForDeliveryOrderShopIds(order);
    if (orderShopIds == null) {
      SnackbarHelper.showError(
        context,
        'This order has invalid or missing pickup shop information.',
      );
      return;
    }

    if (_acceptingReadyForDeliveryOrderIds.contains(orderId) ||
        _acceptConfirmationOrderIds.contains(orderId)) {
      return;
    }

    _acceptConfirmationOrderIds.add(orderId);
    final orderCode = order['order_code']?.toString().trim();
    final confirmed = await DeliveryAcceptanceConfirmationDialog.show(
      context,
      orderLabel: orderCode?.isNotEmpty == true ? orderCode! : 'this order',
      pickupStoreCount: orderShopIds.length,
    );
    _acceptConfirmationOrderIds.remove(orderId);

    if (!mounted || confirmed != true) return;
    setState(() {
      _acceptingReadyForDeliveryOrderIds.add(orderId);
    });

    try {
      final result = await _orderService.acceptReadyForDeliveryOrder(
        orderId: orderId,
        orderShopIds: orderShopIds,
      );
      if (!mounted) return;

      if (result['success'] == true) {
        final refreshFuture = Future.wait([
          _loadReadyForDeliveryOrders(),
          _loadActiveDeliveries(),
          _loadOrders(useCache: false),
        ]);
        await DeliveryAcceptedDialog.show(context);
        await refreshFuture;
      } else {
        SnackbarHelper.showError(
          context,
          result['message']?.toString() ?? 'Failed to accept delivery.',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Error accepting delivery: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _acceptingReadyForDeliveryOrderIds.remove(orderId);
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadOrders(useCache: false),
      _loadReadyForDeliveryOrders(),
      _loadActiveDeliveries(),
      _loadBadges(),
    ]);
    // Trigger automatic POD upload on refresh if internet is available
    _autoUploadPendingPods();
    await Future.delayed(Duration(milliseconds: 500));
  }

  PageRoute<T> _createFadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
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
    final totalDeliveries = _allOrders
        .map((o) => o['order_id']?.toString())
        .where((id) => id != null)
        .toSet()
        .length;
    final pendingDeliveries = _getPendingDeliveries(orderStatusProvider);
    final completedDeliveries = _getCompletedDeliveries(orderStatusProvider);

    final pendingCount = pendingDeliveries.length;
    final completedCount = completedDeliveries
        .map((o) => o['order_id']?.toString())
        .where((id) => id != null)
        .toSet()
        .length;

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
      'incoming': _incomingDeliveryDisplayCount,
      'active': _activeDeliveryDisplayCount,
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
      backgroundColor: AppColors.surfaceLight,
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
      default:
        return _buildHomeView();
    }
  }

  Widget _buildHomeView() {
    return Consumer<OrderStatusProvider>(
      builder: (context, orderStatusProvider, child) {
        final stats = _getStats(orderStatusProvider);

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primaryGreen,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: 20),
                _buildStatisticsCards(stats),
                SizedBox(height: 24),
                _buildActiveDeliveriesSection(),
                SizedBox(height: 24),
                if (_hasLoadedReadyForDelivery &&
                    _readyForDeliveryOrders.isNotEmpty) ...[
                  IncomingDeliverySection(
                    orders: _readyForDeliveryOrders,
                    count: _incomingDeliveryDisplayCount,
                    acceptingOrderIds: _acceptingReadyForDeliveryOrderIds,
                    onAccept: _acceptReadyForDeliveryOrder,
                  ),
                  SizedBox(height: 24),
                ],
                _buildQuickActions(),
                SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              _createFadeRoute(
                const ProfileScreen(hideBottomNavigation: true),
              ),
            );
          },
          child: SvgPicture.asset(
            'assets/icons/User.svg',
            width: 40,
            height: 40,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kumusta!',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.0,
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _userName ?? 'Rider',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        Consumer<BadgeProvider>(
          builder: (context, badges, _) {
            final badgeCount =
                BadgeProvider.formatBadgeCount(badges.unreadNotifications);
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  _createFadeRoute(const NotificationScreen()),
                ).then((_) {
                  _loadBadges();
                });
              },
              child: SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: SvgPicture.asset(
                        'assets/icons/notif.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                    if (badgeCount != null)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            badgeCount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatisticsCards(Map<String, dynamic> stats) {
    return RiderStatisticsGrid(
      stats: stats,
      onEarningsTap: () {
        _navigateToEarnings();
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
      onAllDeliveries: () {
        _navigateToDeliveries();
      },
      onEarnings: () {
        _navigateToEarnings();
      },
    );
  }

  Widget _buildActiveDeliveriesSection() {
    return ActiveDeliveriesSection(
      orders: _activeDeliveryOrders,
      count: _activeDeliveryDisplayCount,
      isLoading: _isLoadingActiveDeliveries,
      error: _activeDeliveryError,
      onRetry: _loadActiveDeliveries,
      onContinue: _continueActiveDelivery,
    );
  }

  Future<void> _continueActiveDelivery(Map<String, dynamic> order) async {
    final completed = await Navigator.push<bool>(
      context,
      _createFadeRoute(RiderPickupMapScreen(order: order)),
    );
    if (!mounted) return;
    await Future.wait([
      _loadActiveDeliveries(),
      _loadOrders(useCache: false),
    ]);
    if (!mounted || completed != true) return;
    SnackbarHelper.showSuccess(context, 'Delivery completed successfully.');
  }

  void _navigateToDeliveries() {
    Navigator.push(
      context,
      _createFadeRoute(const RiderAllDeliveriesScreen()),
    ).then((result) {
      if (!mounted) return;
      // Refresh orders when returning
      _loadOrders(useCache: false);
      // If a tab index was returned, route to that destination.
      if (result != null && result is int) {
        _handleNavigationTap(result, refreshOrders: false);
      }
    });
  }

  void _navigateToEarnings() {
    Navigator.push(
      context,
      _createFadeRoute(const RiderEarningsScreen()),
    ).then((result) {
      if (!mounted) return;
      _loadOrders(useCache: false);
      if (result != null && result is int) {
        _handleNavigationTap(result, refreshOrders: false);
      }
    });
  }

  void _handleNavigationTap(int index, {bool refreshOrders = true}) {
    if (index == 1) {
      _navigateToDeliveries();
      return;
    }

    if (index == 3) {
      _navigateToEarnings();
      return;
    }

    if (index != 0 && index != 2) return;

    if (refreshOrders && index != _selectedIndex) {
      _loadOrders(useCache: false);
    }
    setState(() {
      _selectedIndex = index;
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
                      color: AppColors.primaryGreen,
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
        onTap: _handleNavigationTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/home.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                Colors.grey[600]!,
                BlendMode.srcIn,
              ),
            ),
            activeIcon: SvgPicture.asset(
              'assets/icons/home.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.primaryGreen,
                BlendMode.srcIn,
              ),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/Delivered.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                Colors.grey[600]!,
                BlendMode.srcIn,
              ),
            ),
            activeIcon: SvgPicture.asset(
              'assets/icons/Delivered.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.primaryGreen,
                BlendMode.srcIn,
              ),
            ),
            label: 'Delivery',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/wallet.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                Colors.grey[600]!,
                BlendMode.srcIn,
              ),
            ),
            activeIcon: SvgPicture.asset(
              'assets/icons/wallet.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.primaryGreen,
                BlendMode.srcIn,
              ),
            ),
            label: 'Wallet',
          ),
        ],
      ),
    );
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
