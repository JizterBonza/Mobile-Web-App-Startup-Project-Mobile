import 'package:flutter/material.dart';

import '../../constants/constants.dart';
import '../../services/order_service.dart';
import '../../utils/rider_nav.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/active_deliveries_section.dart';
import '../../widgets/delivery_acceptance_confirmation_dialog.dart';
import '../../widgets/delivery_accepted_dialog.dart';
import '../../widgets/incoming_delivery_section.dart';
import 'riderPickupMap.dart';

class RiderAllDeliveriesScreen extends StatefulWidget {
  const RiderAllDeliveriesScreen({super.key, this.orderService});

  final OrderService? orderService;

  @override
  State<RiderAllDeliveriesScreen> createState() =>
      _RiderAllDeliveriesScreenState();
}

class _RiderAllDeliveriesScreenState extends State<RiderAllDeliveriesScreen> {
  late final OrderService _orderService;
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _incomingOrders = [];
  int _activeCount = 0;
  int _incomingCount = 0;
  bool _isLoadingActive = true;
  bool _isLoadingIncoming = true;
  String? _activeError;
  String? _incomingError;
  int _selectedTab = 0;
  int _activeRequestId = 0;
  int _incomingRequestId = 0;
  final Set<String> _acceptingOrderIds = {};
  final Set<String> _acceptConfirmationOrderIds = {};

  int get _activeDisplayCount =>
      _activeCount > 0 ? _activeCount : _activeOrders.length;
  int get _incomingDisplayCount =>
      _incomingCount > 0 ? _incomingCount : _incomingOrders.length;

  @override
  void initState() {
    super.initState();
    _orderService = widget.orderService ?? OrderService();
    _loadBothTabs();
  }

  Future<void> _loadBothTabs() async {
    await Future.wait([_loadActiveDeliveries(), _loadIncomingDeliveries()]);
  }

  Future<void> _loadActiveDeliveries() async {
    if (!mounted) return;
    final requestId = ++_activeRequestId;
    setState(() {
      _isLoadingActive = true;
      _activeError = null;
    });
    try {
      final result = await _orderService.fetchActiveDeliveries();
      final orders = _ordersFrom(result['orders']);
      final count = _countFrom(result['count'], orders.length);
      if (!mounted || requestId != _activeRequestId) return;
      setState(() {
        _activeOrders = orders;
        _activeCount = count;
        _isLoadingActive = false;
      });
    } catch (error) {
      if (!mounted || requestId != _activeRequestId) return;
      setState(() {
        _activeOrders = [];
        _activeCount = 0;
        _isLoadingActive = false;
        _activeError = _errorMessage(error);
      });
    }
  }

  Future<void> _loadIncomingDeliveries() async {
    if (!mounted) return;
    final requestId = ++_incomingRequestId;
    setState(() {
      _isLoadingIncoming = true;
      _incomingError = null;
    });
    try {
      final result = await _orderService.fetchReadyForDeliveryOrders();
      final orders = _ordersFrom(result['orders']);
      final count = _countFrom(result['count'], orders.length);
      if (!mounted || requestId != _incomingRequestId) return;
      setState(() {
        _incomingOrders = orders;
        _incomingCount = count;
        _isLoadingIncoming = false;
      });
    } catch (error) {
      if (!mounted || requestId != _incomingRequestId) return;
      setState(() {
        _incomingOrders = [];
        _incomingCount = 0;
        _isLoadingIncoming = false;
        _incomingError = _errorMessage(error);
      });
    }
  }

  List<Map<String, dynamic>> _ordersFrom(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((order) => Map<String, dynamic>.from(order))
        .toList();
  }

  int _countFrom(dynamic value, int orderCount) {
    final parsed =
        value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed >= orderCount ? parsed : orderCount;
  }

