import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../constants/constants.dart';
import '../../services/order_service.dart';
import '../../provider/provider.dart';
import '../../provider/pod_provider.dart';
import '../../widgets/order_item_card.dart';
import '../../widgets/view_header.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/order_details_dialog.dart';
import 'delivery_photo_preview_screen.dart';

class RiderAllDeliveriesScreen extends StatefulWidget {
  const RiderAllDeliveriesScreen({super.key});

  @override
  State<RiderAllDeliveriesScreen> createState() =>
      _RiderAllDeliveriesScreenState();
}

class _RiderAllDeliveriesScreenState extends State<RiderAllDeliveriesScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  List<Map<String, dynamic>> _allOrders = [];
  bool _isLoadingOrders = true;
  String? _orderError;
  late TabController _tabController;

  // Status tabs for filtering (matching myOrderScreen style)
  final List<Map<String, dynamic>> _statusTabs = [
    {'label': 'All', 'status': null},
    {'label': 'Ready for Pickup', 'status': 'ready for pickup'},
    {'label': 'In Transit', 'status': 'in-transit'},
    {'label': 'Delivered', 'status': 'delivered'},
    {'label': 'Pending', 'status': 'pending'},
    {'label': 'Processing', 'status': 'processing'},
    {'label': 'Cancelled', 'status': 'cancelled'},
  ];

  List<Map<String, dynamic>> _filterOrdersByStatus(
      String? status, OrderStatusProvider orderStatusProvider) {
    if (status == null) return _allOrders;
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

      final orderStatusDesc = orderStatusProvider
              .getOrderStatusDescription(statusId)
              ?.toLowerCase() ??
          '';
      final filterStatus = status.toLowerCase();

      // Handle various status formats
      if (filterStatus == 'ready for pickup') {
        return orderStatusDesc == 'ready for pickup' ||
            orderStatusDesc == 'ready-for-pickup';
      } else if (filterStatus == 'in-transit') {
        return orderStatusDesc == 'in-transit' || orderStatusDesc == 'in transit';
      } else if (filterStatus == 'cancelled') {
        return orderStatusDesc == 'cancelled' || orderStatusDesc == 'canceled';
      }
      return orderStatusDesc == filterStatus;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _initializeOrderStatusProvider();
    _loadOrders();
  }

  Future<void> _initializeOrderStatusProvider() async {
    final orderStatusProvider =
        Provider.of<OrderStatusProvider>(context, listen: false);
    await orderStatusProvider.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool useCache = true}) async {
    setState(() {
      _isLoadingOrders = true;
      _orderError = null;
    });

    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);

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
    await Future.delayed(Duration(milliseconds: 500));
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

  Future<void> _updateOrderStatus(
      String orderId, String status, String? shopId) async {
    try {
      final result = await _orderService.updateOrderStatus(
        orderId: orderId,
        status: status,
        shopId: shopId,
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

  void _handlePickup(Map<String, dynamic> order) {
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

    // Get status code for "in-transit" from OrderStatusProvider
    final orderStatusProvider =
        Provider.of<OrderStatusProvider>(context, listen: false);
    final inTransitStatusId = orderStatusProvider
            .getOrderStatusIdByDescription('in-transit') ??
        orderStatusProvider.getOrderStatusIdByDescription('in transit');

    if (inTransitStatusId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to find "In Transit" status. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final shopId = order['shop_id']?.toString();
    _updateOrderStatus(orderId, inTransitStatusId.toString(), shopId);
  }

  Future<void> _handleDelivered(Map<String, dynamic> order) async {
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

    final ImagePicker picker = ImagePicker();
    bool photoConfirmed = false;

    // Loop until user confirms photo or cancels
    while (!photoConfirmed && mounted) {
      XFile? imageFile;

      // Capture image from camera
      try {
        imageFile = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (imageFile == null) {
          // User cancelled camera
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delivery photo is required'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing camera: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Navigate to preview screen
      if (!mounted) return;

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => DeliveryPhotoPreviewScreen(
            imageFile: imageFile!,
            order: order,
            orderId: orderId,
          ),
        ),
      );

      // If photo was confirmed and saved successfully, exit loop and reload orders
      if (result == true) {
        photoConfirmed = true;
        if (mounted) {
          await _loadOrders(useCache: false);
        }
        break;
      }
      // If result is false, user wants to retake - loop will continue
      // If result is null, user closed preview - exit
      if (result == null) {
        return;
      }
    }
  }

  Future<void> _uploadPendingPhotos() async {
    try {
      final podProvider = Provider.of<PodProvider>(context, listen: false);

      if (podProvider.isUploading) return;

      print('=== POD UPLOAD DEBUG: Starting upload process via Provider ===');

      // Show progress dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Consumer<PodProvider>(
              builder: (context, provider, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.mediumGreen),
                    SizedBox(height: 16),
                    if (provider.totalToUpload > 0)
                      Text(
                        'Uploading ${provider.uploadProgress}/${provider.totalToUpload} photo(s)...',
                      )
                    else
                      Text('Preparing upload...'),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Use provider to upload all pending PODs
      final result = await podProvider.uploadAllPendingPods();

      // Close progress dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show result
      if (mounted) {
        String message = result['message'] ?? 'Upload completed';
        Color backgroundColor;

        if (result['success'] == true) {
          final data = result['data'] as Map<String, dynamic>?;
          final successCount = data?['successCount'] ?? 0;
          final total = data?['total'] ?? 0;

          if (successCount == total) {
            backgroundColor = AppColors.mediumGreen;
          } else {
            backgroundColor = Colors.orange;
          }
        } else {
          backgroundColor = Colors.red;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('\n=== POD UPLOAD DEBUG: CRITICAL ERROR ===');
      print('DEBUG: Error: $e');
      print('DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        Navigator.pop(context); // Close progress dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during upload: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onNavTap(int index) {
    if (index == 1) {
      // Already on Deliveries, do nothing
      return;
    }
    // Pop back to dashboard and let it handle the navigation
    Navigator.pop(context, index);
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders,
      OrderStatusProvider orderStatusProvider) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.mediumGreen,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            child: EmptyStateWidget(
              icon: Icons.inbox_outlined,
              message: 'No deliveries found',
              subtitle: _orderError,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.mediumGreen,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final cardData =
              _convertOrderToCardFormat(order, orderStatusProvider);

          // Parse order_status as ID to get description
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
              ? orderStatusProvider
                      .getOrderStatusDescription(statusId)
                      ?.toLowerCase() ??
                  ''
              : '';

          // Determine action button based on status
          String? actionLabel;
          VoidCallback? actionCallback;

          if (statusDesc == 'ready for pickup' ||
              statusDesc == 'ready-for-pickup') {
            actionLabel = 'Pickup';
            actionCallback = () => _handlePickup(order);
          } else if (statusDesc == 'in-transit' || statusDesc == 'in transit') {
            actionLabel = 'Delivered';
            actionCallback = () => _handleDelivered(order);
          }

          return OrderItemCard(
            order: cardData,
            showDetails: true,
            onUpdateStatus: actionCallback,
            actionButtonLabel: actionLabel,
            onViewDetails: () {
              _showOrderDetails(order);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            ViewHeader(
              title: 'All Deliveries',
              onBack: () {
                Navigator.pop(context);
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer<PodProvider>(
                    builder: (context, podProvider, child) {
                      return IconButton(
                        icon: podProvider.isUploading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.mediumGreen,
                                ),
                              )
                            : Icon(Icons.cloud_upload,
                                color: AppColors.mediumGreen),
                        onPressed: podProvider.isUploading
                            ? null
                            : _uploadPendingPhotos,
                        tooltip: 'Upload Pending Photos',
                      );
                    },
                  ),
                  if (_orderError != null)
                    IconButton(
                      icon: Icon(Icons.refresh, color: AppColors.mediumGreen),
                      onPressed: () => _loadOrders(useCache: false),
                      tooltip: 'Retry',
                    ),
                ],
              ),
            ),
            // Status filter tabs (matching myOrderScreen style)
            Container(
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
                tabs:
                    _statusTabs.map((tab) => Tab(text: tab['label'])).toList(),
              ),
            ),
            Expanded(
              child: _isLoadingOrders
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.mediumGreen,
                      ),
                    )
                  : Consumer<OrderStatusProvider>(
                      builder: (context, orderStatusProvider, child) {
                        return TabBarView(
                          controller: _tabController,
                          children: _statusTabs.map((tab) {
                            final filteredOrders = _filterOrdersByStatus(
                                tab['status'], orderStatusProvider);
                            return _buildOrdersList(
                                filteredOrders, orderStatusProvider);
                          }).toList(),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: 1, // Deliveries tab is selected
          onTap: _onNavTap,
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
      ),
    );
  }
}
