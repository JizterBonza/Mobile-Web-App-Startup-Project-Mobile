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

  static dynamic orderField(Map<String, dynamic> order, String key) {
    final detail = order['order_detail'] as Map<String, dynamic>?;
    return order[key] ?? detail?[key];
  }

  static double orderFeeAmount(Map<String, dynamic> order, String key) {
    final value = orderField(order, key);
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int orderFeeCount(Map<String, dynamic> order, String key) {
    final value = orderField(order, key);
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static bool orderFeeFlag(Map<String, dynamic> order, String key) {
    final value = orderField(order, key);
    if (value == null) return false;
    if (value is bool) return value;
    final normalized = value.toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
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

  static String _normalizePaymentStatusKey(String status) {
    return status.trim().toLowerCase().replaceAll(' ', '_');
  }

  /// Reads payment status from nested `payment` and top-level `payment_status`.
  /// When sources disagree, prefers definitive statuses (e.g. paid over pending).
  static String resolvePaymentStatus(Map<String, dynamic> order) {
    final payment = order['payment'] as Map<String, dynamic>?;
    final statuses = <String>[];

    for (final value in [
      payment?['status']?.toString(),
      payment?['payment_status']?.toString(),
      order['payment_status']?.toString(),
    ]) {
      if (value != null && value.trim().isNotEmpty) {
        statuses.add(value.trim());
      }
    }

    if (statuses.isEmpty) return '';

    const priority = [
      'paid',
      'refunded',
      'partially_refunded',
      'failed',
      'pending',
    ];

    for (final key in priority) {
      for (final status in statuses) {
        if (_normalizePaymentStatusKey(status) == key) {
          return status;
        }
      }
    }

    return statuses.first;
  }

  static const _paymentStatusLabels = {
    'paid': 'Paid',
    'pending': 'Pending',
    'failed': 'Failed',
    'refunded': 'Refunded',
    'partially_refunded': 'Partially Refunded',
  };

  /// Formats known payment statuses for display (e.g. pending → Pending).
  static String formatPaymentStatus(String status) {
    if (status.isEmpty) return status;
    final normalized = status.trim().toLowerCase().replaceAll(' ', '_');
    final label = _paymentStatusLabels[normalized];
    if (label != null) return label;
    return capitalizeFirst(status.trim().replaceAll('_', ' '));
  }
}