  String _errorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'Unable to load deliveries.' : message;
  }

  Future<void> _continueActiveDelivery(Map<String, dynamic> order) async {
    final completed = await Navigator.push<bool>(
      context,
      _createFadeRoute(RiderPickupMapScreen(order: order)),
    );
    if (!mounted) return;
    await _loadBothTabs();
    if (!mounted || completed != true) return;
    SnackbarHelper.showSuccess(context, 'Delivery completed successfully.');
  }

  List<int>? _incomingOrderShopIds(Map<String, dynamic> order) {
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

  Future<void> _acceptIncomingDelivery(Map<String, dynamic> order) async {
    final parsedOrderId = int.tryParse(order['order_id']?.toString() ?? '');
    if (parsedOrderId == null || parsedOrderId <= 0) {
      SnackbarHelper.showError(context, 'Invalid order ID.');
      return;
    }
    final orderId = parsedOrderId.toString();
    final orderShopIds = _incomingOrderShopIds(order);
    if (orderShopIds == null) {
      SnackbarHelper.showError(
        context,
        'This order has invalid or missing pickup shop information.',
      );
      return;
    }
    if (_acceptingOrderIds.contains(orderId) ||
        _acceptConfirmationOrderIds.contains(orderId)) {
      return;
    }

    _acceptConfirmationOrderIds.add(orderId);
    final rawOrderCode = order['order_code']?.toString().trim() ?? '';
    final orderCode = rawOrderCode.replaceFirst(RegExp(r'^#+'), '').trim();
    final confirmed = await DeliveryAcceptanceConfirmationDialog.show(
      context,
      orderLabel: orderCode.isNotEmpty ? orderCode : 'this order',
      pickupStoreCount: orderShopIds.length,
    );
    _acceptConfirmationOrderIds.remove(orderId);
    if (!mounted || confirmed != true) return;
    setState(() => _acceptingOrderIds.add(orderId));

    try {
      final result = await _orderService.acceptReadyForDeliveryOrder(
        orderId: orderId,
        orderShopIds: orderShopIds,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        final refresh = _loadBothTabs();
        await DeliveryAcceptedDialog.show(context);
        await refresh;
      } else {
        SnackbarHelper.showError(
          context,
          result['message']?.toString() ?? 'Failed to accept delivery.',
        );
      }
    } catch (error) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Error accepting delivery: ${error.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _acceptingOrderIds.remove(orderId));
    }
  }

  PageRoute<T> _createFadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  void _onNavTap(int index) {
    handleRiderNavTap(
      context,
      targetIndex: index,
      currentIndex: RiderNavIndex.delivery,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text(
                'All Delivery',
                key: ValueKey('all-delivery-title'),
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 24,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            _DeliveryTabs(
              selectedIndex: _selectedTab,
              activeCount: _activeDisplayCount,
              incomingCount: _incomingDisplayCount,
              onSelected: (index) => setState(() => _selectedTab = index),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _DeliveryList(
                    key: const ValueKey('active-delivery-tab-view'),
                    type: _DeliveryListType.active,
                    orders: _activeOrders,
                    isLoading: _isLoadingActive,
                    error: _activeError,
                    onRefresh: _loadBothTabs,
                    onRetry: _loadActiveDeliveries,
                    onContinue: _continueActiveDelivery,
                  ),
                  _DeliveryList(
                    key: const ValueKey('incoming-delivery-tab-view'),
                    type: _DeliveryListType.incoming,
                    orders: _incomingOrders,
                    isLoading: _isLoadingIncoming,
                    error: _incomingError,
                    acceptingOrderIds: _acceptingOrderIds,
                    onRefresh: _loadBothTabs,
                    onRetry: _loadIncomingDeliveries,
                    onAccept: _acceptIncomingDelivery,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: buildRiderBottomNavigationBar(
        currentIndex: RiderNavIndex.delivery,
        onTap: _onNavTap,
      ),
    );
  }
}

class _DeliveryTabs extends StatelessWidget {
  const _DeliveryTabs({
    required this.selectedIndex,
    required this.activeCount,
    required this.incomingCount,
    required this.onSelected,
  });

  final int selectedIndex;
  final int activeCount;
  final int incomingCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 9),
      child: Row(
        children: [
          Expanded(
            child: _DeliveryTab(
              key: const ValueKey('active-delivery-tab'),
              label: 'Active Delivery',
              count: activeCount,
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _DeliveryTab(
              key: const ValueKey('incoming-delivery-tab'),
              label: 'Incoming Delivery',
              count: incomingCount,
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTab extends StatelessWidget {
  const _DeliveryTab({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border:
                selected ? Border.all(color: const Color(0xFFE1E1E1)) : null,
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                key: ValueKey(
                  label.startsWith('Active')
                      ? 'active-delivery-tab-count'
                      : 'incoming-delivery-tab-count',
                ),
                height: 18,
                constraints: const BoxConstraints(minWidth: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF05252),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DeliveryListType { active, incoming }

class _DeliveryList extends StatelessWidget {
  const _DeliveryList({
    super.key,
    required this.type,
    required this.orders,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onRetry,
    this.acceptingOrderIds = const {},
    this.onContinue,
    this.onAccept,
  });

  final _DeliveryListType type;
  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final Set<String> acceptingOrderIds;
  final ValueChanged<Map<String, dynamic>>? onContinue;
  final ValueChanged<Map<String, dynamic>>? onAccept;

  String get _prefix =>
      type == _DeliveryListType.active ? 'active' : 'incoming';

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          key: ValueKey('$_prefix-delivery-screen-loading'),
          color: type == _DeliveryListType.active
              ? const Color(0xFFF0A000)
              : const Color(0xFF0A8CFF),
        ),
      );
    }
    if (error != null) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primaryGreen,
        child: ListView(
          key: ValueKey('$_prefix-delivery-screen-error'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
          children: [
            const Icon(Icons.error_outline, size: 38, color: Color(0xFF999999)),
            const SizedBox(height: 10),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF737373), fontSize: 13),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                key: ValueKey('$_prefix-delivery-screen-retry'),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      );
    }
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primaryGreen,
        child: ListView(
          key: ValueKey('$_prefix-delivery-screen-empty'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
          children: [
            const Icon(Icons.inbox_outlined,
                size: 38, color: Color(0xFF999999)),
            const SizedBox(height: 10),
            Text(
              type == _DeliveryListType.active
                  ? 'No active deliveries'
                  : 'No incoming deliveries',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF737373), fontSize: 13),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primaryGreen,
      child: ListView.separated(
        key: ValueKey('$_prefix-delivery-screen-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 3, 16, 20),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];
          if (type == _DeliveryListType.active) {
            return ActiveDeliveryCard(
              order: order,
              fullWidth: true,
              onContinue: () => onContinue?.call(order),
            );
          }
          final orderId = order['order_id']?.toString() ?? '';
          return IncomingDeliveryCard(
            order: order,
            isAccepting: acceptingOrderIds.contains(orderId),
            fullWidth: true,
            onAccept: () => onAccept?.call(order),
          );
        },
      ),
    );
  }
}
