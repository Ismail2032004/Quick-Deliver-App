import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/repositories/business_repository.dart';
import '../../../../core/repositories/notification_repository.dart';
import '../../../../core/repositories/order_repository.dart';
import '../../../../core/repositories/product_repository.dart';
import '../../../../core/repositories/rider_location_repository.dart';
import '../../../../core/repositories/user_repository.dart';
import '../../../../core/services/camera_service.dart';
import '../../../../core/services/push_delivery_service.dart';
import '../../../../core/supabase/services/supabase_storage_service.dart';
import '../../../../core/utils/order_workflow.dart';
import '../../../../core/utils/order_destination_source_codec.dart';
import '../../../../core/utils/order_status_codec.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../customer/data/mock/mock_customer_seed_data.dart';
import '../../../customer/domain/models/business.dart';
import '../../../customer/domain/models/cart_item.dart';
import '../../../customer/domain/models/delivery_order.dart';
import '../../../customer/domain/models/order_item.dart';
import '../../../customer/domain/models/product.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/rider_location.dart';

final deliveryHubProvider =
    StateNotifierProvider<DeliveryHubController, DeliveryHubState>((ref) {
      return DeliveryHubController(
        ref: ref,
        currentUserId: ref.watch(authControllerProvider).currentUser?.id,
        demoMode: ref.watch(demoModeProvider),
        userRepository: ref.watch(userRepositoryProvider),
        businessRepository: ref.watch(businessRepositoryProvider),
        productRepository: ref.watch(productRepositoryProvider),
        orderRepository: ref.watch(orderRepositoryProvider),
        riderLocationRepository: ref.watch(riderLocationRepositoryProvider),
        notificationRepository: ref.watch(notificationRepositoryProvider),
        pushDeliveryService: ref.watch(pushDeliveryServiceProvider),
        storageService: AppConfig.isSupabaseConfigured
            ? ref.watch(storageServiceProvider)
            : null,
      );
    });

class DeliveryHubState {
  const DeliveryHubState({
    required this.users,
    required this.businesses,
    required this.products,
    required this.orders,
    required this.riderLocations,
    required this.notifications,
  });

  factory DeliveryHubState.initial({bool demoMode = false}) {
    if (demoMode) {
      return DeliveryHubState(
        users: [...MockCustomerSeedData.users],
        businesses: [...MockCustomerSeedData.businesses],
        products: [...MockCustomerSeedData.products],
        orders: [...MockCustomerSeedData.initialOrders],
        riderLocations: [...MockCustomerSeedData.riderLocations],
        notifications: [...MockCustomerSeedData.notifications],
      );
    }
    return const DeliveryHubState(
      users: [],
      businesses: [],
      products: [],
      orders: [],
      riderLocations: [],
      notifications: [],
    );
  }

  final List<AppUser> users;
  final List<Business> businesses;
  final List<Product> products;
  final List<DeliveryOrder> orders;
  final List<RiderLocation> riderLocations;
  final List<AppNotification> notifications;

  DeliveryHubState copyWith({
    List<AppUser>? users,
    List<Business>? businesses,
    List<Product>? products,
    List<DeliveryOrder>? orders,
    List<RiderLocation>? riderLocations,
    List<AppNotification>? notifications,
  }) {
    return DeliveryHubState(
      users: users ?? this.users,
      businesses: businesses ?? this.businesses,
      products: products ?? this.products,
      orders: orders ?? this.orders,
      riderLocations: riderLocations ?? this.riderLocations,
      notifications: notifications ?? this.notifications,
    );
  }
}

