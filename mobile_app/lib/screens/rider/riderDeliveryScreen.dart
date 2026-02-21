import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../provider/provider.dart';
import '../../services/order_service.dart';
import '../../widgets/order_item_card.dart';
import '../../utils/snackbar_helper.dart';

class RiderDeliveryScreen extends StatefulWidget {
  const RiderDeliveryScreen({super.key});

  @override
  State<RiderDeliveryScreen> createState() => _RiderDeliveryScreenState();
}

class _RiderDeliveryScreenState extends State<RiderDeliveryScreen> {
  List<Map<String, dynamic>> _availableOrders = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all'; // 'all', 'pending', 'processing'

  @override
  void initState() {
    super.initState();
    _initializeOrderStatusProvider();
    _loadAvailableOrders();
  }

  Future<void> _initializeOrderStatusProvider() async {
    final orderStatusProvider =
        Provider.of<OrderStatusProvider>(context, listen: false);
    await orderStatusProvider.initialize();
  }

  Future<void> _loadAvailableOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch orders with pending or processing status (available for assignment)
      final ordersProvider =
          Provider.of<OrdersProvider>(context, listen: false);
      await ordersProvider.fetchOrders(status: 'pending', useCache: false);
      final orders = ordersProvider.orders;

      // Filter orders that need a rider (not yet assigned or in transit)
      // Get OrderStatusProvider to check status by ID
      final orderStatusProvider =
          Provider.of<OrderStatusProvider>(context, listen: false);
      await orderStatusProvider.initialize();

      final availableOrders = orders.where((order) {
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
        return statusDesc == 'pending' || statusDesc == 'processing';
      }).toList();

      setState(() {
        _availableOrders = availableOrders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _availableOrders = [];
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _acceptDelivery(Map<String, dynamic> order) async {
    final orderId = order['order_id']?.toString() ?? order['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      SnackbarHelper.showError(context, 'Invalid order ID');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Accept Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Do you want to accept this delivery?'),
            SizedBox(height: 16),
            Text(
              'Order: ${order['order_code'] ?? 'N/A'}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Customer: ${_getCustomerName(order)}',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Address: ${order['shipping_address'] ?? 'N/A'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mediumGreen,
              foregroundColor: Colors.white,
            ),
            child: Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          color: AppColors.mediumGreen,
        ),
      ),
    );

    try {
      // Get status code for "in-transit" from OrderStatusProvider
      final orderStatusProvider =
          Provider.of<OrderStatusProvider>(context, listen: false);
      final inTransitStatusId =
          orderStatusProvider.getOrderStatusIdByDescription('in-transit') ??
              orderStatusProvider.getOrderStatusIdByDescription('in transit');

      if (inTransitStatusId == null) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          SnackbarHelper.showError(
            context,
            'Unable to find "In Transit" status. Please try again.',
          );
        }
        return;
      }

      // Update order status to "in-transit" (accepted by rider)
      final orderService = OrderService();
      final result = await orderService.updateOrderStatus(
        orderId: orderId,
        status: inTransitStatusId.toString(),
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        if (result['success'] == true) {
          SnackbarHelper.showSuccess(
            context,
            'Delivery accepted successfully!',
          );
          // Reload available orders
          await _loadAvailableOrders();
          // Navigate back after a short delay
          await Future.delayed(Duration(milliseconds: 500));
          if (context.mounted) {
            Navigator.pop(context);
          }
        } else {
          SnackbarHelper.showError(
            context,
            result['message'] ?? 'Failed to accept delivery',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        SnackbarHelper.showError(
          context,
          'Error accepting delivery: ${e.toString()}',
        );
      }
    }
  }

