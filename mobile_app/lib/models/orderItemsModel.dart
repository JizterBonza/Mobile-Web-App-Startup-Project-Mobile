import 'package:hive/hive.dart';

part 'orderItemsModel.g.dart';

@HiveType(typeId: 4)
class OrderItemsModel {
  OrderItemsModel({
    required this.order_items_id,
    required this.order_id,
    required this.item_id,
    required this.quantity,
    required this.price_at_purchase,
    required this.total_price,
    required this.created_at,
  });

  @HiveField(0)
  final String order_items_id;
  @HiveField(1)
  final String order_id;
  @HiveField(2)
  final String item_id;
  @HiveField(3)
  final int quantity;
  @HiveField(4)
  final double price_at_purchase;
  @HiveField(5)
  final double total_price;
  @HiveField(6)
  final String created_at;
}
