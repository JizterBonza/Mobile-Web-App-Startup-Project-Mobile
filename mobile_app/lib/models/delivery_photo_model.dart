import 'package:hive/hive.dart';

part 'delivery_photo_model.g.dart';

@HiveType(typeId: 6)
class DeliveryPhotoModel {
  DeliveryPhotoModel({
    required this.orderId,
    required this.imagePath,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.address,
    this.status = 'pending', // 'pending', 'uploaded', 'failed'
  });

  @HiveField(0)
  final String orderId;

  @HiveField(1)
  final String imagePath;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final double latitude;

  @HiveField(4)
  final double longitude;

  @HiveField(5)
  final String? address;

  @HiveField(6)
  String status; // Track upload status: 'pending', 'uploaded', 'failed'
}
