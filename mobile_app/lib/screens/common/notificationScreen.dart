import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../provider/badge_provider.dart';
import '../../provider/notification_provider.dart';
import '../../models/notificationModel.dart';
import '../../services/api_service.dart';
import '../../services/farm_checkout_service.dart';
import '../../services/order_service.dart';
import '../../utils/customer_nav.dart';
import '../../utils/manila_time.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import 'farmOrderDetailsScreen.dart';
import 'orderDetailScreen.dart';

class NotificationScreen extends StatefulWidget {
  final bool showCustomerBottomNav;
  final OrderService? orderService;
  final FarmCheckoutService? farmCheckoutService;

  const NotificationScreen({
    super.key,
    this.showCustomerBottomNav = false,
    this.orderService,
    this.farmCheckoutService,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();
  late final OrderService _orderService;
  late final FarmCheckoutService _farmCheckoutService;
  bool _isGuest = true;
  bool _isOpeningOrder = false;
  final Map<int, String> _farmOrderCodes = {};

  @override
  void initState() {
    super.initState();
    _orderService = widget.orderService ?? OrderService();
    _farmCheckoutService = widget.farmCheckoutService ?? FarmCheckoutService();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGuestState();
      _fetchNotifications();
    });
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

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when near the bottom
      final provider =
          Provider.of<NotificationProvider>(context, listen: false);
      if (!provider.isLoadingMore && provider.hasMorePages) {
        provider.loadMoreNotifications();
      }
    }
  }

  Future<void> _fetchNotifications() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    await provider.fetchNotifications(refresh: true);
    _syncBadgeUnreadCount();
  }

  void _syncBadgeUnreadCount() {
    if (!mounted) return;
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    Provider.of<BadgeProvider>(context, listen: false)
        .setUnreadNotifications(notificationProvider.unreadCount);
  }

  String _formatTimestamp(DateTime timestamp) {
    final manilaTimestamp = ManilaTime.fromUtc(timestamp);
    final now = ManilaTime.now();
    final difference = now.difference(manilaTimestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
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
      return '${months[manilaTimestamp.month - 1]} ${manilaTimestamp.day}';
    }
  }

  Future<void> _markAsRead(int id) async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    await provider.markAsRead(id);
    _syncBadgeUnreadCount();
  }

  Future<void> _markAllAsRead() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    final success = await provider.markAllAsRead();
    if (success) {
      _syncBadgeUnreadCount();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(success
                  ? 'All notifications marked as read'
                  : 'Failed to mark notifications as read'),
            ],
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _deleteNotification(int id) async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    final success = await provider.deleteNotification(id);
    if (success) {
      _syncBadgeUnreadCount();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.delete_outline : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(success
                  ? 'Notification removed'
                  : 'Failed to remove notification'),
            ],
          ),
          backgroundColor: success ? Colors.grey[700] : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  IconData _getIconForNotification(NotificationModel notification) {
    if (_isPaymentNotification(notification)) return Icons.payment;
    switch (notification.type) {
      case 'order':
        switch (notification.category) {
          case 'delivered':
            return Icons.check_circle;
          case 'in-transit':
            return Icons.local_shipping;
          case 'processing':
            return Icons.inventory_2;
          case 'cancelled':
            return Icons.cancel;
          default:
            return Icons.shopping_bag;
        }
      case 'promo':
        if (notification.title.contains('Flash') ||
            notification.title.contains('⚡')) {
          return Icons.flash_on;
        }
        return Icons.local_offer;
      case 'system':
        if (notification.title.contains('Payment') ||
            notification.title.contains('card')) {
          return Icons.credit_card;
        }
        if (notification.title.contains('Welcome')) {
          return Icons.celebration;
        }
        return Icons.info_outline;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColorForNotification(NotificationModel notification) {
    if (_isPaymentNotification(notification)) {
      return _isConfirmedPayment(notification)
          ? AppColors.brandConfirmed
          : AppColors.warning;
    }
    switch (notification.type) {
      case 'order':
        switch (notification.category) {
          case 'delivered':
            return AppColors.success;
          case 'in-transit':
            return AppColors.brandPrimaryLight;
          case 'processing':
            return AppColors.brandPrimaryLight;
          case 'cancelled':
            return AppColors.error;
          default:
            return AppColors.brandPrimary;
        }
      case 'promo':
        if (notification.title.contains('Flash') ||
            notification.title.contains('⚡')) {
          return AppColors.accentAmber;
        }
        return Colors.purple;
      case 'system':
        if (notification.title.contains('Payment') ||
            notification.title.contains('card')) {
          return AppColors.brandPrimaryLight;
        }
        return AppColors.success;
      default:
        return AppColors.brandPrimary;
    }
  }

  bool _isPaymentNotification(NotificationModel notification) {
    final type = notification.type.toLowerCase();
    const payments = {
      'payment_pending',
      'payment_reminder',
      'payment_confirmed',
    };
    if (payments.contains(type)) return true;
    if (!type.startsWith('farm_')) return false;
    return type.contains('payment') ||
        type.contains('deposit') ||
        type.contains('balance');
  }

  bool _isConfirmedPayment(NotificationModel notification) {
    final type = notification.type.toLowerCase();
    if (type == 'payment_confirmed') return true;
    return type.startsWith('farm_') && type.endsWith('_paid');
  }

  bool _isFarmOrderReference(NotificationModel notification) {
    if (_referencedOrderId(notification) == null) return false;
    return notification.type.toLowerCase().startsWith('farm_');
  }

  bool _isKnownItemOrderType(String type) {
    if (type == 'order' || type.startsWith('order_')) return true;
    const payments = {
      'payment_pending',
      'payment_reminder',
      'payment_confirmed',
    };
    return payments.contains(type);
  }

  bool _isItemOrderReference(NotificationModel notification) {
    final type = notification.type.toLowerCase();
    if (type.startsWith('farm_') || type == 'refund_required') return false;
    final action = notification.actionUrl ?? '';
    if (action.startsWith('/farm-orders')) return false;
    if (_isKnownItemOrderType(type)) {
      return _referencedOrderId(notification) != null;
    }
    return _explicitDataOrderId(notification) != null ||
        _messageOrderCode(notification) != null;
  }

  /// Order id the signed-in customer is allowed to open.
  /// Shop status rows often put a shop or order-shop id in `reference_id`.
  int? _customerOrderId(NotificationModel notification) {
    final type = notification.type.toLowerCase();
    if (_isKnownItemOrderType(type)) return _referencedOrderId(notification);
    return _explicitDataOrderId(notification);
  }

  int? _explicitDataOrderId(NotificationModel notification) {
    final data = notification.data;
    final fromData = _notificationId(data?['order_id']);
    if (fromData != null) return fromData;
    final order = data?['order'];
    if (order is Map) {
      return _notificationId(order['id']) ?? _notificationId(order['order_id']);
    }
    final action = notification.actionUrl ?? '';
    final match = RegExp(r'^/orders/(\d+)$').firstMatch(action);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  bool _isAuthorizationFailure(String? message) {
    final text = message?.toLowerCase() ?? '';
    return text.contains('authoriz') || text.contains('forbidden');
  }

  bool _showsOrderReference(NotificationModel notification) {
    if (notification.type.toLowerCase() == 'refund_required') return false;
    return _isFarmOrderReference(notification) ||
        _isItemOrderReference(notification) ||
        _messageOrderCode(notification) != null;
  }

  static final RegExp _orderCodeInMessage = RegExp(
    r'#?(ORD-[A-Z0-9]+)',
    caseSensitive: false,
  );

  String? _messageOrderCode(NotificationModel notification) {
    final match = _orderCodeInMessage.firstMatch(notification.message);
    return match?.group(1)?.toUpperCase();
  }

  int? _referencedOrderId(NotificationModel notification) {
    final direct = notification.referenceId;
    if (direct != null) return direct;

    final reference = notification.reference;
    final referenced = _notificationId(reference?['id']) ??
        _notificationId(reference?['order_id']);
    if (referenced != null) return referenced;

    final data = notification.data;
    final fromData = _notificationId(data?['order_id']) ??
        _notificationId(data?['reference_id']);
    if (fromData != null) return fromData;

    final order = data?['order'];
    if (order is Map) {
      return _notificationId(order['id']) ?? _notificationId(order['order_id']);
    }
    return null;
  }

  int? _notificationId(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return int.tryParse(text);
  }

  Future<void> _openReferencedOrder(NotificationModel notification) async {
    if (_isOpeningOrder) return;
    final referencedId = _referencedOrderId(notification);

    if (_isFarmOrderReference(notification)) {
      if (referencedId == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FarmOrderDetailsScreen(
            orderId: referencedId,
            service: _farmCheckoutService,
          ),
        ),
      );
      return;
    }

    final code = _messageOrderCode(notification) ??
        notificationOrderCode(notification);
    final orderId = _customerOrderId(notification);
    if (orderId == null && code == null) return;

    setState(() => _isOpeningOrder = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      Map<String, dynamic>? order;
      String? errorMessage;
      if (orderId != null) {
        final result = await _orderService.getOrderById(orderId.toString());
        if (result['success'] == true && result['data'] is Map) {
          order = Map<String, dynamic>.from(result['data'] as Map);
        } else {
          errorMessage =
              result['message']?.toString() ?? 'Failed to open order.';
          if (code != null && _isAuthorizationFailure(errorMessage)) {
            order = await _orderByCode(code);
            if (order != null) errorMessage = null;
          }
        }
      } else if (code != null) {
        order = await _orderByCode(code);
        errorMessage = order == null ? 'Order not found' : null;
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final opened = order;
      if (opened != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: opened),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Failed to open order.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open order: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningOrder = false);
    }
  }

  String _normalizeOrderCode(String value) =>
      value.trim().toLowerCase().replaceFirst(RegExp(r'^#'), '');

  Future<Map<String, dynamic>?> _orderByCode(String code) async {
    final result = await _orderService.fetchOrders();
    final orders = result['orders'];
    if (orders is! List) return null;
    final target = _normalizeOrderCode(code);
    for (final raw in orders) {
      if (raw is! Map) continue;
      final orderCode =
          _normalizeOrderCode(raw['order_code']?.toString() ?? '');
      if (orderCode == target) return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[700]),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              if (provider.unreadCount > 0) {
                return TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: Icon(
                    Icons.done_all,
                    size: 18,
                    color: AppColors.brandPrimary,
                  ),
                  label: Text(
                    'Mark all read',
                    style: TextStyle(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return _buildLoadingState();
          }

          if (provider.error != null && provider.notifications.isEmpty) {
            return _buildErrorState(provider.error!);
          }

          if (provider.notifications.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _fetchNotifications,
            color: AppColors.brandPrimary,
            child: Column(
              children: [
                // Unread count banner
                if (provider.unreadCount > 0)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withOpacity(0.1),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.brandPrimary.withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${provider.unreadCount}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'unread notification${provider.unreadCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Notifications list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    itemCount: provider.notifications.length +
                        (provider.hasMorePages ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.notifications.length) {
                        // Loading indicator for pagination
                        return Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.brandPrimary,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }
                      return _buildNotificationCard(
                          provider.notifications[index]);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: widget.showCustomerBottomNav
          ? buildCustomerBottomNavigationBar(
              context: context,
              currentIndex: CustomerNavIndex.notifs,
              isGuest: _isGuest,
              onLoginSuccess: () {
                _loadGuestState();
                _fetchNotifications();
              },
            )
          : null,
    );
  }

  Widget _buildLoadingState() {
    return const ListRowsSkeleton(count: 8);
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Failed to load notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchNotifications,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      color: AppColors.brandPrimary,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height - 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: AppColors.brandPrimary,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'No notifications yet',
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
                    'When you receive notifications, they will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final isRead = notification.read;
    final iconData = _getIconForNotification(notification);
    final iconColor = _getIconColorForNotification(notification);
    final cardColor = _isConfirmedPayment(notification)
        ? AppColors.brandConfirmed
        : AppColors.brandPrimary;

    return Dismissible(
      key: Key(notification.id.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        await _deleteNotification(notification.id);
        return false; // Provider handles removal
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          if (!isRead) {
            _markAsRead(notification.id);
          }
          _showNotificationDetail(notification, iconData, iconColor);
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : cardColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead ? Colors.grey[200]! : cardColor.withOpacity(0.2),
            ),
            boxShadow: isRead
                ? []
                : [
                    BoxShadow(
                      color: cardColor.withOpacity(0.08),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    isRead ? FontWeight.w500 : FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            _formatTimestamp(notification.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Unread indicator
                if (!isRead)
                  Container(
                    margin: EdgeInsets.only(left: 8),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotificationDetail(
    NotificationModel notification,
    IconData iconData,
    Color iconColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 24),

            // Icon and title
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatTimestamp(notification.createdAt),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Divider
            Divider(color: Colors.grey[200]),
            SizedBox(height: 16),

            // Message
            Text(
              notification.message,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
            SizedBox(height: 24),

            // Highlighted order reference — tap opens Order Details.
            if (_showsOrderReference(notification)) ...[
              _buildOrderReferenceHighlight(notification),
              SizedBox(height: 16),
            ],

            if (notification.type == 'promo')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to promo/shop
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Exploring deals...'),
                        backgroundColor: AppColors.brandPrimary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Shop Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderReferenceHighlight(NotificationModel notification) {
    final highlight = _isConfirmedPayment(notification)
        ? AppColors.brandConfirmed
        : _isPaymentNotification(notification)
            ? AppColors.warning
            : AppColors.brandPrimary;
    final orderId = _referencedOrderId(notification);
    return _OrderReferenceHighlight(
      label: _orderReferenceLabel(notification),
      highlight: highlight,
      resolveCode: _isFarmOrderReference(notification) &&
              notificationOrderCode(notification) == null &&
              orderId != null
          ? () => _loadFarmOrderCode(orderId)
          : null,
      onOpen: () {
        Navigator.pop(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _openReferencedOrder(notification);
        });
      },
    );
  }

  Future<String?> _loadFarmOrderCode(int orderId) async {
    final cached = _farmOrderCodes[orderId];
    if (cached != null) return cached;
    try {
      final code = (await _farmCheckoutService.order(orderId)).code.trim();
      if (code.isEmpty || code == '#$orderId') return null;
      _farmOrderCodes[orderId] = code;
      return code;
    } catch (_) {
      return null;
    }
  }

  String _orderReferenceLabel(NotificationModel notification) {
    final orderId = _referencedOrderId(notification);
    return notificationOrderCode(notification) ??
        _messageOrderCode(notification) ??
        (orderId == null ? null : _farmOrderCodes[orderId]) ??
        'Order #$orderId';
  }
}

class _OrderReferenceHighlight extends StatefulWidget {
  const _OrderReferenceHighlight({
    required this.label,
    required this.highlight,
    required this.onOpen,
    this.resolveCode,
  });

  final String label;
  final Color highlight;
  final VoidCallback onOpen;
  final Future<String?> Function()? resolveCode;

  @override
  State<_OrderReferenceHighlight> createState() =>
      _OrderReferenceHighlightState();
}

class _OrderReferenceHighlightState extends State<_OrderReferenceHighlight> {
  late String _label;

  @override
  void initState() {
    super.initState();
    _label = widget.label;
    final resolveCode = widget.resolveCode;
    if (resolveCode == null) return;
    resolveCode().then((code) {
      final next = code?.trim() ?? '';
      if (!mounted || next.isEmpty || next == _label) return;
      setState(() => _label = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final highlight = widget.highlight;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('notification-order-reference'),
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: highlight.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlight.withOpacity(0.45),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: highlight.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long,
                  color: highlight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order reference',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: highlight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[500],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
