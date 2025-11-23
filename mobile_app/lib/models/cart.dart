import 'package:hive/hive.dart';

part 'cart.g.dart';

@HiveType(typeId: 1)
class Cart {
  Cart({
    required this.user_id,
    required this.item_id,
    required this.item_name,
    required this.price_at_time,
    this.price_updated = 0.0,
    required this.quantity,
    required this.created_at,
  });
  @HiveField(0)
  final String user_id;
  @HiveField(1)
  final String item_id;
  @HiveField(2)
  final String item_name;
  @HiveField(3)
  final double price_at_time;
  @HiveField(4)
  final double price_updated;
  @HiveField(5)
  final int quantity;
  @HiveField(6)
  final String created_at;
}
