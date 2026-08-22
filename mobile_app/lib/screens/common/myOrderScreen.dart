import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../provider/orders_provider.dart';
import '../../provider/order_status_provider.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../services/shops_service.dart';
import '../../services/api_service.dart';
import '../../utils/customer_nav.dart';
import '../../utils/media_url.dart';
import '../../widgets/order/order_helpers.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import 'orderDetailScreen.dart';

class MyOrderScreen extends StatefulWidget {
  final bool showCustomerBottomNav;

  const MyOrderScreen({super.key, this.showCustomerBottomNav = false});

  @override
  State<MyOrderScreen> createState() => _MyOrderScreenState();
}

class _MyOrderScreenState extends State<MyOrderScreen>
    with SingleTickerProviderStateMixin {
  static const Color _statusNavActive = Color(0xFF1D7546);
  static const Color _statusNavInactive = Color(0xFF6B7280);

  late TabController _tabController;
  final OrderService _orderService = OrderService();
  final ShopsService _shopsService = ShopsService();
  bool _isCancelling = false;
  bool _isGuest = true;
  Map<String, String> _paymentMethodNames = {};

  final List<Map<String, dynamic>> _statusTabs = [
    {
      'label': 'All',
      'status': null,
      'icon': 'assets/icons/orders.svg',
    },
    {
      'label': 'Pending',
      'status': 'pending',
      'icon': 'assets/icons/Pending.svg',
    },
    {
      'label': 'Preparing',
      'status': 'processing',
      'icon': 'assets/icons/Preparing.svg',
    },
    {
      'label': 'To Deliver',
      'status': 'in-transit',
      'icon': 'assets/icons/Deliver.svg',
    },
    {
      'label': 'Delivered',
      'status': 'delivered',
      'icon': 'assets/icons/Delivered.svg',
    },
    {
      'label': 'Cancelled',
      'status': 'cancelled',
      'icon': 'assets/icons/Cancelled.svg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGuestState();
      _ensureOrderStatuses();
      _loadOrders();
      _loadPaymentMethodNames();
    });
  }

  Future<void> _ensureOrderStatuses() async {
    try {
      final orderStatusProvider =
          Provider.of<OrderStatusProvider>(context, listen: false);
      await orderStatusProvider.fetchAndCacheOrderStatuses();
    } catch (e) {
      print('Error loading order statuses: $e');
    }
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadGuestState() async {
    try {
      final token = await ApiService.getToken();
      if (!mounted) return;
      setState(() {
        _isGuest = token == null || token.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _isGuest = true);
    }
  }

  Future<void> _loadPaymentMethodNames() async {
    final names = await PaymentService.getPaymentMethodNames();
    if (mounted) setState(() => _paymentMethodNames = names);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool useCache = true}) async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    await ordersProvider.fetchOrders(useCache: useCache);
  }

  Future<void> _onRefresh() async {
    await _loadOrders(useCache: false);
  }

  List<Map<String, dynamic>> _filterOrdersByStatus(
      List<Map<String, dynamic>> orders, String? status) {
    if (status == null) return orders;

    final orderStatusProvider =
        Provider.of<OrderStatusProvider>(context, listen: false);

    return orders.where((order) {
      // Parse order_status as ID (number)
      final orderStatusId = order['order_status'];
      int? statusId;
      if (orderStatusId is int) {
        statusId = orderStatusId;
      } else if (orderStatusId is String) {
        statusId = int.tryParse(orderStatusId);
      } else if (orderStatusId != null) {
        statusId = int.tryParse(orderStatusId.toString());
      }

      // Get status description from provider
      final orderStatusDesc = statusId != null
          ? orderStatusProvider
              .getOrderStatusDescription(statusId)
              ?.toLowerCase()
          : null;

      // Compare with filter status
      if (orderStatusDesc != null) {
        return orderStatusDesc == status.toLowerCase();
      }

      // Fallback: if provider lookup fails, try direct comparison
      final orderStatus = orderStatusId?.toString().toLowerCase() ?? '';
      return orderStatus == status.toLowerCase();
    }).toList();
  }

  String _formatOrderDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.tryParse(dateString);
      if (dateTime != null) {
        final months = [
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
          'December'
        ];
        var hour = dateTime.hour % 12;
        if (hour == 0) hour = 12;
        final period = dateTime.hour >= 12 ? 'pm' : 'am';
        final minute = dateTime.minute.toString().padLeft(2, '0');
        return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} • $hour:$minute$period';
      }
    } catch (e) {
      print('Error formatting date: $e');
    }
    return dateString;
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '₱0';
    try {
      final parsed =
          price is num ? price.toDouble() : double.tryParse(price.toString());
      if (parsed == null) return '₱0';
      if (parsed == parsed.roundToDouble()) {
        return '₱${parsed.toStringAsFixed(0)}';
      }
      return '₱${parsed.toStringAsFixed(2)}';
    } catch (e) {
      print('Error formatting price: $e');
    }
    return '₱0';
  }

  /// Reads zone title from order_shops[].shop.zone.name
  String _resolveZoneTitle(Map<String, dynamic> order) {
    final orderShops = order['order_shops'] as List? ?? [];
    for (final raw in orderShops) {
      if (raw is! Map) continue;
      final entry = Map<String, dynamic>.from(raw);
      final shop = entry['shop'] as Map<String, dynamic>?;
      final zone = shop?['zone'] as Map<String, dynamic>? ??
          entry['zone'] as Map<String, dynamic>?;
      final zoneName = zone?['name']?.toString().trim();
      if (zoneName != null && zoneName.isNotEmpty) {
        return zoneName.toLowerCase().startsWith('zone')
            ? zoneName
            : 'Zone $zoneName';
      }
    }
    return 'Order';
  }

  /// Groups order_items by shop, using order_shops[].shop for names/ids.
  List<Map<String, dynamic>> _groupItemsByShop(
    List orderItems, {
    List? orderShops,
  }) {
    final shopNameById = <String, String>{};
    for (final raw in orderShops ?? const []) {
      if (raw is! Map) continue;
      final entry = Map<String, dynamic>.from(raw);
      final shop = entry['shop'] as Map<String, dynamic>?;
      final id = entry['shop_id']?.toString() ?? shop?['id']?.toString();
      final name = shop?['shop_name']?.toString() ?? entry['shop_name']?.toString();
      if (id != null && name != null && name.trim().isNotEmpty) {
        shopNameById[id] = name.trim();
      }
    }

    final groups = <String, Map<String, dynamic>>{};
    for (final raw in orderItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final nestedItem = item['item'] as Map<String, dynamic>?;
      final shop = item['shop'] as Map<String, dynamic>? ??
          nestedItem?['shop'] as Map<String, dynamic>?;
      final shopId = shop?['id']?.toString() ??
          nestedItem?['shop_id']?.toString() ??
          item['shop_id']?.toString() ??
          (shopNameById.length == 1 ? shopNameById.keys.first : 'unknown');
      final shopName = shop?['shop_name']?.toString() ??
          nestedItem?['shop_name']?.toString() ??
          item['shop_name']?.toString() ??
          shopNameById[shopId] ??
          (shopNameById.isNotEmpty ? shopNameById.values.first : 'Shop');

      groups.putIfAbsent(
        shopId,
        () => {
          'shop_id': shopId,
          'shop_name': shopName,
          'items': <Map<String, dynamic>>[],
        },
      );
      (groups[shopId]!['items'] as List<Map<String, dynamic>>).add(item);
    }

    // If items lacked shop ids but order_shops exist, still show shops with items
    if (groups.isEmpty && shopNameById.isNotEmpty && orderItems.isNotEmpty) {
      final firstId = shopNameById.keys.first;
      return [
        {
          'shop_id': firstId,
          'shop_name': shopNameById[firstId],
          'items': orderItems
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        }
      ];
    }

    // No items but shops exist — still show shop sections empty
    if (groups.isEmpty && shopNameById.isNotEmpty) {
      return shopNameById.entries
          .map((e) => {
                'shop_id': e.key,
                'shop_name': e.value,
                'items': <Map<String, dynamic>>[],
              })
          .toList();
    }

    return groups.values.toList();
  }

  String _itemVariantLabel(Map<String, dynamic> item) {
    final nestedItem = item['item'] as Map<String, dynamic>?;
    for (final value in [
      item['variant'],
      item['variation'],
      item['size'],
      item['unit'],
      item['item_size'],
      nestedItem?['variant'],
      nestedItem?['variation'],
      nestedItem?['size'],
      nestedItem?['unit'],
      nestedItem?['item_size'],
    ]) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String? _itemImageUrl(Map<String, dynamic> item) {
    final nestedItem = item['item'] as Map<String, dynamic>?;
    final raw = nestedItem?['item_images'] ??
        item['item_images'] ??
        nestedItem?['item_image'] ??
        item['item_image'];
    return resolveItemImageUrl(raw);
  }

  Future<void> _openOrderDetails(Map<String, dynamic> order) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(order: order),
      ),
    );
    if (result == true) {
      _loadOrders(useCache: false);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 28),
            SizedBox(width: 12),
            Text('Cancel Order'),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
          style: TextStyle(color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No, Keep It',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final result = await _orderService.cancelOrder(orderId);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Order cancelled successfully'),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        // Refresh orders list
        await _loadOrders(useCache: false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                    child: Text(result['message'] ?? 'Failed to cancel order')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('An error occurred'),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _showRateOrderDialog(String orderId, String shopId, List orderItems) {
    int selectedRating = 0;
    bool isSubmitting = false;
    final TextEditingController reviewController = TextEditingController();

    // Get item ID from first order item if available
    int? itemId;
    if (orderItems.isNotEmpty) {
      final firstItem = orderItems.first;
      final nestedItem = firstItem['item'] as Map<String, dynamic>?;
      itemId = nestedItem?['id'] ?? firstItem['item_id'] ?? firstItem['id'];
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.accentAmber, size: 28),
              SizedBox(width: 12),
              Text('Rate Your Order'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How was your experience with this order?',
                style: TextStyle(color: Colors.grey[700]),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: isSubmitting
                        ? null
                        : () {
                            setDialogState(() {
                              selectedRating = index + 1;
                            });
                          },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        index < selectedRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 40,
                        color: AppColors.accentAmber,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 8),
              Text(
                selectedRating == 0
                    ? 'Tap to rate'
                    : selectedRating == 1
                        ? 'Poor'
                        : selectedRating == 2
                            ? 'Fair'
                            : selectedRating == 3
                                ? 'Good'
                                : selectedRating == 4
                                    ? 'Very Good'
                                    : 'Excellent',
                style: TextStyle(
                  color: selectedRating == 0
                      ? Colors.grey[500]
                      : AppColors.accentAmberDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: reviewController,
                maxLines: 3,
                enabled: !isSubmitting,
                decoration: InputDecoration(
                  hintText: 'Write a review (optional)',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppColors.primaryGreen, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: selectedRating == 0 || isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);

                      // Get user ID from ApiService
                      final userIdStr = await ApiService.getUserId();
                      final userId = int.tryParse(userIdStr ?? '');
                      if (userId == null) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('Please login to submit a review'),
                              ],
                            ),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        );
                        return;
                      }

                      // Submit review to backend
                      final result = await _shopsService.submitReview(
                        shopId: shopId,
                        userId: userId,
                        rating: selectedRating,
                        orderId: int.tryParse(orderId),
                        itemId: itemId,
                        reviewText: reviewController.text.trim().isEmpty
                            ? null
                            : reviewController.text.trim(),
                      );

                      Navigator.pop(dialogContext);

                      if (result['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('Thank you for your rating!'),
                              ],
                            ),
                            backgroundColor: AppColors.primaryGreen,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(result['message'] ??
                                      'Failed to submit review'),
                                ),
                              ],
                            ),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentAmber,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isSubmitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(
          'My Orders',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[700]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: _buildStatusNav(),
        ),
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, ordersProvider, child) {
          if (ordersProvider.isLoading && ordersProvider.orders.isEmpty) {
            return _buildLoadingState();
          }

          return TabBarView(
            controller: _tabController,
            children: _statusTabs.map((tab) {
              final filteredOrders = _filterOrdersByStatus(
                ordersProvider.orders,
                tab['status'] as String?,
              );
              return _buildOrdersList(filteredOrders, ordersProvider.error);
            }).toList(),
          );
        },
      ),
      bottomNavigationBar: widget.showCustomerBottomNav
          ? buildCustomerBottomNavigationBar(
              context: context,
              currentIndex: CustomerNavIndex.orders,
              isGuest: _isGuest,
              onLoginSuccess: () {
                _loadGuestState();
                _loadOrders(useCache: false);
              },
            )
          : null,
    );
  }

  Widget _buildStatusNav() {
    return Container(
      color: AppColors.surfaceLight,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: List.generate(_statusTabs.length, (index) {
            final tab = _statusTabs[index];
            final isSelected = _tabController.index == index;
            final color =
                isSelected ? _statusNavActive : _statusNavInactive;
            final iconPath = tab['icon'] as String?;

            return Expanded(
              child: InkWell(
                onTap: () => _tabController.animateTo(index),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 24,
                        child: iconPath == null
                            ? const SizedBox.shrink()
                            : SvgPicture.asset(
                                iconPath,
                                height: 22,
                                fit: BoxFit.contain,
                                colorFilter: ColorFilter.mode(
                                  color,
                                  BlendMode.srcIn,
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab['label'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const OrderListSkeleton();
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders, String? error) {
    if (orders.isEmpty) {
      return _buildEmptyState(error);
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primaryGreen,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(orders[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState(String? error) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primaryGreen,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    error != null
                        ? Icons.error_outline
                        : Icons.receipt_long_outlined,
                    size: 64,
                    color:
                        error != null ? AppColors.error : AppColors.primaryGreen,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  error != null ? 'Failed to load orders' : 'No orders found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    error != null
                        ? 'Please check your connection and try again'
                        : 'Your orders will appear here once you make a purchase',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (error != null) ...[
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _onRefresh,
                    icon: Icon(Icons.refresh, size: 20),
                    label: Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Consumer<OrderStatusProvider>(
      builder: (context, orderStatusProvider, child) {
        final orderCode = order['order_code']?.toString() ?? 'N/A';

        final orderStatusId = order['order_status'];
        int? statusId;
        if (orderStatusId is int) {
          statusId = orderStatusId;
        } else if (orderStatusId is String) {
          statusId = int.tryParse(orderStatusId);
        } else if (orderStatusId != null) {
          statusId = int.tryParse(orderStatusId.toString());
        }

        final orderStatusDesc = statusId != null
            ? orderStatusProvider.getOrderStatusDescription(statusId)
            : null;
        final orderStatus = orderStatusDesc ?? 'Pending';

        final totalAmount = OrderHelpers.orderField(order, 'total_amount');
        final subtotal = OrderHelpers.orderField(order, 'subtotal');
        final shippingFee = OrderHelpers.orderFeeAmount(order, 'shipping_fee');
        final totalFees = OrderHelpers.orderFeeAmount(order, 'total_fees');
        final handlingFee = shippingFee > 0 ? shippingFee : totalFees;
        final platformDiscount = OrderHelpers.orderFeeAmount(
                  order,
                  'voucher_discount_amount',
                ) >
                0
            ? OrderHelpers.orderFeeAmount(order, 'voucher_discount_amount')
            : OrderHelpers.orderFeeAmount(order, 'platform_discount');
        final shopDiscount =
            OrderHelpers.orderFeeAmount(order, 'shop_discount') > 0
                ? OrderHelpers.orderFeeAmount(order, 'shop_discount')
                : OrderHelpers.orderFeeAmount(order, 'shop_discount_amount');
        final orderedAt = order['ordered_at']?.toString() ?? '';

        final payment = order['payment'] as Map<String, dynamic>?;
        final rawPaymentMethod = payment?['payment_method']?.toString() ?? '';
        final paymentMethod = rawPaymentMethod.isNotEmpty
            ? (_paymentMethodNames[rawPaymentMethod] ?? rawPaymentMethod)
            : '';
        final paymentStatus = OrderHelpers.resolvePaymentStatus(order);
        final orderId =
            order['id']?.toString() ?? order['order_id']?.toString() ?? '';
        final orderItems = order['order_items'] as List? ?? [];
        final orderShops = order['order_shops'] as List? ?? [];
        final shopGroups = _groupItemsByShop(
          orderItems,
          orderShops: orderShops,
        );

        String shopId = '';
        if (orderShops.isNotEmpty && orderShops.first is Map) {
          final firstShop = Map<String, dynamic>.from(orderShops.first as Map);
          final nested = firstShop['shop'] as Map<String, dynamic>?;
          shopId = firstShop['shop_id']?.toString() ??
              nested?['id']?.toString() ??
              '';
        }
        if (shopId.isEmpty && orderItems.isNotEmpty) {
          final firstItem = orderItems.first;
          if (firstItem is Map) {
            final nestedItem = firstItem['item'] as Map<String, dynamic>?;
            shopId = nestedItem?['shop_id']?.toString() ??
                firstItem['shop_id']?.toString() ??
                '';
          }
        }

        final canCancel = orderStatus.toLowerCase() == 'pending';
        final isDelivered = orderStatus.toLowerCase() == 'delivered';
        final zoneTitle = _resolveZoneTitle(order);
        final itemsSubtotal = orderItems.fold<double>(0, (sum, raw) {
          if (raw is! Map) return sum;
          final nestedItem = raw['item'] as Map<String, dynamic>?;
          final price = raw['price'] ??
              raw['item_price'] ??
              nestedItem?['item_price'] ??
              raw['price_at_purchase'] ??
              0;
          final qty = int.tryParse(raw['quantity']?.toString() ?? '1') ?? 1;
          final unit = price is num
              ? price.toDouble()
              : double.tryParse(price.toString()) ?? 0;
          return sum + (unit * qty);
        });

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        zoneTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        ),
                      ),
                    ),
                    Text(
                      'No: $orderCode',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatOrderDate(orderedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 14),
                ...shopGroups.map((group) {
                  final items = group['items'] as List<Map<String, dynamic>>;
                  final groupCount = items.length;
                  final groupSubtotal = items.fold<double>(0, (sum, raw) {
                    final nestedItem = raw['item'] as Map<String, dynamic>?;
                    final price = raw['price'] ??
                        raw['item_price'] ??
                        nestedItem?['item_price'] ??
                        raw['price_at_purchase'] ??
                        0;
                    final qty =
                        int.tryParse(raw['quantity']?.toString() ?? '1') ?? 1;
                    final unit = price is num
                        ? price.toDouble()
                        : double.tryParse(price.toString()) ?? 0;
                    return sum + (unit * qty);
                  });
                  final singleShop = shopGroups.length == 1;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Text(
                              group['shop_name']?.toString() ?? 'Shop',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1D7546),
                              ),
                            ),
                          ),
                          ...items.map(_buildOrderItemRow),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildCompactRow(
                                  '$groupCount item${groupCount == 1 ? '' : 's'}',
                                  _formatPrice(
                                    singleShop
                                        ? (subtotal ?? groupSubtotal)
                                        : groupSubtotal,
                                  ),
                                ),
                                if (singleShop && shopDiscount > 0) ...[
                                  const SizedBox(height: 6),
                                  _buildCompactRow(
                                    'Shop Discount',
                                    _formatPrice(shopDiscount),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (shopGroups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No items found',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildCompactRow(
                        'Subtotal',
                        _formatPrice(subtotal ?? itemsSubtotal),
                      ),
                      if (handlingFee > 0) ...[
                        const SizedBox(height: 8),
                        _buildCompactRow(
                          'Handling Fee',
                          _formatPrice(handlingFee),
                        ),
                      ],
                      if (platformDiscount > 0) ...[
                        const SizedBox(height: 8),
                        _buildCompactRow(
                          'Platform Discount',
                          _formatPrice(platformDiscount),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildCompactRow(
                        'Total',
                        _formatPrice(totalAmount),
                        emphasize: true,
                      ),
                      if (paymentMethod.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildCompactRow(
                          'Payment Method',
                          _capitalizeFirst(paymentMethod),
                          valueEmphasize: true,
                        ),
                      ],
                      if (paymentStatus.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildCompactRow(
                          'Payment Status',
                          OrderHelpers.formatPaymentStatus(paymentStatus),
                          valueEmphasize: true,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canCancel)
                      TextButton(
                        onPressed: _isCancelling
                            ? null
                            : () => _cancelOrder(orderId),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: _isCancelling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.error,
                                ),
                              )
                            : const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    if (canCancel) const SizedBox(width: 8),
                    if (isDelivered)
                      ElevatedButton.icon(
                        onPressed: () {
                          _showRateOrderDialog(
                            orderId,
                            shopId,
                            orderItems,
                          );
                        },
                        icon: const Icon(Icons.star_rounded, size: 18),
                        label: const Text(
                          'Rate',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentAmber,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    if (isDelivered) const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _openOrderDetails(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'View Details',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderItemRow(Map<String, dynamic> item) {
    final nestedItem = item['item'] as Map<String, dynamic>?;
    final itemName = nestedItem?['item_name']?.toString() ??
        item['item_name']?.toString() ??
        item['name']?.toString() ??
        'Unknown Item';
    final quantity = item['quantity']?.toString() ?? '1';
    final price = item['price'] ??
        item['item_price'] ??
        nestedItem?['item_price'] ??
        item['price_at_purchase'] ??
        0;
    final variant = _itemVariantLabel(item);
    final imageUrl = _itemImageUrl(item);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.grey[400],
                      size: 22,
                    ),
                  )
                : Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.grey[400],
                    size: 22,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (variant.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    variant,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'x$quantity',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatPrice(price),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRow(
    String label,
    String value, {
    bool emphasize = false,
    bool valueEmphasize = false,
  }) {
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
      color: emphasize ? Colors.grey[900] : Colors.grey[600],
    );
    final valueStyle = TextStyle(
      fontSize: 13,
      fontWeight:
          (emphasize || valueEmphasize) ? FontWeight.w700 : FontWeight.w500,
      color: Colors.grey[900],
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
