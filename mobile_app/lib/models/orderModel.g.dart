// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orderModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderModelAdapter extends TypeAdapter<OrderModel> {
  @override
  final int typeId = 3;

  @override
  OrderModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OrderModel(
      order_id: fields[0] as String,
      user_id: fields[1] as String,
      order_items_id: fields[2] as String,
      total_price: fields[3] as double,
      status: fields[4] as String,
      payment_method: fields[5] as String,
      payment_status: fields[6] as String,
      shipping_address: fields[7] as String,
      shipping_status: fields[8] as String,
      created_at: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, OrderModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.order_id)
      ..writeByte(1)
      ..write(obj.user_id)
      ..writeByte(2)
      ..write(obj.order_items_id)
      ..writeByte(3)
      ..write(obj.total_price)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.payment_method)
      ..writeByte(6)
      ..write(obj.payment_status)
      ..writeByte(7)
      ..write(obj.shipping_address)
      ..writeByte(8)
      ..write(obj.shipping_status)
      ..writeByte(9)
      ..write(obj.created_at);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
