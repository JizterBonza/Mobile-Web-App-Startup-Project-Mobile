import 'package:hive/hive.dart';

part 'orderModel.g.dart';

@HiveType(typeId: 3)
class OrderModel {
  OrderModel({
    required this.order_id,
    required this.user_id,
    required this.order_items_id,
    required this.total_price,
    required this.status,
    required this.payment_method,
    required this.payment_status,
    required this.shipping_address,
    required this.shipping_status,
    required this.created_at,
  });

  @HiveField(0)
  final String order_id;
  @HiveField(1)
  final String user_id;
  @HiveField(2)
  final String order_items_id;
  @HiveField(3)
  final double total_price;
  @HiveField(4)
  final String status;
  @HiveField(5)
  final String payment_method;
  @HiveField(6)
  final String payment_status;
  @HiveField(7)
  final String shipping_address;
  @HiveField(8)
  final String shipping_status;
  @HiveField(9)
  final String created_at;
}
