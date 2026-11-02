import 'package:flutter/foundation.dart';

int farmInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

Map<String, dynamic> farmMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

List<Map<String, dynamic>> farmMaps(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];

/// Format server amounts without calculating charges or using binary doubles.
String farmMoney(dynamic value) {
  if (value == null) return 'Not confirmed';
  final parts = value.toString().split('.');
  if (!RegExp(r'^\d+$').hasMatch(parts.first)) return 'Not confirmed';
  return '₱${parts.first}.${(parts.length > 1 ? parts[1] : '').padRight(2, '0')}';
}

@immutable
class FarmBirdDetails {
  const FarmBirdDetails(
      {this.wingband = '', this.feather = '', this.feet = ''});
  final String wingband;
  final String feather;
  final String feet;

  bool get isEmpty => [wingband, feather, feet].every((v) => v.trim().isEmpty);
  Map<String, String> toJson() => {
        if (wingband.trim().isNotEmpty) 'wingband_no': wingband.trim(),
        if (feather.trim().isNotEmpty) 'feather_color': feather.trim(),
        if (feet.trim().isNotEmpty) 'feet_color': feet.trim(),
      };

  static Map<String, String> validate(List<FarmBirdDetails> birds) {
    return validateItems([birds]);
  }

  static Map<String, String> validateItems(List<List<FarmBirdDetails>> items) {
    final errors = <String, String>{};
    final wingbands = <String, String>{};
    for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
      final birds = items[itemIndex];
      for (var i = 0; i < birds.length; i++) {
        final bird = birds[i];
        final prefix = 'items.$itemIndex.birds.$i';
        if (bird.isEmpty) {
          errors[prefix] = 'Enter at least one detail for this bird.';
        }
        for (final entry in bird.toJson().entries) {
          if (entry.value.length > 100) {
            errors['$prefix.${entry.key}'] = 'Use at most 100 characters.';
          }
        }
        final band = bird.wingband.trim().toLowerCase();
        if (band.isNotEmpty) {
          final previous = wingbands[band];
          if (previous != null) {
            errors['$prefix.wingband_no'] = 'Wingband numbers must be unique.';
            errors['$previous.wingband_no'] =
                'Wingband numbers must be unique.';
          }
          wingbands[band] = prefix;
        }
      }
    }
    return errors;
  }
}

class FarmCartItem {
  FarmCartItem(this.data, this.farmId) {
    if (id <= 0 ||
        listingId <= 0 ||
        farmId <= 0 ||
        quantity <= 0 ||
        birdCount <= 0) {
      throw const FormatException('Invalid farm cart item.');
    }
  }
  final Map<String, dynamic> data;
  final int farmId;
  int get id => farmInt(data['id']);
  int get listingId => farmInt(data['listing_id']);
  int get quantity => farmInt(data['quantity']);
  int get birdCount => farmInt(data['bird_count']);
  bool get available => data['available'] != false;
  String get sellingUnit => data['selling_unit']?.toString() ?? '';
}

class FarmQuote {
  FarmQuote(this.data, DateTime receivedAt)
      : expiresAt = receivedAt
            .add(Duration(seconds: farmInt(data['expires_in_seconds']))) {
    if (token.isEmpty ||
        items.isEmpty ||
        farmInt(data['expires_in_seconds']) <= 0 ||
        data['currency'] != 'PHP' ||
        farmInt(data['bird_count']) <= 0 ||
        farmInt(data['box_count']) <= 0 ||
        [
          'chicken_subtotal',
          'deposit_due',
          'shipping_estimate_min',
          'shipping_estimate_max',
          'estimated_total_min',
          'estimated_total_max'
        ].any((key) => !RegExp(r'^\d+(?:\.\d{1,2})?$')
            .hasMatch(data[key]?.toString() ?? ''))) {
      throw const FormatException('Invalid checkout quote.');
    }
  }
  final Map<String, dynamic> data;
  final DateTime expiresAt;
  String get token => data['quote_token']?.toString() ?? '';
  List<Map<String, dynamic>> get items => farmMaps(data['items']);
  bool get expired => !DateTime.now().isBefore(expiresAt);
}

class FarmOrder {
  FarmOrder(this.data) {
    if (id <= 0) throw const FormatException('Invalid farm order.');
  }
  final Map<String, dynamic> data;
  int get id => farmInt(data['id']);
  String get code => data['order_code']?.toString() ?? '#$id';
  bool get depositPaid => data['deposit_paid'] == true;
  bool get balancePayable => data['balance_payable'] == true;
  bool get canPay => !closed && (balancePayable || !depositPaid);
  String get paymentActionLabel =>
      balancePayable ? 'Pay remaining balance' : 'Continue payment';
  bool get closed =>
      ['cancelled', 'canceled', 'completed'].contains(data['status']);
}

class FarmPaymentSession {
  const FarmPaymentSession(this.data, this.statusCode);
  final Map<String, dynamic> data;
  final int statusCode;
  String get state => data['status']?.toString() ?? '';
  String? get checkoutUrl {
    final uri = Uri.tryParse(data['checkout_url']?.toString() ?? '');
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri.toString()
        : null;
  }

  bool get unresolved =>
      statusCode == 202 || ['creating', 'creation_unknown'].contains(state);
}

class FarmApiException implements Exception {
  const FarmApiException(this.message,
      {this.statusCode,
      this.errors = const {},
      this.data = const {},
      this.retryAfter});
  final String message;
  final int? statusCode;
  final Map<String, dynamic> errors;
  final Map<String, dynamic> data;
  final String? retryAfter;
  @override
  String toString() => message;
}
