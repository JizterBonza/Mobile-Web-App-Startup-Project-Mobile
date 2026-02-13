// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_photo_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeliveryPhotoModelAdapter extends TypeAdapter<DeliveryPhotoModel> {
  @override
  final int typeId = 6;

  @override
  DeliveryPhotoModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeliveryPhotoModel(
      orderId: fields[0] as String,
      imagePath: fields[1] as String,
      timestamp: fields[2] as DateTime,
      latitude: fields[3] as double,
      longitude: fields[4] as double,
      address: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DeliveryPhotoModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.orderId)
      ..writeByte(1)
      ..write(obj.imagePath)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.address);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryPhotoModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
