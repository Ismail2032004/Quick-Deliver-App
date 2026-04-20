import '../../features/customer/domain/models/delivery_order.dart';
import '../../features/customer/domain/models/order_item.dart';
import '../models/app_user.dart';
import '../utils/order_destination_source_codec.dart';

abstract class OrderRepository {
  Future<DeliveryOrder> createOrder(DeliveryOrder order);
  Future<void> saveOrderItems(String orderId, List<OrderItem> items);
  Future<void> updateOrder(DeliveryOrder order);
  Future<void> updateOrderStatus(String orderId, OrderStatus status);
  Future<void> assignRider(String orderId, AppUser rider);
  Future<void> updateDeliveryDestination({
    required String orderId,
    required String deliveryAddress,
    required OrderDestinationSource destinationSource,
    double? destinationLatitude,
    double? destinationLongitude,
  });
  Future<void> clearRiderAssignment(String orderId);
  Future<void> upsertDeliveryRecord({
    required String orderId,
    required String riderId,
    required DeliveryProgressStatus status,
  });
  Future<void> attachPickupProof({
    required String orderId,
    required String imageUrl,
  });
  Future<void> attachDeliveryProof({
    required String orderId,
    required String imageUrl,
  });
  Stream<List<DeliveryOrder>> watchOrders();
  Stream<List<DeliveryOrder>> watchOrdersByUser(String userId);
  Stream<DeliveryOrder?> watchOrder(String orderId);
}
