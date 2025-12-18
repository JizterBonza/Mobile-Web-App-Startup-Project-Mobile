import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../provider/orders_provider.dart';
import '../../services/order_service.dart';
import 'orderDetailScreen.dart';

class MyOrderScreen extends StatefulWidget {
  const MyOrderScreen({super.key});

  @override
  State<MyOrderScreen> createState() => _MyOrderScreenState();
}

class _MyOrderScreenState extends State<MyOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderService _orderService = OrderService();
  bool _isCancelling = false;

  final List<Map<String, dynamic>> _statusTabs = [
    {'label': 'All', 'status': null},
    {'label': 'Pending', 'status': 'pending'},
    {'label': 'Processing', 'status': 'processing'},
    {'label': 'In Transit', 'status': 'in-transit'},
    {'label': 'Delivered', 'status': 'delivered'},
    {'label': 'Cancelled', 'status': 'cancelled'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  @override
  void dispose() {
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
    return orders.where((order) {
      final orderStatus = order['order_status']?.toString().toLowerCase() ?? '';
      return orderStatus == status.toLowerCase();
    }).toList();
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
        final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
        final period = dateTime.hour >= 12 ? 'PM' : 'AM';
        final minute = dateTime.minute.toString().padLeft(2, '0');
        return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at $hour:$minute $period';
      }
    } catch (e) {
      print('Error formatting date: $e');
    }
    return dateString;
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return AppColors.mediumGreen;
      case 'in transit':
      case 'in-transit':
        return Colors.orange[600]!;
      case 'pending':
        return Colors.amber[700]!;
      case 'processing':
        return Colors.blue[600]!;
      case 'cancelled':
      case 'canceled':
        return Colors.red[600]!;
      default:
        return Colors.grey[500]!;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Icons.check_circle;
      case 'in transit':
      case 'in-transit':
        return Icons.local_shipping;
      case 'pending':
        return Icons.schedule;
      case 'processing':
        return Icons.sync;
      case 'cancelled':
      case 'canceled':
        return Icons.cancel;
      default:
        return Icons.receipt_long;
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
                color: Colors.orange[700], size: 28),
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
              backgroundColor: Colors.red[600],
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
            backgroundColor: AppColors.mediumGreen,
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
            backgroundColor: Colors.red[600],
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
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
          preferredSize: Size.fromHeight(50),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.mediumGreen,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: AppColors.mediumGreen,
              indicatorWeight: 3,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              tabs: _statusTabs.map((tab) => Tab(text: tab['label'])).toList(),
            ),
          ),
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
                tab['status'],
              );
              return _buildOrdersList(filteredOrders, ordersProvider.error);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.mediumGreen,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading orders...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders, String? error) {
    if (orders.isEmpty) {
      return _buildEmptyState(error);
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.mediumGreen,
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
      color: AppColors.mediumGreen,
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
                    color: AppColors.mediumGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    error != null
                        ? Icons.error_outline
                        : Icons.receipt_long_outlined,
                    size: 64,
                    color:
                        error != null ? Colors.red[400] : AppColors.mediumGreen,
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
                      backgroundColor: AppColors.mediumGreen,
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
    final orderCode = order['order_code']?.toString() ?? 'N/A';
    final orderStatus = order['order_status']?.toString() ?? 'Pending';
    final totalAmount = order['total_amount'];
    final orderedAt = order['ordered_at']?.toString() ?? '';
    final shippingAddress =
        order['shipping_address']?.toString() ?? 'No address';
    final paymentMethod = order['payment_method']?.toString() ?? 'N/A';
    final orderId =
        order['id']?.toString() ?? order['order_id']?.toString() ?? '';
    final orderItems = order['order_items'] as List? ?? [];

    final canCancel = orderStatus.toLowerCase() == 'pending';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with order code and status
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(orderStatus).withOpacity(0.05),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$orderCode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatOrderDate(orderedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(orderStatus).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(orderStatus),
                        size: 14,
                        color: _getStatusColor(orderStatus),
                      ),
                      SizedBox(width: 6),
                      Text(
                        orderStatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(orderStatus),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Order items preview
          if (orderItems.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Items',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...orderItems.take(3).map((item) {
                    // Handle nested item structure - item details might be in 'item' key
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
                    return Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.mediumGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$itemName x$quantity',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatPrice(price),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  if (orderItems.length > 3)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '+${orderItems.length - 3} more items',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mediumGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          Divider(height: 1, color: Colors.grey[200]),

          // Order details
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(
                  Icons.location_on_outlined,
                  'Delivery Address',
                  shippingAddress,
                ),
                SizedBox(height: 12),
                _buildDetailRow(
                  Icons.payment_outlined,
                  'Payment Method',
                  _capitalizeFirst(paymentMethod),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey[200]),

          // Footer with total and actions
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _formatPrice(totalAmount),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mediumGreen,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (canCancel)
                      TextButton(
                        onPressed:
                            _isCancelling ? null : () => _cancelOrder(orderId),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red[600],
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: _isCancelling
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red[600],
                                ),
                              )
                            : Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OrderDetailScreen(order: order),
                          ),
                        );
                        // Refresh orders if order was cancelled
                        if (result == true) {
                          _loadOrders(useCache: false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mediumGreen,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'View Details',
                        style: TextStyle(fontWeight: FontWeight.w600),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.mediumGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.mediumGreen,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
