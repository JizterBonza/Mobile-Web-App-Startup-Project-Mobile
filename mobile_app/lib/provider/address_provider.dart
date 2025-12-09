import 'package:flutter/material.dart';
import '../models/addressModel.dart';
import '../services/address_service.dart';

/// Provider for managing address state and caching
class AddressProvider with ChangeNotifier {
  final AddressService _addressService = AddressService();

  List<AddressModel> _addresses = [];
  AddressModel? _selectedAddress;
  AddressModel? _defaultAddress;
  bool _isLoading = false;
  String? _error;
  bool _fromCache = false;

  // Getters
  List<AddressModel> get addresses => _addresses;
  AddressModel? get selectedAddress => _selectedAddress;
  AddressModel? get defaultAddress => _defaultAddress;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get fromCache => _fromCache;
  bool get hasAddresses => _addresses.isNotEmpty;
  int get addressCount => _addresses.length;

  /// Fetch addresses from API, falls back to cache if API fails
  Future<void> fetchAddresses({bool useCache = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final addresses = await _addressService.fetchAddresses();

      if (addresses.isNotEmpty || _addresses.isEmpty) {
        _addresses = addresses;
        _fromCache = false;
        _error = null;

        // Update default address
        _updateDefaultAddress();

        // If no address is selected, select the default one
        if (_selectedAddress == null && _defaultAddress != null) {
          _selectedAddress = _defaultAddress;
        }
      }
    } catch (e) {
      if (useCache && _addresses.isNotEmpty) {
        // Use cached data if available
        _fromCache = true;
        _error = null;
        print('Using cached addresses due to connection error: $e');
      } else {
        _error = e.toString();
        if (_addresses.isEmpty) {
          _addresses = [];
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new address
  Future<Map<String, dynamic>> addAddress(AddressModel address) async {
    try {
      final result = await _addressService.addAddress(address);

      if (result['success'] == true) {
        // Refresh addresses after successful add
        await fetchAddresses(useCache: false);
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error adding address: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Add address from map data (used by EditAddressScreen)
  Future<Map<String, dynamic>> addAddressFromMap(
      Map<String, dynamic> addressData) async {
    final address = AddressModel(
      label: addressData['label'] ?? '',
      recipientName: addressData['recipient_name'] ?? '',
      phone: addressData['phone'] ?? '',
      addressLine1: addressData['address_line1'] ?? '',
      addressLine2: addressData['address_line2'],
      postalCode: addressData['postal_code'],
      latitude: addressData['latitude'] is double
          ? addressData['latitude']
          : double.tryParse(addressData['latitude']?.toString() ?? ''),
      longitude: addressData['longitude'] is double
          ? addressData['longitude']
          : double.tryParse(addressData['longitude']?.toString() ?? ''),
      mapAddress: addressData['map_address'],
      isDefault: addressData['is_default'] == true,
      // Address breakdown
      street: addressData['street'],
      barangay: addressData['barangay'],
      city: addressData['city'],
      province: addressData['province'],
      country: addressData['country'],
      // Additional fields for backend
      region: addressData['region'],
      addressType: addressData['address_type'],
      isActive: addressData['is_active'] ?? true,
    );

    return await addAddress(address);
  }

  /// Update an existing address
  Future<Map<String, dynamic>> updateAddress(AddressModel address) async {
    try {
      final result = await _addressService.updateAddress(address);

      if (result['success'] == true) {
        // Update local state
        final index = _addresses.indexWhere((a) => a.id == address.id);
        if (index != -1) {
          _addresses[index] = address;

          // Update selected/default if needed
          if (_selectedAddress?.id == address.id) {
            _selectedAddress = address;
          }
          if (_defaultAddress?.id == address.id) {
            _defaultAddress = address;
          }

          notifyListeners();
        }

        // Optionally refresh from server
        await fetchAddresses(useCache: false);
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating address: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Update address from map data (used by EditAddressScreen)
  Future<Map<String, dynamic>> updateAddressFromMap(
      Map<String, dynamic> addressData) async {
    final address = AddressModel(
      id: addressData['id'] is int
          ? addressData['id']
          : int.tryParse(addressData['id']?.toString() ?? ''),
      label: addressData['label'] ?? '',
      recipientName: addressData['recipient_name'] ?? '',
      phone: addressData['phone'] ?? '',
      addressLine1: addressData['address_line1'] ?? '',
      addressLine2: addressData['address_line2'],
      postalCode: addressData['postal_code'],
      latitude: addressData['latitude'] is double
          ? addressData['latitude']
          : double.tryParse(addressData['latitude']?.toString() ?? ''),
      longitude: addressData['longitude'] is double
          ? addressData['longitude']
          : double.tryParse(addressData['longitude']?.toString() ?? ''),
      mapAddress: addressData['map_address'],
      isDefault: addressData['is_default'] == true,
      // Address breakdown
      street: addressData['street'],
      barangay: addressData['barangay'],
      city: addressData['city'],
      province: addressData['province'],
      country: addressData['country'],
      // Additional fields for backend
      region: addressData['region'],
      addressType: addressData['address_type'],
      isActive: addressData['is_active'] ?? true,
    );

    return await updateAddress(address);
  }

  /// Delete an address
  Future<Map<String, dynamic>> deleteAddress(int addressId) async {
    try {
      final result = await _addressService.deleteAddress(addressId);

      if (result['success'] == true) {
        // Remove from local state
        _addresses.removeWhere((a) => a.id == addressId);

        // Clear selected if it was deleted
        if (_selectedAddress?.id == addressId) {
          _selectedAddress = _defaultAddress ??
              (_addresses.isNotEmpty ? _addresses.first : null);
        }

        // Update default address
        _updateDefaultAddress();

        notifyListeners();
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error deleting address: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Set an address as the default
  Future<Map<String, dynamic>> setDefaultAddress(int addressId) async {
    try {
      final result = await _addressService.setDefaultAddress(addressId);

      if (result['success'] == true) {
        // Update local state
        for (var i = 0; i < _addresses.length; i++) {
          _addresses[i] = _addresses[i].copyWith(
            isDefault: _addresses[i].id == addressId,
          );
        }

        _updateDefaultAddress();
        notifyListeners();
      }

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error setting default address: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Select an address (for checkout, etc.)
  void selectAddress(AddressModel address) {
    _selectedAddress = address;
    notifyListeners();
  }

  /// Select address by ID
  void selectAddressById(int addressId) {
    final address = _addresses.firstWhere(
      (a) => a.id == addressId,
      orElse: () => _addresses.first,
    );
    selectAddress(address);
  }

  /// Clear selected address
  void clearSelectedAddress() {
    _selectedAddress = null;
    notifyListeners();
  }

  /// Get address by ID
  AddressModel? getAddressById(int addressId) {
    try {
      return _addresses.firstWhere((a) => a.id == addressId);
    } catch (e) {
      return null;
    }
  }

  /// Get addresses as Map list (for compatibility with existing screens)
  List<Map<String, dynamic>> getAddressesAsMapList() {
    return _addresses.map((a) => a.toMap()).toList();
  }

  /// Get selected address as Map (for compatibility with existing screens)
  Map<String, dynamic>? getSelectedAddressAsMap() {
    return _selectedAddress?.toMap();
  }

  /// Update default address reference
  void _updateDefaultAddress() {
    try {
      _defaultAddress = _addresses.firstWhere((a) => a.isDefault);
    } catch (e) {
      // No default address found, use first address if available
      _defaultAddress = _addresses.isNotEmpty ? _addresses.first : null;
    }
  }

  /// Clear address cache
  void clearCache() {
    _addresses = [];
    _selectedAddress = null;
    _defaultAddress = null;
    _fromCache = false;
    _error = null;
    _addressService.clearCache();
    notifyListeners();
  }

  /// Get cached addresses without fetching from API
  List<AddressModel> getCachedAddresses() {
    return _addresses;
  }

  /// Check if a specific address is selected
  bool isAddressSelected(int addressId) {
    return _selectedAddress?.id == addressId;
  }

  /// Check if a specific address is the default
  bool isAddressDefault(int addressId) {
    return _defaultAddress?.id == addressId;
  }
}
