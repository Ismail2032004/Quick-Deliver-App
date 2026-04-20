import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/customer/domain/models/delivery_order.dart';
import '../../../features/customer/domain/models/order_item.dart';
import '../../models/app_user.dart';
import '../../repositories/order_repository.dart';
import '../../utils/order_destination_source_codec.dart';
import '../../utils/order_workflow.dart';
import '../../utils/order_status_codec.dart';
import '../mappers/supabase_mappers.dart';
import '../supabase_tables.dart';

class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DeliveryOrder> createOrder(DeliveryOrder order) async {
    final response = await _client
        .from(SupabaseTables.orders)
        .insert({
          ...SupabaseMappers.orderToMap(order),
          'created_at': order.createdAt.toIso8601String(),
          'updated_at': order.createdAt.toIso8601String(),
        })
        .select()
        .single();
    await saveOrderItems(order.id, order.items);
    return SupabaseMappers.orderFromMap(response, items: order.items);
  }

  @override
  Future<void> saveOrderItems(String orderId, List<OrderItem> items) async {
    await _client.from(SupabaseTables.orderItems).delete().eq('order_id', orderId);
    if (items.isEmpty) {
      return;
    }
    await _client.from(SupabaseTables.orderItems).insert(
      items.map((item) => SupabaseMappers.orderItemToMap(item, orderId)).toList(),
    );
  }

  @override
  Future<void> updateOrder(DeliveryOrder order) async {
    await _client
        .from(SupabaseTables.orders)
        .update({
          ...SupabaseMappers.orderToMap(order),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', order.id);
    await saveOrderItems(order.id, order.items);
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final currentOrder = await _getOrderById(orderId);
    if (currentOrder == null) {
      throw StateError('Order $orderId was not found.');
    }
    if (!isStatusTransitionAllowed(currentOrder.status, status)) {
      throw StateError(
        'Cannot move ${currentOrder.id} from ${currentOrder.status.label} to ${status.label}.',
      );
    }
    await _client
        .from(SupabaseTables.orders)
        .update({
          'status': status.storageValue,
          'tracking_enabled': status.index >= OrderStatus.pickedUp.index,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  @override
  Future<void> assignRider(String orderId, AppUser rider) async {
    final currentOrder = await _getOrderById(orderId);
    if (currentOrder == null) {
      throw StateError('Order $orderId was not found.');
    }
    if (!canAssignRider(currentOrder)) {
      throw StateError('This order is not eligible for rider assignment.');
    }
    await _client
        .from(SupabaseTables.orders)
        .update({
          'rider_id': rider.id,
          'rider_name': rider.name,
          'rider_phone': rider.phoneNumber,
          'status': currentOrder.status == OrderStatus.pending
              ? OrderStatus.confirmed.storageValue
              : currentOrder.status.storageValue,
          'tracking_enabled':
              currentOrder.status.index >= OrderStatus.pickedUp.index,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  @override
  Future<void> clearRiderAssignment(String orderId) async {
    await _client
        .from(SupabaseTables.orders)
        .update({
          'rider_id': null,
          'rider_name': null,
          'rider_phone': null,
          'tracking_enabled': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
    await _client.from(SupabaseTables.deliveries).delete().eq('order_id', orderId);
  }

  @override
  Future<void> updateDeliveryDestination({
    required String orderId,
    required String deliveryAddress,
    required OrderDestinationSource destinationSource,
    double? destinationLatitude,
    double? destinationLongitude,
  }) async {
    final currentOrder = await _getOrderById(orderId);
    if (currentOrder == null) {
      throw StateError('Order $orderId was not found.');
    }
    if (!canEditDeliveryDestination(currentOrder)) {
      throw StateError(
        'Delivery destination can only be updated before the rider picks up the order.',
      );
    }
    await _client
        .from(SupabaseTables.orders)
        .update({
          'delivery_address': deliveryAddress,
          'destination_source': destinationSource.storageValue,
          'destination_latitude': destinationLatitude,
          'destination_longitude': destinationLongitude,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  @override
  Future<void> upsertDeliveryRecord({
    required String orderId,
    required String riderId,
    required DeliveryProgressStatus status,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _client.from(SupabaseTables.deliveries).upsert({
      'order_id': orderId,
      'rider_id': riderId,
      'status': status.storageValue,
      'assigned_at': now,
      'picked_up_at': status.index >= DeliveryProgressStatus.pickedUp.index
          ? now
          : null,
      'delivered_at': status == DeliveryProgressStatus.delivered ? now : null,
    });
  }

  @override
  Future<void> attachPickupProof({
    required String orderId,
    required String imageUrl,
  }) async {
    final currentOrder = await _getOrderById(orderId);
    if (currentOrder == null || !canAttachPickupProof(currentOrder)) {
      throw StateError('Pickup proof is only allowed for ready deliveries.');
    }
    await _client
        .from(SupabaseTables.orders)
        .update({
          'pickup_proof_image_url': imageUrl,
          'status': OrderStatus.pickedUp.storageValue,
          'tracking_enabled': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  @override
  Future<void> attachDeliveryProof({
    required String orderId,
    required String imageUrl,
  }) async {
    final currentOrder = await _getOrderById(orderId);
    if (currentOrder == null || !canAttachDeliveryProof(currentOrder)) {
      throw StateError(
        'Delivery proof is only allowed after pickup has been completed.',
      );
    }
    await _client
        .from(SupabaseTables.orders)
        .update({
          'delivery_proof_image_url': imageUrl,
          'status': OrderStatus.deliveredPendingProofReview.storageValue,
          'tracking_enabled': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);
  }

  @override
  Stream<List<DeliveryOrder>> watchOrders() {
    return _client
        .from(SupabaseTables.orders)
        .stream(primaryKey: ['id'])
        .order('created_at')
        .asyncMap(_hydrateOrders);
  }

  @override
  Stream<List<DeliveryOrder>> watchOrdersByUser(String userId) {
    return watchOrders().map(
      (orders) => orders
          .where(
            (order) => order.customerId == userId || order.riderId == userId,
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<DeliveryOrder?> watchOrder(String orderId) {
    return watchOrders().map((orders) {
      for (final order in orders) {
        if (order.id == orderId) {
          return order;
        }
      }
      return null;
    });
  }

  Future<List<DeliveryOrder>> _hydrateOrders(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) {
      return const [];
    }
    final orderIds = rows.map((row) => row['id'] as String).toList(growable: false);
    final itemResponse = await _client
        .from(SupabaseTables.orderItems)
        .select()
        .inFilter('order_id', orderIds);
    final deliveryResponse = await _client
        .from(SupabaseTables.deliveries)
        .select('order_id,status')
        .inFilter('order_id', orderIds);
    final groupedItems = <String, List<OrderItem>>{};
    final deliveryStatuses = <String, DeliveryProgressStatus?>{};
    for (final raw in itemResponse) {
      final orderId = raw['order_id'] as String;
      groupedItems.putIfAbsent(orderId, () => <OrderItem>[]);
      groupedItems[orderId]!.add(SupabaseMappers.orderItemFromMap(raw));
    }
    for (final raw in deliveryResponse) {
      final delivery = raw as Map<String, dynamic>;
      deliveryStatuses[delivery['order_id'] as String] =
          deliveryProgressStatusFromStorage(delivery['status'] as String?);
    }
    return rows
        .map(
          (row) => SupabaseMappers.orderFromMap(
            row,
            items: groupedItems[row['id']] ?? const [],
            deliveryStatus: deliveryStatuses[row['id']],
          ),
        )
        .toList(growable: false);
  }

  Future<DeliveryOrder?> _getOrderById(String orderId) async {
    final response = await _client
        .from(SupabaseTables.orders)
        .select()
        .eq('id', orderId)
        .maybeSingle();
    if (response == null) {
      return null;
    }
    final items = await _client
        .from(SupabaseTables.orderItems)
        .select()
        .eq('order_id', orderId);
    final delivery = await _client
        .from(SupabaseTables.deliveries)
        .select('status')
        .eq('order_id', orderId)
        .maybeSingle();
    return SupabaseMappers.orderFromMap(
      response,
      items: items
          .map<OrderItem>(SupabaseMappers.orderItemFromMap)
          .toList(growable: false),
      deliveryStatus: deliveryProgressStatusFromStorage(
        delivery?['status'] as String?,
      ),
    );
  }
}
