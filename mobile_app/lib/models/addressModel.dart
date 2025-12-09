import 'package:hive/hive.dart';

part 'addressModel.g.dart';

/// Model class representing a shipping address
@HiveType(typeId: 5)
class AddressModel {
  @HiveField(0)
  final int? id;

  @HiveField(1)
  final String label; // address_label

  @HiveField(2)
  final String recipientName;

  @HiveField(3)
  final String phone; // contact_number

  @HiveField(4)
  final String addressLine1; // full_address (optional in API)

  @HiveField(5)
  final String? addressLine2; // additional_notes

  @HiveField(6)
  final String? postalCode;

  @HiveField(7)
  final double? latitude;

  @HiveField(8)
  final double? longitude;

  @HiveField(9)
  final String? mapAddress;

  @HiveField(10)
  final bool isDefault;

  @HiveField(11)
  final DateTime? createdAt;

  @HiveField(12)
  final DateTime? updatedAt;

  // Address breakdown fields
  @HiveField(13)
  final String? street; // street_address (required in API)

  @HiveField(14)
  final String? barangay;

  @HiveField(15)
  final String? city; // city_municipality (required in API)

  @HiveField(16)
  final String? province;

  @HiveField(17)
  final String? country;

  // Additional fields for backend
  @HiveField(18)
  final String? region;

  @HiveField(19)
  final String? addressType; // home, work, farm, other

  @HiveField(20)
  final bool isActive;

  AddressModel({
    this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.addressLine1,
    this.addressLine2,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.mapAddress,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
    this.street,
    this.barangay,
    this.city,
    this.province,
    this.country,
    this.region,
    this.addressType,
    this.isActive = true,
  });

  /// Create AddressModel from JSON map (API response)
  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
      // address_label (API) or label (fallback)
      label:
          json['address_label']?.toString() ?? json['label']?.toString() ?? '',
      recipientName: json['recipient_name']?.toString() ?? '',
      // contact_number (API) or phone (fallback)
      phone:
          json['contact_number']?.toString() ?? json['phone']?.toString() ?? '',
      // full_address (API) or address_line1 (fallback)
      addressLine1: json['full_address']?.toString() ??
          json['address_line1']?.toString() ??
          '',
      // additional_notes (API) or address_line2 (fallback)
      addressLine2: json['additional_notes']?.toString() ??
          json['address_line2']?.toString(),
      postalCode: json['postal_code']?.toString(),
      latitude: json['latitude'] is double
          ? json['latitude']
          : double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: json['longitude'] is double
          ? json['longitude']
          : double.tryParse(json['longitude']?.toString() ?? ''),
      mapAddress: json['map_address']?.toString(),
      isDefault: json['is_default'] == true || json['is_default'] == 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      // street_address (API) or street (fallback)
      street: json['street_address']?.toString() ?? json['street']?.toString(),
      barangay: json['barangay']?.toString(),
      // city_municipality (API) or city (fallback)
      city: json['city_municipality']?.toString() ?? json['city']?.toString(),
      province: json['province']?.toString(),
      country: json['country']?.toString(),
      region: json['region']?.toString(),
      addressType: json['address_type']?.toString(),
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['is_active'] == null,
    );
  }

  /// Convert AddressModel to JSON map (for API requests)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'address_label': label,
      'address_type': addressType ?? _getAddressTypeFromLabel(label),
      'recipient_name': recipientName,
      'contact_number': phone,
      // Required fields
      'city_municipality': city ?? '',
      'street_address': street ?? addressLine1,
      // Optional fields
      if (region != null && region!.isNotEmpty) 'region': region,
      if (province != null && province!.isNotEmpty) 'province': province,
      if (barangay != null && barangay!.isNotEmpty) 'barangay': barangay,
      if (postalCode != null && postalCode!.isNotEmpty)
        'postal_code': postalCode,
      if (addressLine1.isNotEmpty) 'full_address': addressLine1,
      if (addressLine2 != null && addressLine2!.isNotEmpty)
        'additional_notes': addressLine2,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'is_default': isDefault,
      'is_active': isActive,
    };
  }

  /// Get address_type from label
  String _getAddressTypeFromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return 'home';
      case 'office':
      case 'work':
        return 'work';
      case 'farm':
        return 'farm';
      default:
        return 'other';
    }
  }

  /// Convert to the Map format used in screens (internal use)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'address_line1': addressLine1,
      'address_line2': addressLine2 ?? '',
      'postal_code': postalCode ?? '',
      'latitude': latitude,
      'longitude': longitude,
      'map_address': mapAddress ?? '',
      'is_default': isDefault,
      'street': street ?? '',
      'barangay': barangay ?? '',
      'city': city ?? '',
      'province': province ?? '',
      'country': country ?? '',
      'region': region ?? '',
      'address_type': addressType ?? '',
      'is_active': isActive,
    };
  }

  /// Create a copy with modified fields
  AddressModel copyWith({
    int? id,
    String? label,
    String? recipientName,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? mapAddress,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? street,
    String? barangay,
    String? city,
    String? province,
    String? country,
    String? region,
    String? addressType,
    bool? isActive,
  }) {
    return AddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      mapAddress: mapAddress ?? this.mapAddress,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      street: street ?? this.street,
      barangay: barangay ?? this.barangay,
      city: city ?? this.city,
      province: province ?? this.province,
      country: country ?? this.country,
      region: region ?? this.region,
      addressType: addressType ?? this.addressType,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Get formatted full address
  String get fullAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (barangay != null && barangay!.isNotEmpty) parts.add(barangay!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (province != null && province!.isNotEmpty) parts.add(province!);
    if (region != null && region!.isNotEmpty) parts.add(region!);
    if (postalCode != null && postalCode!.isNotEmpty) parts.add(postalCode!);
    return parts.isNotEmpty ? parts.join(', ') : addressLine1;
  }

  /// Check if location coordinates are available
  bool get hasLocation => latitude != null && longitude != null;

  @override
  String toString() {
    return 'AddressModel(id: $id, label: $label, recipientName: $recipientName, city: $city, province: $province, isDefault: $isDefault)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AddressModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
