import '../../features/customer/domain/models/business.dart';
import '../../features/customer/domain/models/delivery_order.dart';
import '../../features/customer/domain/models/order_item.dart';
import '../../features/customer/domain/models/product.dart';
import '../../features/operations/domain/models/app_notification.dart';
import '../../features/operations/domain/models/rider_location.dart';
import '../models/app_role.dart';
import '../models/app_user.dart';
import '../utils/order_destination_source_codec.dart';
import 'auth_repository.dart';
import 'business_repository.dart';
import 'notification_repository.dart';
import 'order_repository.dart';
import 'product_repository.dart';
import 'rider_location_repository.dart';
import 'user_repository.dart';

const _setupMessage =
    'Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY before using the production backend.';

class UnavailableAuthRepository implements AuthRepository {
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
    throw StateError(_setupMessage);
  }

  @override
  Future<AppUser?> signIn({required String email, required String password}) {
    throw StateError(_setupMessage);
  }

  @override
  Future<AppUser?> refreshCurrentUser() async => null;

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> resendVerificationEmail({
    required String email,
    String? redirectTo,
  }) async {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> updatePassword({required String password}) async {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> signOut() async {}
}

class UnavailableUserRepository implements UserRepository {
  @override
  Future<AppUser?> getCurrentUserProfile() async => null;

  @override
  Future<AppUser?> getUserById(String userId) async => null;

  @override
  Future<AppUser> upsertUser(AppUser user) {
    throw StateError(_setupMessage);
  }

  @override
  Stream<AppUser?> watchUser(String userId) => const Stream.empty();

  @override
  Stream<List<AppUser>> watchUsers({AppRole? role}) => const Stream.empty();
}

class UnavailableBusinessRepository implements BusinessRepository {
  @override
  Future<List<Business>> getBusinesses() async => const [];

  @override
  Future<Business?> getBusinessById(String businessId) async => null;

  @override
  Future<Business?> getBusinessByOwner(String ownerId) async => null;

  @override
  Stream<List<Business>> watchBusinesses({String? ownerId}) =>
      const Stream.empty();

  @override
  Future<void> saveBusiness(Business business) {
    throw StateError(_setupMessage);
  }
}

class UnavailableProductRepository implements ProductRepository {
  @override
  Stream<List<Product>> watchProducts() => const Stream.empty();

  @override
  Future<List<Product>> getProductsByBusiness(String businessId) async =>
      const [];

  @override
  Stream<List<Product>> watchProductsByBusiness(String businessId) =>
      const Stream.empty();

  @override
  Future<void> saveProduct(Product product) {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> deleteProduct(String productId) {
    throw StateError(_setupMessage);
  }
}

class UnavailableOrderRepository implements OrderRepository {
  @override
  Future<DeliveryOrder> createOrder(DeliveryOrder order) {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> saveOrderItems(String orderId, List<OrderItem> items) {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> updateOrder(DeliveryOrder order) {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> assignRider(String orderId, AppUser rider) {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> updateDeliveryDestination({
    required String orderId,
    required String deliveryAddress,
    required OrderDestinationSource destinationSource,
    double? destinationLatitude,
    double? destinationLongitude,
  }) {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> clearRiderAssignment(String orderId) {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> upsertDeliveryRecord({
    required String orderId,
    required String riderId,
    required DeliveryProgressStatus status,
  }) {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> attachPickupProof({
    required String orderId,
    required String imageUrl,
  }) {
    throw StateError(_setupMessage);
  }

  @override
  Future<void> attachDeliveryProof({
    required String orderId,
    required String imageUrl,
  }) {
    throw StateError(_setupMessage);
  }

  @override
  Stream<List<DeliveryOrder>> watchOrders() => const Stream.empty();

  @override
  Stream<List<DeliveryOrder>> watchOrdersByUser(String userId) =>
      const Stream.empty();

  @override
  Stream<DeliveryOrder?> watchOrder(String orderId) => const Stream.empty();
}

class UnavailableRiderLocationRepository implements RiderLocationRepository {
  @override
  Future<void> updateRiderLocation(RiderLocation location) {
    throw StateError(_setupMessage);
  }

  @override
  Stream<List<RiderLocation>> watchActiveLocations({String? riderId}) =>
      const Stream.empty();

  @override
  Stream<RiderLocation?> watchLocationForOrder(String orderId) =>
      const Stream.empty();
}

class UnavailableNotificationRepository implements NotificationRepository {
  @override
  Future<void> sendNotification(AppNotification notification) {
    throw StateError(_setupMessage);
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) =>
      const Stream.empty();

  @override
  Future<void> markNotificationRead(String notificationId) {
    throw StateError(_setupMessage);
  }
}
