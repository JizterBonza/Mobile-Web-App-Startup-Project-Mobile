import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../provider/notification_provider.dart';
import '../../models/notificationModel.dart';
import '../../services/api_service.dart';
import '../../utils/customer_nav.dart';
import '../../widgets/skeletons/app_skeletons.dart';

class NotificationScreen extends StatefulWidget {
  final bool showCustomerBottomNav;

  const NotificationScreen({super.key, this.showCustomerBottomNav = false});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isGuest = true;

  @override
  void initState() {
    super.initState();
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
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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
      return '${months[timestamp.month - 1]} ${timestamp.day}';
    }
  }

  Future<void> _markAsRead(int id) async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    await provider.markAsRead(id);
  }

  Future<void> _markAllAsRead() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    final success = await provider.markAllAsRead();

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
          backgroundColor: success ? AppColors.primaryGreen : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _deleteNotification(int id) async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    final success = await provider.deleteNotification(id);

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
    // Determine icon based on type and category
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
    switch (notification.type) {
      case 'order':
        switch (notification.category) {
          case 'delivered':
            return AppColors.success;
          case 'in-transit':
            return AppColors.warning;
          case 'processing':
            return AppColors.primaryGreenLight;
          case 'cancelled':
            return AppColors.error;
          default:
            return AppColors.primaryGreen;
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
          return AppColors.primaryGreenLight;
        }
        return AppColors.success;
      default:
        return AppColors.primaryGreen;
    }
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
                    color: AppColors.primaryGreen,
                  ),
                  label: Text(
                    'Mark all read',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
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
            color: AppColors.primaryGreen,
            child: Column(
              children: [
                // Unread count banner
                if (provider.unreadCount > 0)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.primaryGreen.withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
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
                            color: AppColors.primaryGreen,
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
                              color: AppColors.primaryGreen,
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
                backgroundColor: AppColors.primaryGreen,
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
      color: AppColors.primaryGreen,
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
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: AppColors.primaryGreen,
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
            color:
                isRead ? Colors.white : AppColors.primaryGreen.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead
                  ? Colors.grey[200]!
                  : AppColors.primaryGreen.withOpacity(0.2),
            ),
            boxShadow: isRead
                ? []
                : [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.08),
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
                      color: AppColors.primaryGreen,
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

            // Action button based on notification type
            if (notification.type == 'order')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to order details if reference_id exists
                    if (notification.referenceId != null) {
                      // TODO: Navigate to order details
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Navigating to order details...'),
                          backgroundColor: AppColors.primaryGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'View Order',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

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
                        backgroundColor: AppColors.primaryGreen,
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
}
