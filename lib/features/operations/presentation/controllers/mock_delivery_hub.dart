import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_role.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/services/camera_service.dart';
import '../../../../core/utils/order_destination_source_codec.dart';
import '../../../customer/data/mock/mock_customer_seed_data.dart';
import '../../../customer/domain/models/business.dart';
import '../../../customer/domain/models/cart_item.dart';
import '../../../customer/domain/models/delivery_order.dart';
import '../../../customer/domain/models/order_item.dart';
import '../../../customer/domain/models/product.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/rider_location.dart';

final deliveryHubProvider =
    StateNotifierProvider<MockDeliveryHubController, MockDeliveryHubState>((
      ref,
    ) {
      return MockDeliveryHubController(MockDeliveryHubState.initial());
    });

class MockDeliveryHubState {
  const MockDeliveryHubState({
    required this.users,
    required this.businesses,
    required this.products,
    required this.orders,
    required this.riderLocations,
    required this.notifications,
  });

  factory MockDeliveryHubState.initial() {
    return MockDeliveryHubState(
      users: [...MockCustomerSeedData.users],
      businesses: [...MockCustomerSeedData.businesses],
      products: [...MockCustomerSeedData.products],
      orders: [...MockCustomerSeedData.initialOrders],
      riderLocations: [...MockCustomerSeedData.riderLocations],
      notifications: [...MockCustomerSeedData.notifications],
    );
  }

  final List<AppUser> users;
  final List<Business> businesses;
  final List<Product> products;
  final List<DeliveryOrder> orders;
  final List<RiderLocation> riderLocations;
  final List<AppNotification> notifications;

  MockDeliveryHubState copyWith({
    List<AppUser>? users,
    List<Business>? businesses,
    List<Product>? products,
    List<DeliveryOrder>? orders,
    List<RiderLocation>? riderLocations,
    List<AppNotification>? notifications,
  }) {
    return MockDeliveryHubState(
      users: users ?? this.users,
      businesses: businesses ?? this.businesses,
      products: products ?? this.products,
      orders: orders ?? this.orders,
      riderLocations: riderLocations ?? this.riderLocations,
      notifications: notifications ?? this.notifications,
    );
  }
}

class MockDeliveryHubController extends StateNotifier<MockDeliveryHubState> {
  MockDeliveryHubController(super.state);

  List<AppUser> usersByRole(AppRole role) {
    return state.users
        .where((user) => user.approvedRoles.contains(role))
        .toList(growable: false);
  }

  void updateBusiness(Business updatedBusiness) {
    state = state.copyWith(
      businesses: [
        for (final business in state.businesses)
          if (business.id == updatedBusiness.id) updatedBusiness else business,
      ],
    );
  }

  void addProduct(Product product) {
    state = state.copyWith(products: [product, ...state.products]);
  }

  void updateProduct(Product updatedProduct) {
    state = state.copyWith(
      products: [
        for (final product in state.products)
          if (product.id == updatedProduct.id) updatedProduct else product,
      ],
    );
  }

  void deleteProduct(String productId) {
    state = state.copyWith(
      products: state.products
          .where((product) => product.id != productId)
          .toList(growable: false),
    );
  }

  DeliveryOrder createOrder({
    required Business business,
    required AppUser customer,
    required String deliveryAddress,
    required List<CartItem> cartItems,
    OrderDestinationSource destinationSource = OrderDestinationSource.manual,
    double? destinationLatitude,
    double? destinationLongitude,
    String? note,
  }) {
    final sequence = DateTime.now().millisecondsSinceEpoch.toString().substring(
      7,
    );
    final order = DeliveryOrder(
      id: 'QD-$sequence',
      businessId: business.id,
      businessName: business.name,
      customerId: customer.id,
      customerName: customer.name,
      customerPhone: customer.phoneNumber ?? '+233200000000',
      deliveryAddress: deliveryAddress,
      status: OrderStatus.pending,
      destinationSource: destinationSource,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      businessPhone: business.phoneNumber,
      items: [
        for (final item in cartItems)
          OrderItem(
            productId: item.productId,
            productName: item.productName,
            unitPrice: item.unitPrice,
            quantity: item.quantity,
            imageUrl: item.imageUrl,
          ),
      ],
      createdAt: DateTime.now(),
      note: note,
    );

    state = state.copyWith(
      orders: [order, ...state.orders],
      notifications: [
        AppNotification(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
          userId: business.ownerId,
          title: 'New order received',
          body: '${customer.name} placed ${order.id} for ${business.name}.',
          type: AppNotificationType.orderStatus,
          orderId: order.id,
          createdAt: DateTime.now(),
        ),
        ...state.notifications,
      ],
    );
    return order;
  }

