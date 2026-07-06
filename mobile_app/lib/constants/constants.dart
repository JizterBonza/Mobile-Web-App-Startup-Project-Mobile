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

  /// Web OAuth client ID (Laravel GOOGLE_CLIENT_ID). Used as serverClientId for id_token.
  static String get googleWebClientId {
    final id = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    if (id == null || id.isEmpty) {
      throw Exception(
        'GOOGLE_WEB_CLIENT_ID not found in .env. Use the Web application OAuth client ID from Google Cloud Console.',
      );
    }
    return id;
  }

  /// iOS OAuth client ID (optional on Android; required for native sign-in on iOS).
  static String? get googleIosClientId {
    final id = dotenv.env['GOOGLE_IOS_CLIENT_ID'];
    if (id == null || id.isEmpty) return null;
    return id;
  }
}

class AppColors {
  AppColors._();

  // Primary green brand palette (from dashboard UI)
  static const Color primaryGreen      = Color(0xFF0F6B42);
  static const Color primaryGreenDark  = Color(0xFF064D2B);
  static const Color primaryGreenLight = Color(0xFF1E9B6A);

  // Accent yellow (notification badges)
  static const Color accentAmber      = Color(0xFFFFB800);
  static const Color accentAmberDark  = Color(0xFFE6A600);

  // Surface / background
  static const Color surfaceLight     = Color(0xFFF2F2F2);
  static const Color surfaceMuted     = Color(0xFFFAFAFA);
  static const Color borderDefault    = Color(0xFFE0E0E0);

  // Text
  static const Color textPrimary      = Color(0xFF1F2937);
  static const Color textSecondary    = Color(0xFF757575);
  static const Color textOnPrimary    = Color(0xFFFFFFFF);

  // Semantic feedback
  static const Color success          = Color(0xFF0F6B42);
  static const Color warning          = Color(0xFFF57C00);
  static const Color error            = Color(0xFFD32F2F);

  // Order status semantic aliases
  static const Color statusPending        = warning;
  static const Color statusProcessing     = primaryGreenLight;
  static const Color statusReadyForPickup = success;
  static const Color statusInTransit      = primaryGreenLight;
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
