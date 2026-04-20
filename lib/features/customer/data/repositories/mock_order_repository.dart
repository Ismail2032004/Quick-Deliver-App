import '../../domain/models/delivery_order.dart';
import '../../domain/models/order_item.dart';
import '../mock/mock_customer_seed_data.dart';

class MockOrderRepository {
  List<DeliveryOrder> seedOrders() {
    return [...MockCustomerSeedData.initialOrders];
  }

  DeliveryOrder createOrder({
    required String businessId,
    required String businessName,
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required List<OrderItem> items,
    String? businessPhone,
    String? note,
  }) {
    final sequence = DateTime.now().millisecondsSinceEpoch.toString().substring(
      7,
    );
    return DeliveryOrder(
      id: 'QD-$sequence',
      businessId: businessId,
      businessName: businessName,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      status: OrderStatus.pending,
      businessPhone: businessPhone,
      items: items,
      createdAt: DateTime.now(),
      note: note,
    );
  }
}
