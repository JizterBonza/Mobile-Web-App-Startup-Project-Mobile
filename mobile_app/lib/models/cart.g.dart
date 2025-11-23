// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CartAdapter extends TypeAdapter<Cart> {
  @override
  final int typeId = 1;

  @override
  Cart read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Cart(
      user_id: fields[0] as String,
      item_id: fields[1] as String,
      item_name: fields[2] as String,
      price_at_time: fields[3] as double,
      price_updated: fields[4] as double,
      quantity: fields[5] as int,
      created_at: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Cart obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.user_id)
      ..writeByte(1)
      ..write(obj.item_id)
      ..writeByte(2)
      ..write(obj.item_name)
      ..writeByte(3)
      ..write(obj.price_at_time)
      ..writeByte(4)
      ..write(obj.price_updated)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.created_at);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
