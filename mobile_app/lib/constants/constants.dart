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

  // Primary navy brand palette
  static const Color primaryNavy      = Color(0xFF1A2A5C);
  static const Color primaryNavyDark  = Color(0xFF0F1B40);
  static const Color primaryNavyLight = Color(0xFF2C3E80);

  // Accent amber
  static const Color accentAmber      = Color(0xFFF5A623);
  static const Color accentAmberDark  = Color(0xFFE89500);

  // Surface / background
  static const Color surfaceLight     = Color(0xFFF1F3F5);
  static const Color surfaceMuted     = Color(0xFFFAFAFA);
  static const Color borderDefault    = Color(0xFFE5E7EB);

  // Text
  static const Color textPrimary      = Color(0xFF1F2937);
  static const Color textSecondary    = Color(0xFF6B7280);

  // Semantic feedback
  static const Color success          = Color(0xFF2E7D32);
  static const Color warning          = Color(0xFFF57C00);
  static const Color error            = Color(0xFFD32F2F);

  // Order status semantic aliases
  static const Color statusPending        = warning;
  static const Color statusProcessing     = primaryNavyLight;
  static const Color statusReadyForPickup = success;
  static const Color statusInTransit      = primaryNavyLight;
  static const Color statusDelivered      = success;
  static const Color statusCancelled      = error;
  static const Color statusDefault        = textSecondary;
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
      case 'shipped':
        return AppColors.statusDelivered;
      case 'cancelled':
      case 'canceled':
        return AppColors.statusCancelled;
      default:
        return AppColors.statusDefault;
    }
  }

  /// Format status text for display
  static String formatStatus(String status) {
    if (status.toLowerCase() == 'in-transit') {
      return 'In Transit';
    }
    return status
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }
}
