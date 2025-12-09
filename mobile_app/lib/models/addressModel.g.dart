// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'addressModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AddressModelAdapter extends TypeAdapter<AddressModel> {
  @override
  final int typeId = 5;

  @override
  AddressModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AddressModel(
      id: fields[0] as int?,
      label: fields[1] as String,
      recipientName: fields[2] as String,
      phone: fields[3] as String,
      addressLine1: fields[4] as String,
      addressLine2: fields[5] as String?,
      postalCode: fields[6] as String?,
      latitude: fields[7] as double?,
      longitude: fields[8] as double?,
      mapAddress: fields[9] as String?,
      isDefault: fields[10] as bool,
      createdAt: fields[11] as DateTime?,
      updatedAt: fields[12] as DateTime?,
      street: fields[13] as String?,
      barangay: fields[14] as String?,
      city: fields[15] as String?,
      province: fields[16] as String?,
      country: fields[17] as String?,
      region: fields[18] as String?,
      addressType: fields[19] as String?,
      isActive: fields[20] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AddressModel obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.recipientName)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.addressLine1)
      ..writeByte(5)
      ..write(obj.addressLine2)
      ..writeByte(6)
      ..write(obj.postalCode)
      ..writeByte(7)
      ..write(obj.latitude)
      ..writeByte(8)
      ..write(obj.longitude)
      ..writeByte(9)
      ..write(obj.mapAddress)
      ..writeByte(10)
      ..write(obj.isDefault)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.updatedAt)
      ..writeByte(13)
      ..write(obj.street)
      ..writeByte(14)
      ..write(obj.barangay)
      ..writeByte(15)
      ..write(obj.city)
      ..writeByte(16)
      ..write(obj.province)
      ..writeByte(17)
      ..write(obj.country)
      ..writeByte(18)
      ..write(obj.region)
      ..writeByte(19)
      ..write(obj.addressType)
      ..writeByte(20)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
