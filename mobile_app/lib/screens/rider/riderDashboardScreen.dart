import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../services/order_service.dart';
import '../../services/api_service.dart';
import '../../provider/provider.dart';
import '../../utils/connectivity_helper.dart';
import '../../utils/rider_nav.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/rider_statistics_grid.dart';
import '../../widgets/rider_quick_actions.dart';
import '../../widgets/incoming_delivery_section.dart';
import '../../widgets/delivery_acceptance_confirmation_dialog.dart';
import '../../widgets/delivery_accepted_dialog.dart';
import '../../widgets/active_deliveries_section.dart';
import '../../widgets/empty_state_widget.dart';
import '../common/profileScreen.dart';
import '../common/notificationScreen.dart';
import 'riderPickupMap.dart';
import 'riderDeliveryMap.dart';
import 'riderAllDeliveriesScreen.dart';
import 'riderDeliveryHistoryDetailScreen.dart';
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
  final TextEditingController _historySearchController =
      TextEditingController();
  List<Map<String, dynamic>> _historyDeliveries = [];
  bool _isLoadingHistory = false;
  bool _hasLoadedHistory = false;
  String? _historyError;
  String _historySearchQuery = '';
  late int _historyMonth;
  late int _historyYear;
  String _historyStatus = 'all';
  int _historyRequestId = 0;
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
    final now = DateTime.now();
    _historyMonth = now.month;
    _historyYear = now.year;
    riderDashboardTab.reset();
    riderDashboardTab.addListener(_syncRequestedTab);
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

  @override
  void dispose() {
    riderDashboardTab.removeListener(_syncRequestedTab);
    _historySearchController.dispose();
    super.dispose();
  }

  /// A route above the dashboard asked for one of the dashboard-hosted tabs.
  void _syncRequestedTab() {
    if (!mounted) return;
    _loadOrders(useCache: false);
    _handleNavigationTap(riderDashboardTab.index, refreshOrders: false);
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

  Future<void> _loadDeliveryHistory() async {
    if (!mounted) return;
    final requestId = ++_historyRequestId;
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final result = await _orderService.fetchRiderDeliveryHistory(
        month: _historyMonth,
        year: _historyYear,
        status: _historyStatus,
      );
      final rawDeliveries = result['deliveries'];
      final deliveries = rawDeliveries is List
          ? rawDeliveries
              .whereType<Map>()
              .map((delivery) => Map<String, dynamic>.from(delivery))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted || requestId != _historyRequestId) return;
      setState(() {
        _historyDeliveries = deliveries;
        _isLoadingHistory = false;
        _hasLoadedHistory = true;
        _historyError = null;
      });
    } catch (error) {
      if (!mounted || requestId != _historyRequestId) return;
      setState(() {
        _historyDeliveries = [];
        _isLoadingHistory = false;
        _hasLoadedHistory = true;
        _historyError = error.toString().replaceFirst('Exception: ', '').trim();
      });
    }
  }

  void _selectHistoryMonth(int month) {
    if (month == _historyMonth) return;
    setState(() => _historyMonth = month);
    _loadDeliveryHistory();
  }

  void _selectHistoryYear(int year) {
    if (year == _historyYear) return;
    setState(() => _historyYear = year);
    _loadDeliveryHistory();
  }

  void _selectHistoryStatus(String status) {
    if (status == _historyStatus) return;
    setState(() => _historyStatus = status);
    _loadDeliveryHistory();
  }

  List<Map<String, dynamic>> get _visibleHistoryDeliveries {
    final query = _historySearchQuery.trim().toLowerCase();
    if (query.isEmpty) return _historyDeliveries;
    return _historyDeliveries.where((delivery) {
      final orderCode = delivery['order_code']?.toString().toLowerCase() ?? '';
      final recipient =
          delivery['recipient_name']?.toString().toLowerCase() ?? '';
      return orderCode.contains(query) || recipient.contains(query);
    }).toList();
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
                _buildQuickActions(),
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
                _buildActiveDeliveriesSection(),
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
    _pushRiderTab(const RiderAllDeliveriesScreen());
  }

  void _navigateToEarnings() {
    _pushRiderTab(const RiderEarningsScreen());
  }

  /// Nav taps on the pushed tab routes report back through
  /// [riderDashboardTab], so only an unannounced exit (system back) has to
  /// refresh here.
  void _pushRiderTab(Widget screen) {
    Navigator.push(context, riderFadeRoute(screen)).then((result) {
      if (!mounted || result != null) return;
      _loadOrders(useCache: false);
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

    final isChangingTab = index != _selectedIndex;
    if (refreshOrders && index == 0 && isChangingTab) {
      _loadOrders(useCache: false);
    }
    setState(() {
      _selectedIndex = index;
    });
    if (index == 2 && (isChangingTab || !_hasLoadedHistory)) {
      _loadDeliveryHistory();
    }
  }

  Widget _buildHistoryView() {
    final historyDeliveries = _visibleHistoryDeliveries;

    return ColoredBox(
      color: const Color(0xFFF4F4F4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'Delivery History',
              key: ValueKey('delivery-history-title'),
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 24,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DeliveryHistoryControls(
              searchController: _historySearchController,
              month: _historyMonth,
              year: _historyYear,
              status: _historyStatus,
              enabled: !_isLoadingHistory,
              onSearchChanged: (query) {
                setState(() => _historySearchQuery = query);
              },
              onMonthChanged: _selectHistoryMonth,
              onYearChanged: _selectHistoryYear,
              onStatusChanged: _selectHistoryStatus,
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: _isLoadingHistory
                ? const Center(
                    child: CircularProgressIndicator(
                      key: ValueKey('delivery-history-loading'),
                      color: AppColors.primaryGreenLight,
                    ),
                  )
                : _historyError != null
                    ? EmptyStateWidget(
                        icon: Icons.cloud_off_outlined,
                        message: 'Unable to load delivery history',
                        subtitle: _historyError,
                        action: ElevatedButton(
                          key: const ValueKey('delivery-history-retry'),
                          onPressed: _loadDeliveryHistory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreenLight,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      )
                    : historyDeliveries.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.history_outlined,
                            message: _historySearchQuery.trim().isEmpty
                                ? 'No deliveries found'
                                : 'No matching deliveries',
                          )
                        : RefreshIndicator(
                            onRefresh: _loadDeliveryHistory,
                            color: AppColors.primaryGreenLight,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                              itemCount: historyDeliveries.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final delivery = historyDeliveries[index];
                                final orderCode = _historyOrderCode(
                                  delivery['order_code'],
                                );

                                return _DeliveryHistoryCard(
                                  key: ValueKey(
                                    'delivery-history-card-$orderCode-$index',
                                  ),
                                  orderCode: orderCode,
                                  date: _formatHistoryDate(delivery),
                                  customer: delivery['recipient_name']
                                          ?.toString()
                                          .trim() ??
                                      '',
                                  address: _historyAddress(delivery),
                                  pickupStoreCount:
                                      _historyPickupStoreCount(delivery),
                                  itemCount: _historyItemCount(delivery),
                                  status: _historyStatusLabel(delivery),
                                  onTap: () =>
                                      _openDeliveryHistoryDetail(delivery),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  String _historyStatusLabel(Map<String, dynamic> delivery) {
    final rawStatus = delivery['status'];
    if (rawStatus is Map) {
      final label = rawStatus['label']?.toString().trim() ?? '';
      if (label.isNotEmpty) return label;
      final key = rawStatus['key']?.toString().trim() ?? '';
      if (key.isNotEmpty) return key;
    }
    final label = delivery['status_label']?.toString().trim() ?? '';
    if (label.isNotEmpty) return label;
    return rawStatus?.toString().trim() ?? '';
  }

  String _historyAddress(Map<String, dynamic> delivery) {
    final address = delivery['delivery_address']?.toString().trim() ?? '';
    return address.isEmpty ? 'Delivery address unavailable' : address;
  }

  int _historyPickupStoreCount(Map<String, dynamic> delivery) {
    return int.tryParse(delivery['pickup_store_count']?.toString() ?? '') ?? 0;
  }

  int _historyItemCount(Map<String, dynamic> delivery) {
    return int.tryParse(delivery['item_count']?.toString() ?? '') ?? 0;
  }

  void _openDeliveryHistoryDetail(Map<String, dynamic> delivery) {
    final orderId = int.tryParse(delivery['order_id']?.toString() ?? '');
    if (orderId == null || orderId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This delivery has an invalid order ID.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      _createFadeRoute(
        RiderDeliveryHistoryDetailScreen(orderId: orderId),
      ),
    );
  }

  String _historyOrderCode(dynamic value) {
    final code = value?.toString().trim() ?? '';
    if (code.isEmpty || code == 'N/A') return 'ORDER';
    return code.startsWith('#') ? code.substring(1) : code;
  }

  String _formatHistoryDate(Map<String, dynamic> order) {
    final raw =
        (order['delivered_at'] ?? order['updated_at'] ?? order['ordered_at'])
            ?.toString()
            .trim();
    final date = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (date == null) {
      return raw?.isNotEmpty == true ? raw! : 'Date unavailable';
    }

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final meridiem = date.hour < 12 ? 'am' : 'pm';
    return '${months[date.month - 1]} ${date.day}, ${date.year} '
        '• $hour:$minute$meridiem';
  }

  Widget _buildBottomNavigationBar() {
    return buildRiderBottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _handleNavigationTap,
    );
  }
}

class _DeliveryHistoryControls extends StatelessWidget {
  const _DeliveryHistoryControls({
    required this.searchController,
    required this.month,
    required this.year,
    required this.status,
    required this.enabled,
    required this.onSearchChanged,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final int month;
  final int year;
  final String status;
  final bool enabled;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<String> onStatusChanged;

  static const _months = <int, String>{
    1: 'Jan',
    2: 'Feb',
    3: 'Mar',
    4: 'Apr',
    5: 'May',
    6: 'Jun',
    7: 'Jul',
    8: 'Aug',
    9: 'Sep',
    10: 'Oct',
    11: 'Nov',
    12: 'Dec',
  };

  @override
  Widget build(BuildContext context) {
    final latestYear = DateTime.now().year + 1;
    final years = <int>{
      for (var value = 2020; value <= latestYear; value++) value,
      year,
    }.toList()
      ..sort((left, right) => right.compareTo(left));

    return Column(
      children: [
        Container(
          key: const ValueKey('delivery-history-search'),
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFD8D8D8)),
          ),
          child: TextField(
            controller: searchController,
            enabled: enabled,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              color: Color(0xFF222222),
              fontSize: 12,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: Color(0xFF9A9A9A),
              ),
              prefixIconConstraints: BoxConstraints(
                minWidth: 38,
                minHeight: 40,
              ),
              hintText: 'Search order number or customer',
              hintStyle: TextStyle(
                color: Color(0xFF8D8D8D),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _HistorySelect<int>(
                key: const ValueKey('delivery-history-month'),
                value: month,
                enabled: enabled,
                items: _months,
                onChanged: onMonthChanged,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _HistorySelect<int>(
                key: const ValueKey('delivery-history-year'),
                value: year,
                enabled: enabled,
                items: {for (final value in years) value: value.toString()},
                onChanged: onYearChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _HistoryFilter(
                label: 'All',
                value: 'all',
                selected: status == 'all',
                enabled: enabled,
                onSelected: onStatusChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HistoryFilter(
                label: 'Delivered',
                value: 'delivered',
                selected: status == 'delivered',
                enabled: enabled,
                onSelected: onStatusChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HistoryFilter(
                label: 'Failed',
                value: 'failed',
                selected: status == 'failed',
                enabled: enabled,
                onSelected: onStatusChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HistorySelect<T> extends StatelessWidget {
  const _HistorySelect({
    super.key,
    required this.value,
    required this.enabled,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final bool enabled;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD8D8D8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: Color(0xFF111111),
          ),
          style: const TextStyle(
            color: Color(0xFF8A8A8A),
            fontSize: 12,
          ),
          items: items.entries
              .map(
                (entry) => DropdownMenuItem<T>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (selected) {
                  if (selected != null) onChanged(selected);
                }
              : null,
        ),
      ),
    );
  }
}

class _HistoryFilter extends StatelessWidget {
  const _HistoryFilter({
    required this.label,
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final String value;
  final bool selected;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('delivery-history-$value-filter'),
        onTap: enabled ? () => onSelected(value) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 31,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryGreenLight : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border:
                selected ? null : Border.all(color: const Color(0xFFD8D8D8)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF777777),
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryHistoryCard extends StatelessWidget {
  const _DeliveryHistoryCard({
    super.key,
    required this.orderCode,
    required this.date,
    required this.customer,
    required this.address,
    required this.pickupStoreCount,
    required this.itemCount,
    required this.status,
    required this.onTap,
  });

  final String orderCode;
  final String date;
  final String customer;
  final String address;
  final int pickupStoreCount;
  final int itemCount;
  final String status;
  final VoidCallback onTap;

  bool get _isFailed {
    final value = status.toLowerCase();
    return value.contains('fail') ||
        value.contains('cancel') ||
        value.contains('return');
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = _isFailed ? 'Failed' : 'Delivered';
    final statusColor =
        _isFailed ? const Color(0xFFFF334F) : const Color(0xFF149755);
    final statusFill =
        _isFailed ? const Color(0xFFFFF0F2) : const Color(0xFFE1F7EA);
    final statusBorder =
        _isFailed ? const Color(0xFFFF6378) : const Color(0xFF77D4A0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDDDDDD)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 16,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 10,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 60),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusBorder, width: 0.7),
                    ),
                    child: Text(
                      statusLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 23),
              _HistoryDetailLine(
                icon: Icons.person,
                text: customer.isEmpty ? 'Unknown Customer' : customer,
              ),
              const SizedBox(height: 8),
              _HistoryDetailLine(
                icon: Icons.location_on,
                text: address,
              ),
              const SizedBox(height: 8),
              _HistoryDetailLine(
                icon: Icons.store,
                text: '$pickupStoreCount pickup '
                    '${pickupStoreCount == 1 ? 'store' : 'stores'} '
                    '• $itemCount ${itemCount == 1 ? 'item' : 'items'}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryDetailLine extends StatelessWidget {
  const _HistoryDetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFFA2A2A2)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
