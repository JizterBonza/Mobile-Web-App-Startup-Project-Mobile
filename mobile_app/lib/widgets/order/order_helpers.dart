import 'package:flutter/material.dart';
import '../../constants/constants.dart';

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

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return AppColors.mediumGreen;
      case 'in transit':
      case 'in-transit':
        return Colors.orange[600]!;
      case 'pending':
        return Colors.amber[700]!;
      case 'processing':
        return Colors.blue[600]!;
      case 'cancelled':
      case 'canceled':
        return Colors.red[600]!;
      default:
        return Colors.grey[500]!;
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Icons.check_circle;
      case 'in transit':
      case 'in-transit':
        return Icons.local_shipping;
      case 'pending':
        return Icons.schedule;
      case 'processing':
        return Icons.sync;
      case 'cancelled':
      case 'canceled':
        return Icons.cancel;
      default:
        return Icons.receipt_long;
    }
  }

  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
