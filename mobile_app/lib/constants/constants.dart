import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App configuration constants
class AppConfig {
  AppConfig._();

  /// Get the Google Maps API key from environment variables
  static String get googleMapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
          'GOOGLE_MAPS_API_KEY not found in .env file. Please add it.');
    }
    return key;
  }
}

class AppColors {
  AppColors._();

  // Brand greens
  static const Color deepForestGreen = Color(0xFF2D5016);
  static const Color mediumGreen = Color(0xFF4A7C2C);
  static const Color freshLeafGreen = Color(0xFF6B9E3E);

  // Neutrals and helpers
  static const Color lightGreyBackground =
      Color(0xFFFAFAFA); // approx Colors.grey[50]
  static const Color inputBorderGrey =
      Color(0xFFE0E0E0); // approx Colors.grey[300]
  static const Color textSecondaryGrey =
      Color(0xFF757575); // approx Colors.grey[600]
  static const Color textTertiaryGrey =
      Color(0xFF616161); // approx Colors.grey[700]

  // Order Status Colors
  static const Color statusPending = Color(0xFFF57C00); // Orange
  static const Color statusProcessing = Color(0xFF1976D2); // Blue
  static const Color statusReadyForPickup =
      Color(0xFF4A7C2C); // Green (mediumGreen)
  static const Color statusInTransit = Color(0xFF1565C0); // Blue 800
  static const Color statusDelivered = Color(0xFF4A7C2C); // Green (mediumGreen)
  static const Color statusCancelled = Color(0xFFD32F2F); // Red
  static const Color statusDefault = Color(0xFF757575); // Grey
}

/// Helper class for consistent order status colors across the app
class OrderStatusColors {
  OrderStatusColors._();

  /// Get color for a given order status
  static Color getColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.statusPending;
      case 'processing':
        return AppColors.statusProcessing;
      case 'ready for pickup':
        return AppColors.statusReadyForPickup;
      case 'in-transit':
      case 'in transit':
        return AppColors.statusInTransit;
      case 'delivered':
        return AppColors.statusDelivered;
      case 'cancelled':
        return AppColors.statusCancelled;
      default:
        return AppColors.statusDefault;
    }
  }

  /// Get background color (with opacity) for status badges
  static Color getBackgroundColor(String status) {
    return getColor(status).withOpacity(0.15);
  }

  /// Format status text for display
  static String formatStatus(String status) {
    // Handle hyphenated status
    if (status.toLowerCase() == 'in-transit') {
      return 'In Transit';
    }
    // Capitalize each word
    return status
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }
}
