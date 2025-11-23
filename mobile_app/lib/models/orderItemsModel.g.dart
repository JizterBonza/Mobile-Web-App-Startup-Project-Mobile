// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orderItemsModel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderItemsModelAdapter extends TypeAdapter<OrderItemsModel> {
  @override
  final int typeId = 4;

  @override
  OrderItemsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OrderItemsModel(
      order_items_id: fields[0] as String,
      order_id: fields[1] as String,
      item_id: fields[2] as String,
      quantity: fields[3] as int,
      price_at_purchase: fields[4] as double,
      total_price: fields[5] as double,
      created_at: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, OrderItemsModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.order_items_id)
      ..writeByte(1)
      ..write(obj.order_id)
      ..writeByte(2)
      ..write(obj.item_id)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.price_at_purchase)
      ..writeByte(5)
      ..write(obj.total_price)
      ..writeByte(6)
      ..write(obj.created_at);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderItemsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
