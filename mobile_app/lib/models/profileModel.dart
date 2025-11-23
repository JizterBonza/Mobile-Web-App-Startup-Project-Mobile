import 'package:hive/hive.dart';

part 'profileModel.g.dart';

@HiveType(typeId: 2)
class ProfileModel {
  ProfileModel({
    required this.user_id,
    required this.username,
    required this.first_name,
    required this.last_name,
    this.middle_name,
    required this.email,
    this.phone,
    this.shipping_address,
    required this.user_type,
  });

  @HiveField(0)
  final String user_id;
  @HiveField(1)
  final String username;
  @HiveField(2)
  final String first_name;
  @HiveField(3)
  final String last_name;
  @HiveField(4)
  final String? middle_name;
  @HiveField(5)
  final String email;
  @HiveField(6)
  final String? phone;
  @HiveField(7)
  final String? shipping_address;
  @HiveField(8)
  final String user_type;
}
