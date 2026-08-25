import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../utils/url.dart';

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

  /// Public Reverb app key (not REVERB_APP_SECRET).
  static String get reverbAppKey => dotenv.env['REVERB_APP_KEY']?.trim() ?? '';

  static String get reverbHost {
    final host = dotenv.env['REVERB_HOST']?.trim();
    if (host != null && host.isNotEmpty) return host;
    return Uri.tryParse(Url.getUrl())?.host ?? '';
  }

  static String get reverbWsScheme {
    final raw = (dotenv.env['REVERB_SCHEME'] ?? 'https').trim().toLowerCase();
    if (raw == 'ws' || raw == 'wss') return raw;
    if (raw == 'https') return 'wss';
    return 'ws';
  }

  static int get reverbPort {
    final raw = dotenv.env['REVERB_PORT']?.trim();
    if (raw != null && raw.isNotEmpty) {
      return int.tryParse(raw) ?? (reverbWsScheme == 'wss' ? 443 : 8080);
    }
    return reverbWsScheme == 'wss' ? 443 : 8080;
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
  static const Color statusReadyForDelivery = success;
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
      case 'ready for delivery':
      case 'ready-for-delivery':
        return AppColors.statusReadyForDelivery;
      case 'ready for pickup':
      case 'ready-for-pickup':
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
    final normalized = status
        .trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    switch (normalized) {
      case 'in transit':
        return 'In Transit';
      case 'ready for delivery':
        return 'Ready for Delivery';
      case 'ready for pickup':
        return 'Ready for Pickup';
    }

    return status
        .trim()
        .replaceAll('-', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }
}