  void updateOrderStatus(String orderId, OrderStatus status) {
    final updatedOrders = <DeliveryOrder>[];
    DeliveryOrder? updatedOrder;
    for (final order in state.orders) {
      if (order.id == orderId) {
        updatedOrder = order.copyWith(status: status);
        updatedOrders.add(updatedOrder);
      } else {
        updatedOrders.add(order);
      }
    }

    if (updatedOrder == null) return;

    state = state.copyWith(
      orders: updatedOrders,
      notifications: [
        AppNotification(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
          userId: updatedOrder.customerId,
          title: 'Order update',
          body:
              '${updatedOrder.id} is now ${statusLabel(status).toLowerCase()}.',
          type: AppNotificationType.orderStatus,
          orderId: updatedOrder.id,
          createdAt: DateTime.now(),
        ),
        ...state.notifications,
      ],
    );
  }

  void assignRider(String orderId, AppUser rider) {
    final updated = state.orders
        .map((order) {
          if (order.id != orderId) return order;
          return order.copyWith(
            riderId: rider.id,
            riderName: rider.name,
            riderPhone: rider.phoneNumber,
            status: order.status == OrderStatus.pending
                ? OrderStatus.confirmed
                : order.status,
            trackingEnabled: true,
          );
        })
        .toList(growable: false);

    state = state.copyWith(
      orders: updated,
      notifications: [
        AppNotification(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
          userId: rider.id,
          title: 'Delivery assigned',
          body: 'You have been assigned a new QuickDeliver order.',
          type: AppNotificationType.riderAssigned,
          orderId: orderId,
          createdAt: DateTime.now(),
        ),
        ...state.notifications,
      ],
    );
  }

  void acceptDelivery(String orderId, AppUser rider) {
    assignRider(orderId, rider);
  }

  void attachPickupProof({
    required String orderId,
    required PickedProofImage image,
  }) {
    state = state.copyWith(
      orders: [
        for (final order in state.orders)
          if (order.id == orderId)
            order.copyWith(
              pickupProofImageUrl: image.path,
              status: OrderStatus.pickedUp,
              trackingEnabled: true,
            )
          else
            order,
      ],
    );
  }

  void attachDeliveryProof({
    required String orderId,
    required PickedProofImage image,
  }) {
    state = state.copyWith(
      orders: [
        for (final order in state.orders)
          if (order.id == orderId)
            order.copyWith(
              deliveryProofImageUrl: image.path,
              status: OrderStatus.deliveredPendingProofReview,
              trackingEnabled: true,
            )
          else
            order,
      ],
    );
  }

  void updateRiderLocation({
    required String riderId,
    required String riderName,
    required double latitude,
    required double longitude,
    String? orderId,
    bool isActive = true,
  }) {
    final current = state.riderLocations
        .where((location) => location.riderId != riderId)
        .toList();
    current.insert(
      0,
      RiderLocation(
        riderId: riderId,
        riderName: riderName,
        latitude: latitude,
        longitude: longitude,
        updatedAt: DateTime.now(),
        orderId: orderId,
        isActive: isActive,
      ),
    );
    state = state.copyWith(riderLocations: current);
  }

  void markNotificationRead(String notificationId) {
    state = state.copyWith(
      notifications: [
        for (final item in state.notifications)
          if (item.id == notificationId) item.copyWith(isRead: true) else item,
      ],
    );
  }

  static String statusLabel(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => 'Pending',
      OrderStatus.confirmed => 'Confirmed',
      OrderStatus.preparing => 'Preparing',
      OrderStatus.ready => 'Ready',
      OrderStatus.pickedUp => 'Picked up',
      OrderStatus.delivering => 'Delivering',
      OrderStatus.deliveredPendingProofReview => 'Proof review',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };
  }
}
