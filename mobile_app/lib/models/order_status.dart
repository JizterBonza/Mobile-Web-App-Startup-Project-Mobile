import 'package:hive/hive.dart';

part 'order_status.g.dart';

/// Model class representing an order status
@HiveType(typeId: 7)
class OrderStatus {
  OrderStatus({
    required this.status_id,
    required this.status_desc,
  });

  @HiveField(0)
  final int status_id;

  @HiveField(1)
  final String status_desc;
}