class DeliveryHubController extends StateNotifier<DeliveryHubState> {
  DeliveryHubController({
    required Ref ref,
    required String? currentUserId,
    required bool demoMode,
    required UserRepository userRepository,
    required BusinessRepository businessRepository,
    required ProductRepository productRepository,
    required OrderRepository orderRepository,
    required RiderLocationRepository riderLocationRepository,
    required NotificationRepository notificationRepository,
    required PushDeliveryService pushDeliveryService,
    required SupabaseStorageService? storageService,
  }) : _currentUserId = currentUserId,
       _demoMode = demoMode,
       _userRepository = userRepository,
       _businessRepository = businessRepository,
       _productRepository = productRepository,
       _orderRepository = orderRepository,
       _riderLocationRepository = riderLocationRepository,
       _notificationRepository = notificationRepository,
       _pushDeliveryService = pushDeliveryService,
       _storageService = storageService,
       super(DeliveryHubState.initial(demoMode: demoMode)) {
    if (!_demoMode) {
      _bindStreams();
    }
  }

  final String? _currentUserId;
  final bool _demoMode;
  final UserRepository _userRepository;
  final BusinessRepository _businessRepository;
  final ProductRepository _productRepository;
  final OrderRepository _orderRepository;
  final RiderLocationRepository _riderLocationRepository;
  final NotificationRepository _notificationRepository;
  final PushDeliveryService _pushDeliveryService;
  final SupabaseStorageService? _storageService;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<AppUser> usersByRole(AppRole role) {
    return state.users
        .where((user) => user.approvedRoles.contains(role))
        .toList(growable: false);
  }

  Future<void> updateBusiness(Business updatedBusiness) async {
    if (_demoMode) {
      final exists = state.businesses.any(
        (business) => business.id == updatedBusiness.id,
      );
      state = state.copyWith(
        businesses: exists
            ? [
                for (final business in state.businesses)
                  if (business.id == updatedBusiness.id)
                    updatedBusiness
                  else
                    business,
              ]
            : [updatedBusiness, ...state.businesses],
      );
      return;
    }
    await _businessRepository.saveBusiness(
      await _saveBusinessImageIfNeeded(updatedBusiness),
    );
  }

  Future<void> addProduct(Product product) async {
    if (_demoMode) {
      state = state.copyWith(products: [product, ...state.products]);
      return;
    }
    final savedProduct = await _saveProductImageIfNeeded(product);
    await _productRepository.saveProduct(savedProduct);
  }

  Future<void> updateProduct(Product updatedProduct) async {
    if (_demoMode) {
      state = state.copyWith(
        products: [
          for (final product in state.products)
            if (product.id == updatedProduct.id) updatedProduct else product,
        ],
      );
      return;
    }
    final savedProduct = await _saveProductImageIfNeeded(updatedProduct);
    await _productRepository.saveProduct(savedProduct);
  }

  Future<void> deleteProduct(String productId) async {
    if (_demoMode) {
      state = state.copyWith(
        products: state.products
            .where((product) => product.id != productId)
            .toList(growable: false),
      );
      return;
    }
    await _productRepository.deleteProduct(productId);
  }

  Future<DeliveryOrder> createOrder({
    required Business business,
    required AppUser customer,
    required String deliveryAddress,
    required List<CartItem> cartItems,
    OrderDestinationSource destinationSource = OrderDestinationSource.manual,
    double? destinationLatitude,
    double? destinationLongitude,
    String? note,
  }) async {
    final customerPhone = customer.phoneNumber?.trim();
    if (customerPhone == null || customerPhone.isEmpty) {
      throw StateError(
        'Add a phone number to your profile before placing an order.',
      );
    }
    final sequence = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final now = DateTime.now();
    final order = DeliveryOrder(
      id: 'QD-$sequence',
      businessId: business.id,
      businessName: business.name,
      customerId: customer.id,
      customerName: customer.name,
      customerPhone: customerPhone,
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
      createdAt: now,
      note: note,
    );

    if (_demoMode) {
      state = state.copyWith(
        orders: [order, ...state.orders],
        notifications: [
          AppNotification(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch + 1}',
            userId: customer.id,
            title: 'Order placed',
            body: '${order.id} has been sent to ${business.name}.',
            type: AppNotificationType.orderStatus,
            orderId: order.id,
            createdAt: now,
          ),
          AppNotification(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
            userId: business.ownerId,
            title: 'New order received',
            body: '${customer.name} placed ${order.id} for ${business.name}.',
            type: AppNotificationType.orderStatus,
            orderId: order.id,
            createdAt: now,
          ),
          ...state.notifications,
        ],
      );
      return order;
    }

