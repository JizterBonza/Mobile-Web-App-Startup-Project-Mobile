import 'package:flutter/material.dart';
import '../../utils/status_utils.dart' as status_utils;

/// Helper functions for order-related formatting and styling
class OrderHelpers {
  OrderHelpers._();

  static String formatOrderDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.tryParse(dateString);
      if (dateTime != null) {
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
        final period = dateTime.hour >= 12 ? 'PM' : 'AM';
        final minute = dateTime.minute.toString().padLeft(2, '0');
        return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at $hour:$minute $period';
      }
    } catch (e) {
      print('Error formatting date: $e');
    }
    return dateString;
  }

  static String formatPrice(dynamic price) {
    if (price == null) return '₱0.00';
    try {
      if (price is num) {
        return '₱${price.toStringAsFixed(2)}';
      } else if (price is String) {
        final parsed = double.tryParse(price);
        return parsed != null ? '₱${parsed.toStringAsFixed(2)}' : '₱0.00';
      }
    } catch (e) {
      print('Error formatting price: $e');
    }
    return '₱0.00';
  }

  /// Delegates to centralized status_utils.getStatusColor
  static Color getStatusColor(String status) =>
      status_utils.getStatusColor(status);

  /// Delegates to centralized status_utils.getStatusIcon
  static IconData getStatusIcon(String status) =>
      status_utils.getStatusIcon(status);

  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
