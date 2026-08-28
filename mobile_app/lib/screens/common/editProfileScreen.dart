import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/constants.dart';
import '../../models/addressModel.dart';
import '../../provider/address_provider.dart';
import '../../services/api_service.dart';
import '../../utils/media_url.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/skeletons/app_skeletons.dart';
import '../../widgets/user_profile_avatar.dart';
import 'editAddressScreen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isInitialLoading = true;
  AddressModel? _defaultAddress;
  String? _profileImageUrl;
  XFile? _selectedProfileImage;
  Uint8List? _selectedProfileImageBytes;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final firstName = await ApiService.getFirstName();
      final middleName = await ApiService.getMiddleName();
      final lastName = await ApiService.getLastName();
      final userName = await ApiService.getUserName();
      final userEmail = await ApiService.getUserEmail();
      final userPhone = await ApiService.getUserMobileNumber();
      final userAddress = await ApiService.getUserAddress();
      final profileImageUrl = await ApiService.getProfileImageUrl();

      // Fetch addresses from provider
      if (mounted) {
        final addressProvider = context.read<AddressProvider>();
        await addressProvider.fetchAddresses();
        _defaultAddress = addressProvider.defaultAddress;
      }

      if (mounted) {
        setState(() {
          _firstNameController.text = firstName ?? '';
          _middleNameController.text = middleName ?? '';
          _lastNameController.text = lastName ?? '';
          _usernameController.text = userName ?? '';
          _emailController.text = userEmail ?? '';
          _phoneController.text = userPhone ?? '';
          // Use default address from provider if available, otherwise use userAddress
          if (_defaultAddress != null) {
            _addressController.text = _defaultAddress!.fullAddress;
          } else {
            _addressController.text = userAddress ?? '';
          }
          _profileImageUrl = profileImageUrl;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.updateProfile(
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim().isEmpty
            ? null
            : _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        shippingAddress: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        profileImage: _selectedProfileImage,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final updatedImageUrl = result['profile_image_url']?.toString();
        final resolvedImageUrl = resolveMediaUrl(
          updatedImageUrl?.isNotEmpty == true
              ? updatedImageUrl
              : _profileImageUrl,
        );
        if (_selectedProfileImage != null && resolvedImageUrl != null) {
          await NetworkImage(resolvedImageUrl).evict();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Profile updated successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ??
                'Failed to update profile. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showProfileImageSourceSheet() async {
    if (_isLoading) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickProfileImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickProfileImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(source: source);
      if (image == null) return;

      final validationError = await ApiService.validateProfileImage(image);
      if (validationError != null) {
        if (mounted) _showImageError(validationError);
        return;
      }

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedProfileImage = image;
        _selectedProfileImageBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      final sourceName = source == ImageSource.camera ? 'camera' : 'gallery';
      _showImageError('Could not open $sourceName: $e');
    }
  }

  void _showImageError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _navigateToAddAddress() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const EditAddressScreen(),
      ),
    );

    // If address was added successfully, refresh addresses from provider
    if (result != null && mounted) {
      final addressProvider = context.read<AddressProvider>();
      await addressProvider.fetchAddresses();

      setState(() {
        _defaultAddress = addressProvider.defaultAddress;
        if (_defaultAddress != null) {
          _addressController.text = _defaultAddress!.fullAddress;
        } else {
          // Fallback to result data if no default address
          final addressParts = <String>[];
          if (result['address_line1'] != null &&
              result['address_line1'].toString().isNotEmpty) {
            addressParts.add(result['address_line1']);
          }
          if (result['city'] != null && result['city'].toString().isNotEmpty) {
            addressParts.add(result['city']);
          }
          if (result['province'] != null &&
              result['province'].toString().isNotEmpty) {
            addressParts.add(result['province']);
          }
          _addressController.text = addressParts.join(', ');
        }
      });
    }
  }

  Widget _buildAddAddressButton() {
    return GestureDetector(
      onTap: _navigateToAddAddress,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryGreen.withOpacity(0.3),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_location_alt_outlined,
                color: AppColors.primaryGreen,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Shipping Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tap to add your delivery location',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.primaryGreen,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAddressCard() {
    final address = _defaultAddress!;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with label and default badge
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getLabelIcon(address.label),
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          address.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      address.recipientName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button
              GestureDetector(
                onTap: () => _navigateToEditAddress(address),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: AppColors.primaryGreen,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Address details
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address.fullAddress,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (address.phone.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 8),
                      Text(
                        address.phone,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLabelIcon(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'office':
      case 'work':
        return Icons.business_outlined;
      case 'parents house':
        return Icons.family_restroom_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  Future<void> _navigateToEditAddress(AddressModel address) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => EditAddressScreen(
          existingAddress: address.toMap(),
        ),
      ),
    );

    // If address was updated successfully, refresh from provider
    if (result != null && mounted) {
      final addressProvider = context.read<AddressProvider>();
      await addressProvider.fetchAddresses();

      setState(() {
        _defaultAddress = addressProvider.defaultAddress;
        if (_defaultAddress != null) {
          _addressController.text = _defaultAddress!.fullAddress;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
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
      body: _isInitialLoading
          ? const GenericListSkeleton(count: 5, itemHeight: 56)
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header section
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Semantics(
                            button: true,
                            label: 'Change profile photo',
                            child: GestureDetector(
                              onTap: _showProfileImageSourceSheet,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  UserProfileAvatar(
                                    size: 80,
                                    imageUrl: _profileImageUrl,
                                    imageBytes: _selectedProfileImageBytes,
                                    backgroundColor:
                                        AppColors.primaryGreen.withOpacity(0.1),
                                    iconColor: AppColors.primaryGreen,
                                    iconSize: 40,
                                    border: Border.all(
                                      color: AppColors.primaryGreen
                                          .withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  Positioned(
                                    right: -4,
                                    bottom: -4,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isLoading
                                ? null
                                : _showProfileImageSourceSheet,
                            icon: const Icon(Icons.upload_outlined, size: 18),
                            label: Text(
                              _selectedProfileImage == null
                                  ? 'Change photo'
                                  : 'Photo selected',
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Update Your Profile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Edit your information below',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Form fields section
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                          SizedBox(height: 20),
                          // First Name field
                          CustomTextFormField(
                            controller: _firstNameController,
                            labelText: 'First Name',
                            prefixIcon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your first name';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          // Middle Name field (optional)
                          CustomTextFormField(
                            controller: _middleNameController,
                            labelText: 'Middle Name (Optional)',
                            prefixIcon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                          ),
                          SizedBox(height: 16),
                          // Last Name field
                          CustomTextFormField(
                            controller: _lastNameController,
                            labelText: 'Last Name',
                            prefixIcon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your last name';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Account details section
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                          SizedBox(height: 20),
                          // Username field
                          CustomTextFormField(
                            controller: _usernameController,
                            labelText: 'Username',
                            prefixIcon: Icons.alternate_email,
                            textCapitalization: TextCapitalization.none,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a username';
                              }
                              if (value.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                                return 'Username can only contain letters, numbers, and underscores';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          // Email field
                          CustomTextFormField(
                            controller: _emailController,
                            labelText: 'Email',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          // Phone field
                          CustomTextFormField(
                            controller: _phoneController,
                            labelText: 'Phone Number (Optional)',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Address section
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shipping Address',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                          SizedBox(height: 20),
                          // Show default address, address field, or Add button
                          _defaultAddress != null
                              ? _buildDefaultAddressCard()
                              : _addressController.text.isEmpty
                                  ? _buildAddAddressButton()
                                  : CustomTextFormField(
                                      controller: _addressController,
                                      labelText: 'Shipping Address (Optional)',
                                      prefixIcon: Icons.location_on_outlined,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      keyboardType: TextInputType.streetAddress,
                                    ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Save button
                    CustomElevatedButton(
                      text: 'Save Changes',
                      isLoading: _isLoading,
                      onPressed: _saveProfile,
                    ),
                    SizedBox(height: 16),

                    // Cancel button
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
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
}