    final savedOrder = await _orderRepository.createOrder(order);
    state = state.copyWith(
      orders: _mergeOrder(savedOrder, state.orders),
    );
    await _dispatchNotification(
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        userId: business.ownerId,
        title: 'New order received',
        body: '${customer.name} placed ${savedOrder.id} for ${business.name}.',
        type: AppNotificationType.orderStatus,
        orderId: savedOrder.id,
        createdAt: now,
      ),
    );
    await _dispatchNotification(
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch + 1}',
        userId: customer.id,
        title: 'Order placed',
        body: '${savedOrder.id} has been sent to ${business.name}.',
        type: AppNotificationType.orderStatus,
        orderId: savedOrder.id,
        createdAt: now,
      ),
    );
    return savedOrder;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final order = _findOrder(orderId);
    if (order == null) {
      throw StateError('This order is no longer available.');
    }
    if (!isStatusTransitionAllowed(order.status, status)) {
      throw StateError(
        'Cannot move ${order.id} from ${order.status.label} to ${status.label}.',
      );
    }

    if (_demoMode) {
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
      if (updatedOrder == null) {
        return;
      }
      state = state.copyWith(
        orders: updatedOrders,
        notifications: [
          AppNotification(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
            userId: updatedOrder.customerId,
            title: 'Order update',
            body: '${updatedOrder.id} is now ${status.label.toLowerCase()}.',
            type: AppNotificationType.orderStatus,
            orderId: updatedOrder.id,
            createdAt: DateTime.now(),
          ),
          ...state.notifications,
        ],
      );
      return;
    }

    await _orderRepository.updateOrderStatus(orderId, status);
    state = state.copyWith(
      orders: [
        for (final item in state.orders)
          if (item.id == orderId)
            item.copyWith(
              status: status,
              deliveryStatus: item.riderId == null
                  ? item.deliveryStatus
                  : _deliveryProgressForOrderStatus(status),
            )
          else
            item,
      ],
    );
    final riderId = order.riderId;
    if (riderId != null) {
      await _orderRepository.upsertDeliveryRecord(
        orderId: orderId,
        riderId: riderId,
        status: _deliveryProgressForOrderStatus(status),
      );
    }
    await _dispatchNotification(
      _buildCustomerStatusNotification(order: order, status: status),
    );
    await _notifyBusinessOwner(
      order.businessId,
      title: 'Order status updated',
      body: '${order.id} moved to ${status.label.toLowerCase()}.',
      orderId: order.id,
    );
  }

  Future<void> assignRider(String orderId, AppUser rider) async {
    final currentOrder = _findOrder(orderId);
    if (currentOrder == null) {
      throw StateError('This delivery is no longer available.');
    }
    if (!canAssignRider(currentOrder)) {
      throw StateError('This order can no longer be assigned.');
    }

    if (_demoMode) {
      final updated = state.orders
          .map((order) {
            if (order.id != orderId) {
              return order;
            }
            return order.copyWith(
              riderId: rider.id,
              riderName: rider.name,
              riderPhone: rider.phoneNumber,
              status: order.status == OrderStatus.pending
                  ? OrderStatus.confirmed
                  : order.status,
              trackingEnabled:
                  order.status.index >= OrderStatus.pickedUp.index,
              deliveryStatus: order.status == OrderStatus.ready
                  ? DeliveryProgressStatus.assigned
                  : _deliveryProgressForOrderStatus(order.status),
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
      return;
    }

    await _orderRepository.assignRider(orderId, rider);
    state = state.copyWith(
      orders: [
        for (final item in state.orders)
          if (item.id == orderId)
            item.copyWith(
              riderId: rider.id,
              riderName: rider.name,
              riderPhone: rider.phoneNumber,
              status: currentOrder.status,
              trackingEnabled:
                  currentOrder.status.index >= OrderStatus.pickedUp.index,
              deliveryStatus: currentOrder.status == OrderStatus.ready
                  ? DeliveryProgressStatus.assigned
                  : _deliveryProgressForOrderStatus(currentOrder.status),
            )
          else
            item,
      ],
    );
    await _orderRepository.upsertDeliveryRecord(
      orderId: orderId,
      riderId: rider.id,
      status: currentOrder.status == OrderStatus.ready
          ? DeliveryProgressStatus.assigned
          : _deliveryProgressForOrderStatus(currentOrder.status),
    );
    await _dispatchNotification(
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        userId: rider.id,
        title: 'Delivery assigned',
        body: 'You have been assigned a new QuickDeliver order.',
        type: AppNotificationType.riderAssigned,
        orderId: orderId,
        createdAt: DateTime.now(),
      ),
    );
    await _dispatchNotification(
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch + 1}',
        userId: currentOrder.customerId,
        title: 'Rider assigned',
        body: '${rider.name} is now assigned to ${currentOrder.id}.',
        type: AppNotificationType.riderAssigned,
        orderId: orderId,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> acceptDelivery(String orderId, AppUser rider) async {
    final order = _findOrder(orderId);
    if (order == null) {
      throw StateError('This delivery is no longer available.');
    }
    if (!canRiderAccept(order)) {
      throw StateError(
        'This delivery is not waiting for your acceptance right now.',
      );
    }
    if (order.riderId != rider.id) {
      throw StateError('This delivery is assigned to a different rider.');
    }
    if (_demoMode) {
      state = state.copyWith(
        orders: [
          for (final item in state.orders)
            if (item.id == orderId)
              item.copyWith(deliveryStatus: DeliveryProgressStatus.accepted)
            else
              item,
        ],
      );
      return;
    }
    await _orderRepository.upsertDeliveryRecord(
      orderId: orderId,
      riderId: rider.id,
      status: DeliveryProgressStatus.accepted,
    );
    state = state.copyWith(
      orders: [
        for (final item in state.orders)
          if (item.id == orderId)
            item.copyWith(deliveryStatus: DeliveryProgressStatus.accepted)
          else
            item,
      ],
    );
    await _notifyBusinessOwner(
      order.businessId,
      title: 'Rider accepted delivery',
      body: '${rider.name} accepted ${order.id}.',
      orderId: order.id,
    );
  }

  Future<void> declineDelivery(String orderId, AppUser rider) async {
    final order = _findOrder(orderId);
    if (order == null) {
      throw StateError('This delivery is no longer available.');
    }
    if (!canRiderDecline(order)) {
      throw StateError('This delivery can\'t be declined right now.');
    }
    if (order.riderId != rider.id) {
      throw StateError('This delivery is assigned to a different rider.');
    }
    if (_demoMode) {
      state = state.copyWith(
        orders: [
          for (final item in state.orders)
            if (item.id == orderId)
              item.copyWith(
                riderId: null,
                riderName: null,
                riderPhone: null,
                trackingEnabled: false,
                deliveryStatus: null,
              )
            else
              item,
        ],
      );
      return;
    }
    await _orderRepository.clearRiderAssignment(orderId);
    state = state.copyWith(
      orders: [
        for (final item in state.orders)
          if (item.id == orderId)
            item.copyWith(
              riderId: null,
              riderName: null,
              riderPhone: null,
              trackingEnabled: false,
              deliveryStatus: null,
            )
          else
            item,
      ],
    );
    await _notifyBusinessOwner(
      order.businessId,
      title: 'Rider declined delivery',
      body: '${rider.name} declined ${order.id}. Reassign another rider to continue.',
      orderId: order.id,
    );
  }

  Future<void> updateDeliveryDestination({
    required String orderId,
    required String deliveryAddress,
    required OrderDestinationSource destinationSource,
    double? destinationLatitude,
    double? destinationLongitude,
  }) async {
    final order = _findOrder(orderId);
    if (order == null) {
      throw StateError('This order is no longer available.');
    }
    if (!canEditDeliveryDestination(order)) {
      throw StateError(
        'Delivery destination can only be changed before pickup starts.',
      );
    }
    if (_demoMode) {
      state = state.copyWith(
        orders: [
          for (final item in state.orders)
            if (item.id == orderId)
              item.copyWith(
                deliveryAddress: deliveryAddress,
                destinationSource: destinationSource,
                destinationLatitude: destinationLatitude,
                destinationLongitude: destinationLongitude,
              )
            else
              item,
        ],
      );
      return;
    }
    await _orderRepository.updateDeliveryDestination(
      orderId: orderId,
      deliveryAddress: deliveryAddress,
      destinationSource: destinationSource,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
    );
    state = state.copyWith(
      orders: [
        for (final item in state.orders)
          if (item.id == orderId)
            item.copyWith(
              deliveryAddress: deliveryAddress,
              destinationSource: destinationSource,
              destinationLatitude: destinationLatitude,
              destinationLongitude: destinationLongitude,
            )
          else
            item,
      ],
    );
    await _dispatchNotification(
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        userId: order.customerId,
        title: 'Delivery destination updated',
        body:
            'The drop-off details for ${order.id} were updated before rider pickup.',
        type: AppNotificationType.orderStatus,
        orderId: orderId,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> attachPickupProof({
    required String orderId,
    required PickedProofImage image,
  }) async {
    final order = _findOrder(orderId);
    if (order == null) {
      throw StateError('This order is no longer available.');
    }
    if (!canAttachPickupProof(order)) {
      throw StateError('Pickup proof is only allowed once the order is ready.');
    }
    if (_demoMode) {
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
      return;
    }
    final storageService = _storageService;
    if (storageService == null) {
      throw StateError('Supabase Storage is not configured.');
    }
    final uploadedImage = await storageService.uploadProofImage(
      orderId: orderId,
      label: 'pickup',
      image: image,
    );
    await _orderRepository.attachPickupProof(
      orderId: orderId,
      imageUrl: uploadedImage,
    );
    final riderId = order.riderId;
    if (riderId != null) {
      await _orderRepository.upsertDeliveryRecord(
        orderId: orderId,
        riderId: riderId,
        status: DeliveryProgressStatus.pickedUp,
      );
    }
    state = state.copyWith(
      orders: [
        for (final item in state.orders)
          if (item.id == orderId)
            item.copyWith(
              pickupProofImageUrl: uploadedImage,
              status: OrderStatus.pickedUp,
              trackingEnabled: true,
              deliveryStatus: DeliveryProgressStatus.pickedUp,
            )
          else
            item,
      ],
    );
    await _dispatchNotification(
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        userId: order.customerId,
        title: 'Order picked up',
        body: '${order.id} has been picked up and tracking is now live.',
        type: AppNotificationType.proofUploaded,
        orderId: orderId,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> attachDeliveryProof({
    required String orderId,
    required PickedProofImage image,
  }) async {
    final order = _findOrder(orderId);
    if (order == null) {
      throw StateError('This order is no longer available.');
    }
    if (!canAttachDeliveryProof(order)) {
      throw StateError(
        'Delivery proof can only be uploaded after pickup is complete.',
      );
    }
    if (_demoMode) {
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
      return;
    }
    final storageService = _storageService;
    if (storageService == null) {
      throw StateError('Supabase Storage is not configured.');
    }
    final uploadedImage = await storageService.uploadProofImage(
      orderId: orderId,
      label: 'delivery',
      image: image,
    );
    await _orderRepository.attachDeliveryProof(
      orderId: orderId,
      imageUrl: uploadedImage,
    );
    final riderId = order.riderId;
    if (riderId != null) {
      await _orderRepository.upsertDeliveryRecord(
        orderId: orderId,
        riderId: riderId,
        status: DeliveryProgressStatus.proofReview,
      );
    }
    state = state.copyWith(
      orders: [
        for (final item in state.orders)
          if (item.id == orderId)
            item.copyWith(
              deliveryProofImageUrl: uploadedImage,
              status: OrderStatus.deliveredPendingProofReview,
              trackingEnabled: true,
              deliveryStatus: DeliveryProgressStatus.proofReview,
            )
          else
            item,
      ],
    );
    await _dispatchNotification(
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        userId: order.customerId,
        title: 'Delivery completed',
        body:
            '${order.id} has proof attached and is waiting for business confirmation.',
        type: AppNotificationType.proofUploaded,
        orderId: orderId,
        createdAt: DateTime.now(),
      ),
    );
    await _notifyBusinessOwner(
      order.businessId,
      title: 'Delivery proof ready',
      body: '${order.id} is waiting for delivery proof review.',
      orderId: order.id,
    );
  }

  Future<void> updateRiderLocation({
    required String riderId,
    required String riderName,
    required double latitude,
    required double longitude,
    String? orderId,
    bool isActive = true,
  }) async {
    final order = orderId == null ? null : _findOrder(orderId);
    if (orderId != null && order == null) {
      throw StateError('This delivery is no longer available for tracking.');
    }
    if (orderId != null && order != null && !canPublishRiderLocation(order)) {
      throw StateError(
        'Live rider location can only be shared for active assigned deliveries.',
      );
    }
    final location = RiderLocation(
      riderId: riderId,
      riderName: riderName,
      latitude: latitude,
      longitude: longitude,
      updatedAt: DateTime.now(),
      orderId: orderId,
      isActive: isActive,
    );
    if (_demoMode) {
      final current = state.riderLocations
          .where((item) => item.riderId != riderId)
          .toList(growable: false);
      state = state.copyWith(riderLocations: [location, ...current]);
      return;
    }
    await _riderLocationRepository.updateRiderLocation(location);
  }

  Future<void> markNotificationRead(String notificationId) async {
    if (_demoMode) {
      state = state.copyWith(
        notifications: [
          for (final item in state.notifications)
            if (item.id == notificationId) item.copyWith(isRead: true) else item,
        ],
      );
      return;
    }
    await _notificationRepository.markNotificationRead(notificationId);
  }

  static String statusLabel(OrderStatus status) => status.label;

  Future<Product> _saveProductImageIfNeeded(Product product) async {
    if (product.imageUrl.startsWith('http')) {
      return product;
    }
    final storageService = _storageService;
    if (storageService == null) {
      return product;
    }
    final uploadedImage = await storageService.uploadProductImage(
      businessId: product.businessId,
      productId: product.id,
      imagePath: product.imageUrl,
    );
    return product.copyWith(imageUrl: uploadedImage);
  }

  Future<Business> _saveBusinessImageIfNeeded(Business business) async {
    if (business.imageUrl.startsWith('http')) {
      return business;
    }
    final storageService = _storageService;
    if (storageService == null || business.imageUrl.trim().isEmpty) {
      return business;
    }
    final uploadedImage = await storageService.uploadBusinessImage(
      businessId: business.id,
      imagePath: business.imageUrl,
    );
    return business.copyWith(imageUrl: uploadedImage);
  }

  DeliveryOrder? _findOrder(String orderId) {
    for (final order in state.orders) {
      if (order.id == orderId) {
        return order;
      }
    }
    return null;
  }

  List<DeliveryOrder> _mergeOrder(
    DeliveryOrder order,
    List<DeliveryOrder> existing,
  ) {
    final updated = [
      order,
      for (final item in existing)
        if (item.id != order.id) item,
    ];
    updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return updated;
  }

  Future<void> _notifyBusinessOwner(
    String businessId, {
    required String title,
    required String body,
    required String orderId,
  }) async {
    Business? business;
    for (final item in state.businesses) {
      if (item.id == businessId) {
        business = item;
        break;
      }
    }
    if (business == null) {
      return;
    }
    await _dispatchNotification(
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch + 2}',
        userId: business.ownerId,
        title: title,
        body: body,
        type: AppNotificationType.orderStatus,
        orderId: orderId,
        createdAt: DateTime.now(),
      ),
    );
  }

  AppNotification _buildCustomerStatusNotification({
    required DeliveryOrder order,
    required OrderStatus status,
  }) {
    final (title, body) = switch (status) {
      OrderStatus.confirmed => (
        'Order confirmed',
        '${order.id} was confirmed and is moving into preparation.',
      ),
      OrderStatus.preparing => (
        'Order in preparation',
        '${order.id} is being prepared right now.',
      ),
      OrderStatus.ready => (
        'Order ready',
        '${order.id} is ready for rider pickup.',
      ),
      OrderStatus.pickedUp => (
        'Order picked up',
        '${order.id} has been picked up and live tracking is now available.',
      ),
      OrderStatus.delivering => (
        'Rider is on the way',
        '${order.id} is out for delivery.',
      ),
      OrderStatus.deliveredPendingProofReview => (
        'Proof submitted',
        '${order.id} is waiting for final delivery confirmation.',
      ),
      OrderStatus.delivered => (
        'Order delivered',
        '${order.id} has been delivered.',
      ),
      OrderStatus.cancelled => (
        'Order cancelled',
        '${order.id} was cancelled.',
      ),
      OrderStatus.pending => (
        'Order update',
        '${order.id} is now ${status.label.toLowerCase()}.',
      ),
    };
    return AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      userId: order.customerId,
      title: title,
      body: body,
      type: AppNotificationType.orderStatus,
      orderId: order.id,
      createdAt: DateTime.now(),
    );
  }

  DeliveryProgressStatus _deliveryProgressForOrderStatus(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => DeliveryProgressStatus.assigned,
      OrderStatus.confirmed => DeliveryProgressStatus.accepted,
      OrderStatus.preparing => DeliveryProgressStatus.accepted,
      OrderStatus.ready => DeliveryProgressStatus.assigned,
      OrderStatus.pickedUp => DeliveryProgressStatus.pickedUp,
      OrderStatus.delivering => DeliveryProgressStatus.delivering,
      OrderStatus.deliveredPendingProofReview =>
        DeliveryProgressStatus.proofReview,
      OrderStatus.delivered => DeliveryProgressStatus.delivered,
      OrderStatus.cancelled => DeliveryProgressStatus.cancelled,
    };
  }

  Future<void> _dispatchNotification(AppNotification notification) async {
    await _notificationRepository.sendNotification(notification);
    await _pushDeliveryService.sendPushNotification(notification);
  }

  void _bindStreams() {
    _subscriptions.add(
      _userRepository.watchUsers().listen((users) {
        state = state.copyWith(users: users);
      }),
    );
    _subscriptions.add(
      _businessRepository.watchBusinesses().listen((businesses) {
        state = state.copyWith(businesses: businesses);
      }),
    );
    _subscriptions.add(
      _productRepository.watchProducts().listen((products) {
        state = state.copyWith(products: products);
      }),
    );
    _subscriptions.add(
      _orderRepository.watchOrders().listen((orders) {
        state = state.copyWith(orders: orders);
      }),
    );
    _subscriptions.add(
      _riderLocationRepository.watchActiveLocations().listen((locations) {
        state = state.copyWith(riderLocations: locations);
      }),
    );
    if (_currentUserId != null) {
      _subscriptions.add(
        _notificationRepository.watchNotifications(_currentUserId).listen(
          (notifications) {
            state = state.copyWith(notifications: notifications);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
