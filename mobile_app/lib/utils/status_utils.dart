import 'package:flutter/material.dart';
import '../constants/constants.dart';

/// Returns the appropriate color for a given order status.
/// Delegates to OrderStatusColors for a single source of truth
/// shared by customer, rider, and vendor surfaces.
Color getStatusColor(String status) => OrderStatusColors.getColor(status);

/// Normalizes API status descriptions for reliable comparisons.
String normalizeOrderStatus(String status) {
  return status
      .trim()
      .toLowerCase()
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// Whether an API status represents the rider's actionable pickup state.
bool isReadyForDeliveryStatus(String status) {
  return normalizeOrderStatus(status) == 'ready for delivery';
}

/// Returns the appropriate icon for a given order status.
/// Centralized for consistent status icons across all user types.
IconData getStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'delivered':
      return Icons.check_circle;
    case 'shipped':
      return Icons.local_shipping;
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
