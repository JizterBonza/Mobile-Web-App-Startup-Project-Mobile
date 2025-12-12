import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../provider/address_provider.dart';
import '../common/editAddressScreen.dart';

class ShippingAddressScreen extends StatefulWidget {
  final bool isSelectionMode;

  const ShippingAddressScreen({
    super.key,
    this.isSelectionMode = false,
  });

  @override
  State<ShippingAddressScreen> createState() => _ShippingAddressScreenState();
}

class _ShippingAddressScreenState extends State<ShippingAddressScreen> {
  int? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    // Fetch addresses when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAddresses();
    });
  }

  Future<void> _loadAddresses() async {
    final addressProvider = context.read<AddressProvider>();
    await addressProvider.fetchAddresses();

    // Select the default address initially
    if (addressProvider.defaultAddress != null && _selectedAddressId == null) {
      setState(() {
        _selectedAddressId = addressProvider.defaultAddress!.id;
      });
    } else if (addressProvider.addresses.isNotEmpty &&
        _selectedAddressId == null) {
      setState(() {
        _selectedAddressId = addressProvider.addresses.first.id;
      });
    }
  }

  void _selectAddress(int addressId) {
    setState(() {
      _selectedAddressId = addressId;
    });
  }

  void _confirmSelection() {
    final addressProvider = context.read<AddressProvider>();
    final selectedAddress = addressProvider.getAddressById(_selectedAddressId!);

    if (selectedAddress != null) {
      Navigator.pop(context, selectedAddress.toMap());
    }
  }

  Future<void> _addNewAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAddressScreen(),
      ),
    );

    if (result != null && mounted) {
      // Refresh the list after adding
      await _loadAddresses();
    }
  }

  Future<void> _editAddress(Map<String, dynamic> address) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAddressScreen(
          existingAddress: address,
        ),
      ),
    );

    if (result != null && mounted) {
      // Refresh the list after editing
      await _loadAddresses();
    }
  }

  Future<void> _deleteAddress(int addressId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Address'),
        content: Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final addressProvider = context.read<AddressProvider>();
      final result = await addressProvider.deleteAddress(addressId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Address deleted'),
            backgroundColor:
                result['success'] == true ? Colors.green[700] : Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _setDefaultAddress(int addressId) async {
    final addressProvider = context.read<AddressProvider>();
    final result = await addressProvider.setDefaultAddress(addressId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Default address updated'),
          backgroundColor:
              result['success'] == true ? Colors.green[700] : Colors.red[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.isSelectionMode ? 'Select Address' : 'Shipping Addresses',
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
            onPressed: _addNewAddress,
            icon: Icon(Icons.add),
            tooltip: 'Add New Address',
          ),
        ],
      ),
      body: Consumer<AddressProvider>(
        builder: (context, addressProvider, child) {
          if (addressProvider.isLoading) {
            return _buildLoadingState();
          }

          if (addressProvider.error != null &&
              addressProvider.addresses.isEmpty) {
            return _buildErrorState(addressProvider.error!);
          }

          if (addressProvider.addresses.isEmpty) {
            return _buildEmptyState();
          }

          return _buildAddressList(addressProvider);
        },
      ),
      bottomNavigationBar: Consumer<AddressProvider>(
        builder: (context, addressProvider, child) {
          if (widget.isSelectionMode && addressProvider.addresses.isNotEmpty) {
            return _buildSelectionBottomBar();
          }
          return SizedBox.shrink();
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
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.mediumGreen),
          ),
          SizedBox(height: 16),
          Text(
            'Loading addresses...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red[300],
            ),
            SizedBox(height: 16),
            Text(
              'Failed to load addresses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAddresses,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mediumGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.mediumGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_off_outlined,
                size: 60,
                color: AppColors.mediumGreen.withOpacity(0.6),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Addresses Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'You haven\'t added any shipping addresses yet.\nAdd one to make checkout faster!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _addNewAddress,
              icon: Icon(Icons.add_location_alt_outlined),
              label: Text('Add New Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mediumGreen,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressList(AddressProvider addressProvider) {
    final addresses = addressProvider.getAddressesAsMapList();

    return RefreshIndicator(
      onRefresh: _loadAddresses,
      color: AppColors.mediumGreen,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: addresses.length,
        itemBuilder: (context, index) {
          final address = addresses[index];
          final isSelected = _selectedAddressId == address['id'];
          final isDefault = address['is_default'] == true;

          return _buildAddressCard(
            address: address,
            isSelected: isSelected,
            isDefault: isDefault,
            onTap: () {
              if (widget.isSelectionMode) {
                _selectAddress(address['id']);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildAddressCard({
    required Map<String, dynamic> address,
    required bool isSelected,
    required bool isDefault,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.mediumGreen
              : (isDefault
                  ? AppColors.mediumGreen.withOpacity(0.3)
                  : Colors.grey[300]!),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with label and badges
                Row(
                  children: [
                    // Address label with icon
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            _getLabelColor(address['label']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getLabelIcon(address['label']),
                            size: 16,
                            color: _getLabelColor(address['label']),
                          ),
                          SizedBox(width: 6),
                          Text(
                            address['label'] ?? 'Address',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _getLabelColor(address['label']),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    // Default badge
                    if (isDefault)
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.mediumGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Spacer(),
                    // Selection indicator or menu
                    if (widget.isSelectionMode)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.mediumGreen
                                : Colors.grey[400]!,
                            width: 2,
                          ),
                          color: isSelected
                              ? AppColors.mediumGreen
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      )
                    else
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'Edit') {
                            _editAddress(address);
                          } else if (value == 'Set as Default') {
                            _setDefaultAddress(address['id']);
                          } else if (value == 'Delete') {
                            _deleteAddress(address['id']);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'Edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 20, color: Colors.grey[700]),
                                SizedBox(width: 12),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          if (!isDefault)
                            PopupMenuItem(
                              value: 'Set as Default',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 20, color: Colors.grey[700]),
                                  SizedBox(width: 12),
                                  Text('Set as Default'),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'Delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 20, color: Colors.red[600]),
                                SizedBox(width: 12),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red[600])),
                              ],
                            ),
                          ),
                        ],
                        icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                      ),
                  ],
                ),
                SizedBox(height: 12),

                // Recipient name
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address['recipient_name'] ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // Phone number
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 8),
                    Text(
                      address['phone'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // Full address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatFullAddress(address),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatFullAddress(Map<String, dynamic> address) {
    final parts = <String>[];

    if (address['address_line1'] != null &&
        address['address_line1'].toString().isNotEmpty) {
      parts.add(address['address_line1']);
    }
    if (address['address_line2'] != null &&
        address['address_line2'].toString().isNotEmpty) {
      parts.add(address['address_line2']);
    }
    if (address['city'] != null && address['city'].toString().isNotEmpty) {
      parts.add(address['city']);
    }
    if (address['province'] != null &&
        address['province'].toString().isNotEmpty) {
      parts.add(address['province']);
    }
    if (address['postal_code'] != null &&
        address['postal_code'].toString().isNotEmpty) {
      parts.add(address['postal_code']);
    }

    return parts.join(', ');
  }

  Color _getLabelColor(String? label) {
    switch (label?.toLowerCase()) {
      case 'home':
        return AppColors.mediumGreen;
      case 'office':
        return Colors.blue[700]!;
      case 'parents house':
        return Colors.orange[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  IconData _getLabelIcon(String? label) {
    switch (label?.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'office':
        return Icons.business_outlined;
      case 'parents house':
        return Icons.family_restroom_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  Widget _buildSelectionBottomBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _selectedAddressId != null ? _confirmSelection : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.mediumGreen,
            disabledBackgroundColor: Colors.grey[400],
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            'Use This Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
