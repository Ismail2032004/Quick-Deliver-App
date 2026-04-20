import '../../features/customer/domain/models/business.dart';
import '../../features/customer/domain/models/delivery_order.dart';
import '../../features/customer/domain/models/order_item.dart';
import '../../features/customer/domain/models/product.dart';
import '../../features/operations/domain/models/app_notification.dart';
import '../../features/operations/domain/models/rider_location.dart';
import '../models/app_role.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/business_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/rider_location_repository.dart';
import '../repositories/user_repository.dart';
import '../utils/order_destination_source_codec.dart';

class FirebaseAuthRepository implements AuthRepository {
  @override
  String? get currentAuthUserId => null;

  @override
  AppUser? get currentUser => null;

  @override
  Future<void> initialize() async {}

  @override
  Stream<AppUser?> authStateChanges() => const Stream.empty();

  @override
  Future<AppUser?> register({
    required String name,
    required String email,
    required String password,
    required AppRole signupRole,
  }) {
    throw UnimplementedError(
      'Connect Firebase Authentication before using FirebaseAuthRepository.',
    );
  }

  @override
  Future<AppUser?> signIn({required String email, required String password}) {
    throw UnimplementedError(
      'Connect Firebase Authentication before using FirebaseAuthRepository.',
    );
  }

  @override
  Future<AppUser?> refreshCurrentUser() async => null;

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async => throw UnimplementedError();

  @override
  Future<void> resendVerificationEmail({
    required String email,
    String? redirectTo,
  }) async => throw UnimplementedError();

  @override
  Future<void> updatePassword({required String password}) async =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

class FirebaseUserRepository implements UserRepository {
  @override
  Future<AppUser?> getCurrentUserProfile() async => null;

  @override
  Future<AppUser?> getUserById(String userId) {
    throw UnimplementedError();
  }

  @override
  Future<AppUser> upsertUser(AppUser user) async {
    throw UnimplementedError();
  }

  @override
  Stream<AppUser?> watchUser(String userId) => const Stream.empty();

  @override
  Stream<List<AppUser>> watchUsers({AppRole? role}) => const Stream.empty();
}

class FirebaseBusinessRepository implements BusinessRepository {
  @override
  Future<List<Business>> getBusinesses() async => const [];

  @override
  Future<Business?> getBusinessById(String businessId) async => null;

  @override
  Future<Business?> getBusinessByOwner(String ownerId) async => null;

  @override
  Future<void> saveBusiness(Business business) async =>
      throw UnimplementedError();

  @override
  Stream<List<Business>> watchBusinesses({String? ownerId}) =>
      const Stream.empty();
}

class FirebaseProductRepository implements ProductRepository {
  @override
  Stream<List<Product>> watchProducts() => const Stream.empty();

  @override
  Future<void> deleteProduct(String productId) async =>
      throw UnimplementedError();

  @override
  Future<List<Product>> getProductsByBusiness(String businessId) async =>
      const [];

  @override
  Future<void> saveProduct(Product product) async => throw UnimplementedError();

  @override
  Stream<List<Product>> watchProductsByBusiness(String businessId) =>
      const Stream.empty();
}

class FirebaseOrderRepository implements OrderRepository {
  @override
  Future<DeliveryOrder> createOrder(DeliveryOrder order) async =>
      throw UnimplementedError();

  @override
  Future<void> saveOrderItems(String orderId, List<OrderItem> items) async =>
      throw UnimplementedError();

  @override
  Future<void> updateOrder(DeliveryOrder order) async =>
      throw UnimplementedError();

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async =>
      throw UnimplementedError();

  @override
  Future<void> assignRider(String orderId, AppUser rider) async =>
      throw UnimplementedError();

  @override
  Future<void> updateDeliveryDestination({
    required String orderId,
    required String deliveryAddress,
    required OrderDestinationSource destinationSource,
    double? destinationLatitude,
    double? destinationLongitude,
  }) async => throw UnimplementedError();

  @override
  Future<void> clearRiderAssignment(String orderId) async =>
      throw UnimplementedError();

  @override
  Future<void> upsertDeliveryRecord({
    required String orderId,
    required String riderId,
    required DeliveryProgressStatus status,
  }) async => throw UnimplementedError();

  @override
  Future<void> attachPickupProof({
    required String orderId,
    required String imageUrl,
  }) async => throw UnimplementedError();

  @override
  Future<void> attachDeliveryProof({
    required String orderId,
    required String imageUrl,
  }) async => throw UnimplementedError();

  @override
  Stream<List<DeliveryOrder>> watchOrders() => const Stream.empty();

  @override
  Stream<List<DeliveryOrder>> watchOrdersByUser(String userId) =>
      const Stream.empty();

  @override
  Stream<DeliveryOrder?> watchOrder(String orderId) => const Stream.empty();
}

class FirebaseRiderLocationRepository implements RiderLocationRepository {
  @override
  Future<void> updateRiderLocation(RiderLocation location) async =>
      throw UnimplementedError();

  @override
  Stream<List<RiderLocation>> watchActiveLocations({String? riderId}) =>
      const Stream.empty();

  @override
  Stream<RiderLocation?> watchLocationForOrder(String orderId) =>
      const Stream.empty();
}

class FirebaseNotificationRepository implements NotificationRepository {
  @override
  Future<void> sendNotification(AppNotification notification) async =>
      throw UnimplementedError();

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) =>
      const Stream.empty();

  @override
  Future<void> markNotificationRead(String notificationId) async =>
      throw UnimplementedError();
}
