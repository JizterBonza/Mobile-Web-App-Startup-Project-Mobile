import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/constants.dart';
import '../provider/address_provider.dart';
import '../widgets/form_widgets.dart';
import 'locationPickerScreen.dart';

class EditAddressScreen extends StatefulWidget {
  /// If null, creates a new address. If provided, edits the existing address.
  final Map<String, dynamic>? existingAddress;

  const EditAddressScreen({
    super.key,
    this.existingAddress,
  });

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _labelController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressLine1Controller =
      TextEditingController(); //Complete Address from picker
  final _addressLine2Controller = TextEditingController(); //Additional Details
  final _postalCodeController = TextEditingController(); //Postal Code

  bool _isLoading = false;
  bool _isDefault = false;
  String _selectedLabel = 'Home';

  // Location data
  double? _latitude;
  double? _longitude;
  String _selectedAddress = ''; //Selected Address from the map

  // Address breakdown from geocoding
  String? _street;
  String? _barangay;
  String? _city;
  String? _province;
  String? _country;

  // Predefined label options
  final List<Map<String, dynamic>> _labelOptions = [
    {
      'label': 'Home',
      'icon': Icons.home_outlined,
      'color': AppColors.mediumGreen
    },
    {'label': 'Office', 'icon': Icons.business_outlined, 'color': Colors.blue},
    {
      'label': 'Parents House',
      'icon': Icons.family_restroom_outlined,
      'color': Colors.orange
    },
    {
      'label': 'Other',
      'icon': Icons.location_on_outlined,
      'color': Colors.grey
    },
  ];