  String _getCustomerName(Map<String, dynamic> order) {
    final user = order['user'] as Map<String, dynamic>?;
    if (user != null) {
      return '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    }
    return 'Unknown Customer';
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
      'customer': _getCustomerName(order),
      'status': orderStatus,
      'date': _formatOrderDate(order['ordered_at']?.toString() ?? ''),
      'total':
          double.tryParse(order['total_amount']?.toString() ?? '0.0') ?? 0.0,
      'items': (order['order_items'] as List?)?.length ?? 0,
      'phone': (order['user'] as Map<String, dynamic>?)?['mobile_number']
              ?.toString() ??
          '',
      'address': order['shipping_address']?.toString() ?? '',
      'order_id': order['order_id']?.toString() ?? order['id']?.toString(),
    };
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedFilter == 'all') {
      return _availableOrders;
    } else {
      final orderStatusProvider =
          Provider.of<OrderStatusProvider>(context, listen: false);
      return _availableOrders.where((order) {
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
        return statusDesc == _selectedFilter.toLowerCase();
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Available Deliveries',
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
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAvailableOrders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterChip('all', 'All'),
                SizedBox(width: 8),
                _buildFilterChip('pending', 'Pending'),
                SizedBox(width: 8),
                _buildFilterChip('processing', 'Processing'),
              ],
            ),
          ),
          // Orders list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.mediumGreen,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Error loading deliveries',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadAvailableOrders,
                              icon: Icon(Icons.refresh),
                              label: Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.mediumGreen,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No available deliveries',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Check back later for new delivery requests',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : Consumer<OrderStatusProvider>(
                            builder: (context, orderStatusProvider, child) {
                              return RefreshIndicator(
                                onRefresh: _loadAvailableOrders,
                                color: AppColors.mediumGreen,
                                child: ListView.builder(
                                  padding: EdgeInsets.all(16),
                                  itemCount: _filteredOrders.length,
                                  itemBuilder: (context, index) {
                                    final order = _filteredOrders[index];
                                    final cardData = _convertOrderToCardFormat(
                                        order, orderStatusProvider);

                                    return Container(
                                      margin: EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.mediumGreen
                                              .withOpacity(0.3),
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          OrderItemCard(
                                            order: cardData,
                                            showDetails: true,
                                            onViewDetails: () {
                                              _showOrderDetails(order);
                                            },
                                          ),
                                          Divider(height: 1),
                                          Padding(
                                            padding: EdgeInsets.all(16),
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: () =>
                                                    _acceptDelivery(order),
                                                icon: Icon(Icons.check_circle),
                                                label: Text('Accept Delivery'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.mediumGreen,
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: AppColors.mediumGreen.withOpacity(0.2),
      checkmarkColor: AppColors.mediumGreen,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.mediumGreen : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.mediumGreen : Colors.grey[300]!,
        width: isSelected ? 2 : 1,
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final user = order['user'] as Map<String, dynamic>?;
    final customerName = _getCustomerName(order);
    final orderItems = order['order_items'] as List? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                  'Order Code', order['order_code']?.toString() ?? 'N/A'),
              _buildDetailRow('Customer', customerName),
              _buildDetailRow(
                  'Status', _getOrderStatusDescription(order) ?? 'Pending'),
              _buildDetailRow('Date',
                  _formatOrderDate(order['ordered_at']?.toString() ?? '')),
              _buildDetailRow(
                  'Address', order['shipping_address']?.toString() ?? 'N/A'),
              _buildDetailRow(
                  'Phone', user?['mobile_number']?.toString() ?? 'N/A'),
              if (order['drop_location_lat'] != null &&
                  order['drop_location_long'] != null) ...[
                SizedBox(height: 8),
                Divider(),
                SizedBox(height: 8),
                Text(
                  'Delivery Location:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Lat: ${order['drop_location_lat']}, Long: ${order['drop_location_long']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (order['order_instruction'] != null &&
                  order['order_instruction'].toString().isNotEmpty) ...[
                SizedBox(height: 8),
                Divider(),
                SizedBox(height: 8),
                Text(
                  'Special Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  order['order_instruction'].toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              SizedBox(height: 8),
              Divider(),
              SizedBox(height: 8),
              Text(
                'Items (${orderItems.length}):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ...orderItems.take(5).map((item) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text('• ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(
                          '${item['item_name'] ?? 'Unknown'} x${item['quantity'] ?? 1}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      if (item['item_price'] != null)
                        Text(
                          _formatPrice(item['item_price']),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              if (orderItems.length > 5)
                Text(
                  '... and ${orderItems.length - 5} more items',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              SizedBox(height: 8),
              Divider(),
              SizedBox(height: 8),
              _buildDetailRow('Subtotal', _formatPrice(order['subtotal'])),
              _buildDetailRow(
                  'Shipping Fee', _formatPrice(order['shipping_fee'])),
              _buildDetailRow(
                'Total',
                _formatPrice(order['total_amount']),
                isBold: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptDelivery(order);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mediumGreen,
              foregroundColor: Colors.white,
            ),
            child: Text('Accept Delivery'),
          ),
        ],
      ),
    );
  }

  String? _getOrderStatusDescription(Map<String, dynamic> order) {
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

    if (statusId != null) {
      return orderStatusProvider.getOrderStatusDescription(statusId);
    }
    return null;
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.grey[900],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
