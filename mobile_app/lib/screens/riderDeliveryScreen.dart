import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/constants.dart';
import '../provider/provider.dart';
import '../services/order_service.dart';
import '../widgets/order_item_card.dart';
import '../utils/snackbar_helper.dart';

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
  bool _useStaticSamples = false; // Toggle to use static samples

  // Static sample orders for demonstration
  final List<Map<String, dynamic>> _staticSampleOrders = [
    {
      'id': '1',
      'order_id': '1',
      'order_code': 'ORD-2024-001',
      'user_id': '1',
      'order_status': 'pending',
      'ordered_at':
          DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
      'updated_at':
          DateTime.now().subtract(Duration(hours: 2)).toIso8601String(),
      'subtotal': '1250.00',
      'shipping_fee': '50.00',
      'total_amount': '1300.00',
      'shipping_address':
          '123 Main Street, Barangay San Antonio, Quezon City, Metro Manila',
      'drop_location_lat': 14.6760,
      'drop_location_long': 121.0437,
      'order_instruction':
          'Please ring the doorbell twice. Leave package at the gate if no answer.',
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
      'order_code': 'ORD-2024-002',
      'user_id': '2',
      'order_status': 'processing',
      'ordered_at':
          DateTime.now().subtract(Duration(hours: 1)).toIso8601String(),
      'updated_at':
          DateTime.now().subtract(Duration(minutes: 30)).toIso8601String(),
      'subtotal': '890.50',
      'shipping_fee': '45.00',
      'total_amount': '935.50',
      'shipping_address':
          '456 Oak Avenue, Barangay Poblacion, Makati City, Metro Manila',
      'drop_location_lat': 14.5547,
      'drop_location_long': 121.0244,
      'order_instruction':
          'Call before delivery. Customer prefers morning delivery.',
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
      'order_code': 'ORD-2024-003',
      'user_id': '3',
      'order_status': 'pending',
      'ordered_at':
          DateTime.now().subtract(Duration(minutes: 45)).toIso8601String(),
      'updated_at':
          DateTime.now().subtract(Duration(minutes: 45)).toIso8601String(),
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
        {
          'item_name': 'Garden Hoe',
          'quantity': 2,
          'item_price': '550.00',
        },
      ],
    },
    {
      'id': '4',
      'order_id': '4',
      'order_code': 'ORD-2024-004',
      'user_id': '4',
      'order_status': 'processing',
      'ordered_at':
          DateTime.now().subtract(Duration(minutes: 20)).toIso8601String(),
      'updated_at':
          DateTime.now().subtract(Duration(minutes: 15)).toIso8601String(),
      'subtotal': '750.25',
      'shipping_fee': '40.00',
      'total_amount': '790.25',
      'shipping_address':
          '321 Elm Street, Barangay San Isidro, Taguig City, Metro Manila',
      'drop_location_lat': 14.5176,
      'drop_location_long': 121.0509,
      'order_instruction': null,
      'payment_method': 'Bank Transfer',
      'payment_status': 'paid',
      'user': {
        'id': '4',
        'first_name': 'Carlos',
        'last_name': 'Rodriguez',
        'mobile_number': '+63 912 345 6792',
        'email': 'carlos.rodriguez@example.com',
      },
      'order_items': [
        {
          'item_name': 'Pepper Seeds Pack',
          'quantity': 2,
          'item_price': '150.00',
        },
        {
          'item_name': 'Garden Gloves',
          'quantity': 3,
          'item_price': '150.08',
        },
      ],
    },
    {
      'id': '5',
      'order_id': '5',
      'order_code': 'ORD-2024-005',
      'user_id': '5',
      'order_status': 'pending',
      'ordered_at':
          DateTime.now().subtract(Duration(minutes: 10)).toIso8601String(),
      'updated_at':
          DateTime.now().subtract(Duration(minutes: 10)).toIso8601String(),
      'subtotal': '1850.75',
      'shipping_fee': '60.00',
      'total_amount': '1910.75',
      'shipping_address':
          '654 Maple Drive, Barangay Central, Mandaluyong City, Metro Manila',
      'drop_location_lat': 14.5832,
      'drop_location_long': 121.0405,
      'order_instruction':
          'Delivery to back gate. Security guard will receive.',
      'payment_method': 'Cash on Delivery',
      'payment_status': 'pending',
      'user': {
        'id': '5',
        'first_name': 'Lisa',
        'last_name': 'Tan',
        'mobile_number': '+63 912 345 6793',
        'email': 'lisa.tan@example.com',
      },
      'order_items': [
        {
          'item_name': 'Premium Garden Tools Set',
          'quantity': 1,
          'item_price': '1200.00',
        },
        {
          'item_name': 'Organic Compost 20kg',
          'quantity': 1,
          'item_price': '650.75',
        },
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailableOrders();
  }

  Future<void> _loadAvailableOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Use static samples if enabled or if API fails
    try {
      // Fetch orders with pending or processing status (available for assignment)
      final ordersProvider =
          Provider.of<OrdersProvider>(context, listen: false);
      await ordersProvider.fetchOrders(status: 'pending', useCache: false);
      final orders = ordersProvider.orders;

      // Filter orders that need a rider (not yet assigned or in transit)
      final availableOrders = orders.where((order) {
        final status = order['order_status']?.toString().toLowerCase() ?? '';
        return status == 'pending' || status == 'processing';
      }).toList();

      // If no orders from API, use static samples
      if (availableOrders.isEmpty) {
        setState(() {
          _availableOrders = List.from(_staticSampleOrders);
          _isLoading = false;
          _useStaticSamples = true;
        });
      } else {
        setState(() {
          _availableOrders = availableOrders;
          _isLoading = false;
          _useStaticSamples = false;
        });
      }
    } catch (e) {
      // On error, use static samples for demonstration
      setState(() {
        _availableOrders = List.from(_staticSampleOrders);
        _isLoading = false;
        _error = null; // Don't show error when using samples
        _useStaticSamples = true;
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
            if (_useStaticSamples) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.orange[700]),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Demo mode: Using sample data',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

    // If using static samples, just simulate the acceptance
    if (_useStaticSamples) {
      // Simulate loading
      await Future.delayed(Duration(milliseconds: 800));

      // Remove the accepted order from the list
      setState(() {
        _availableOrders.removeWhere((o) =>
            (o['order_id']?.toString() ?? o['id']?.toString()) == orderId);
      });

      SnackbarHelper.showSuccess(
        context,
        'Delivery accepted successfully! (Demo mode)',
      );

      // Navigate back after a short delay
      await Future.delayed(Duration(milliseconds: 500));
      if (context.mounted) {
        Navigator.pop(context);
      }
      return;
    }

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
      // Update order status to "in-transit" (accepted by rider)
      final orderService = OrderService();
      final result = await orderService.updateOrderStatus(
        orderId: orderId,
        status: 'in-transit',
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

  Map<String, dynamic> _convertOrderToCardFormat(Map<String, dynamic> order) {
    return {
      'id': order['order_code']?.toString() ?? 'N/A',
      'customer': _getCustomerName(order),
      'status': order['order_status']?.toString() ?? 'Pending',
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
      return _availableOrders.where((order) {
        final status = order['order_status']?.toString().toLowerCase() ?? '';
        return status == _selectedFilter;
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
                                if (!_useStaticSamples) ...[
                                  SizedBox(height: 24),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _availableOrders =
                                            List.from(_staticSampleOrders);
                                        _useStaticSamples = true;
                                      });
                                    },
                                    icon: Icon(Icons.visibility),
                                    label: Text('Load Sample Data'),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: AppColors.mediumGreen),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAvailableOrders,
                            color: AppColors.mediumGreen,
                            child: ListView.builder(
                              padding: EdgeInsets.all(16),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (context, index) {
                                final order = _filteredOrders[index];
                                final cardData =
                                    _convertOrderToCardFormat(order);

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
                                        color: Colors.black.withOpacity(0.05),
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
                                                    BorderRadius.circular(8),
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
                  'Status', order['order_status']?.toString() ?? 'Pending'),
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