  bool get _isEditMode => widget.existingAddress != null;
  bool get _hasLocation => _latitude != null && _longitude != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _populateExistingData();
    }
  }

  void _populateExistingData() {
    final address = widget.existingAddress!;
    _selectedLabel = address['label'] ?? 'Home';
    _labelController.text = address['label'] ?? '';
    _recipientNameController.text = address['recipient_name'] ?? '';
    _phoneController.text = address['phone'] ?? '';
    _addressLine1Controller.text = address['address_line1'] ?? '';
    _addressLine2Controller.text = address['address_line2'] ?? '';
    _postalCodeController.text = address['postal_code'] ?? '';
    _isDefault = address['is_default'] == true;

    // Load location data if available
    if (address['latitude'] != null && address['longitude'] != null) {
      _latitude = address['latitude'] is double
          ? address['latitude']
          : double.tryParse(address['latitude'].toString());
      _longitude = address['longitude'] is double
          ? address['longitude']
          : double.tryParse(address['longitude'].toString());
      _selectedAddress =
          address['map_address'] ?? address['address_line1'] ?? '';
    }

    // Load address breakdown if available
    _street = address['street']?.toString();
    _barangay = address['barangay']?.toString();
    _city = address['city']?.toString();
    _province = address['province']?.toString();
    _country = address['country']?.toString();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _recipientNameController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation:
              _hasLocation ? LatLng(_latitude!, _longitude!) : null,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _selectedAddress = result['address'] ?? '';

        // Capture address breakdown
        _street = result['street'];
        _barangay = result['barangay'];
        _city = result['city'];
        _province = result['province'];
        _country = result['country'];

        // Update postal code if returned from picker
        if (result['postal_code'] != null &&
            result['postal_code'].toString().isNotEmpty) {
          _postalCodeController.text = result['postal_code'];
        }

        print('DEBUG: Selected address: $_selectedAddress');
        print('DEBUG: Street: $_street');
        print('DEBUG: Barangay: $_barangay');
        print('DEBUG: City: $_city');
        print('DEBUG: Province: $_province');
        print('DEBUG: Country: $_country');

        // Auto-fill address line 1 with the selected address
        if (_addressLine1Controller.text.isEmpty) {
          _addressLine1Controller.text = _selectedAddress;
        }
      });
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if location is selected
    if (!_hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please pin your location on the map'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Build address data
    final addressData = {
      'id': _isEditMode
          ? widget.existingAddress!['id']
          : DateTime.now().millisecondsSinceEpoch,
      'label': _selectedLabel == 'Other'
          ? _labelController.text.trim()
          : _selectedLabel,
      'recipient_name': _recipientNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address_line1': _addressLine1Controller.text.trim(),
      'address_line2': _addressLine2Controller.text.trim(),
      'postal_code': _postalCodeController.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
      'map_address': _selectedAddress,
      'is_default': _isDefault,
      // Address breakdown from geocoding
      'street': _street ?? '',
      'barangay': _barangay ?? '',
      'city': _city ?? '',
      'province': _province ?? '',
      'country': _country ?? '',
    };

    try {
      final addressProvider = context.read<AddressProvider>();
      Map<String, dynamic> result;

      if (_isEditMode) {
        result = await addressProvider.updateAddressFromMap(addressData);
      } else {
        result = await addressProvider.addAddressFromMap(addressData);
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ??
                (_isEditMode
                    ? 'Address updated successfully!'
                    : 'Address added successfully!')),
            backgroundColor:
                result['success'] == true ? Colors.green[700] : Colors.red[700],
          ),
        );

        if (result['success'] == true) {
          Navigator.pop(context, addressData);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Address' : 'Add New Address',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[700]),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header section
              _buildHeaderSection(),
              SizedBox(height: 24),

              // Address Label section
              _buildLabelSection(),
              SizedBox(height: 16),

              // Contact Information section
              _buildContactSection(),
              SizedBox(height: 16),

              // Location Picker section (Google Maps)
              _buildLocationPickerSection(),
              SizedBox(height: 16),

              // Address Details section
              _buildAddressDetailsSection(),
              SizedBox(height: 16),

              // Default Address toggle
              _buildDefaultToggle(),
              SizedBox(height: 24),

              // Save button
              CustomElevatedButton(
                text: _isEditMode ? 'Update Address' : 'Save Address',
                isLoading: _isLoading,
                onPressed: _saveAddress,
              ),
              SizedBox(height: 16),

              // Cancel button
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.mediumGreen.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.mediumGreen.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              _isEditMode ? Icons.edit_location_alt : Icons.add_location_alt,
              size: 40,
              color: AppColors.mediumGreen,
            ),
          ),
          SizedBox(height: 16),
          Text(
            _isEditMode ? 'Update Address' : 'Add New Address',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),
          SizedBox(height: 4),
          Text(
            _isEditMode
                ? 'Update your address details below'
                : 'Fill in the details for your new address',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.label_outline,
                color: AppColors.mediumGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Address Label',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _labelOptions.map((option) {
              final isSelected = _selectedLabel == option['label'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedLabel = option['label'];
                  });
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (option['color'] as Color).withOpacity(0.15)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? option['color'] as Color
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        option['icon'] as IconData,
                        size: 20,
                        color: isSelected
                            ? option['color'] as Color
                            : Colors.grey[600],
                      ),
                      SizedBox(width: 8),
                      Text(
                        option['label'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? option['color'] as Color
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          // Custom label input when "Other" is selected
          if (_selectedLabel == 'Other') ...[
            SizedBox(height: 16),
            CustomTextFormField(
              controller: _labelController,
              labelText: 'Custom Label',
              hintText: 'e.g., Grandma\'s House, Vacation Home',
              prefixIcon: Icons.edit_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (_selectedLabel == 'Other' &&
                    (value == null || value.isEmpty)) {
                  return 'Please enter a label for this address';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                color: AppColors.mediumGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          // Recipient Name
          CustomTextFormField(
            controller: _recipientNameController,
            labelText: 'Recipient Name',
            hintText: 'Full name of the recipient',
            prefixIcon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the recipient name';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          // Phone Number
          CustomTextFormField(
            controller: _phoneController,
            labelText: 'Phone Number',
            hintText: '+63 9XX XXX XXXX',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a phone number';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPickerSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasLocation
              ? AppColors.mediumGreen.withOpacity(0.5)
              : Colors.grey[300]!,
          width: _hasLocation ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.map_outlined,
                color: AppColors.mediumGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Pin Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              Spacer(),
              if (_hasLocation)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.mediumGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: AppColors.mediumGreen,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Selected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mediumGreen,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Tap the button below to pin your exact delivery location on the map',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),

          // Map preview or placeholder
          GestureDetector(
            onTap: _openLocationPicker,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _hasLocation
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          // Static map preview placeholder
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.mediumGreen.withOpacity(0.1),
                                  AppColors.mediumGreen.withOpacity(0.05),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 40,
                                    color: AppColors.mediumGreen,
                                  ),
                                  SizedBox(height: 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Tap to change overlay
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit,
                                      size: 14, color: AppColors.mediumGreen),
                                  SizedBox(width: 4),
                                  Text(
                                    'Change',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mediumGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.mediumGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_location_alt_outlined,
                            size: 32,
                            color: AppColors.mediumGreen,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Tap to pin location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mediumGreen,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Open map to select your delivery location',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Selected address display
          if (_hasLocation && _selectedAddress.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mediumGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.mediumGreen.withOpacity(0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 18,
                    color: AppColors.mediumGreen,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedAddress,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressDetailsSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.home_outlined,
                color: AppColors.mediumGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Additional Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Add any extra details to help the rider find you',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),
          // Address Line 1
          CustomTextFormField(
            controller: _addressLine1Controller,
            labelText: 'Complete Address',
            hintText: 'House/Unit No., Street, Barangay, City',
            prefixIcon: Icons.location_on_outlined,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the complete address';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          // Address Line 2
          CustomTextFormField(
            controller: _addressLine2Controller,
            labelText: 'Landmark / Delivery Instructions (Optional)',
            hintText: 'e.g., Near 7-Eleven, Blue gate, Ring doorbell',
            prefixIcon: Icons.info_outline,
            textCapitalization: TextCapitalization.sentences,
          ),
          SizedBox(height: 16),
          // Postal Code
          CustomTextFormField(
            controller: _postalCodeController,
            labelText: 'Postal Code (Optional)',
            hintText: 'e.g., 1200',
            prefixIcon: Icons.markunread_mailbox_outlined,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultToggle() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isDefault
                  ? AppColors.mediumGreen.withOpacity(0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isDefault ? Icons.star : Icons.star_border,
              color: _isDefault ? AppColors.mediumGreen : Colors.grey[600],
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set as Default Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Use this address for all orders by default',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isDefault,
            onChanged: (value) {
              setState(() {
                _isDefault = value;
              });
            },
            activeColor: AppColors.mediumGreen,
          ),
        ],
      ),
    );
  }
}
