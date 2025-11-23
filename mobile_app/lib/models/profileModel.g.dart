// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profileModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProfileModelAdapter extends TypeAdapter<ProfileModel> {
  @override
  final int typeId = 2;

  @override
  ProfileModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProfileModel(
      user_id: fields[0] as String,
      username: fields[1] as String,
      first_name: fields[2] as String,
      last_name: fields[3] as String,
      middle_name: fields[4] as String?,
      email: fields[5] as String,
      phone: fields[6] as String?,
      shipping_address: fields[7] as String?,
      user_type: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ProfileModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.user_id)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.first_name)
      ..writeByte(3)
      ..write(obj.last_name)
      ..writeByte(4)
      ..write(obj.middle_name)
      ..writeByte(5)
      ..write(obj.email)
      ..writeByte(6)
      ..write(obj.phone)
      ..writeByte(7)
      ..write(obj.shipping_address)
      ..writeByte(8)
      ..write(obj.user_type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
