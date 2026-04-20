import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/location_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../operations/domain/models/app_notification.dart';
import '../../../operations/presentation/controllers/delivery_hub_controller.dart';
import '../../data/mock/mock_customer_seed_data.dart';
import '../../data/repositories/mock_business_repository.dart';
import '../../domain/models/business.dart';
import '../../domain/models/cart_item.dart';
import '../../domain/models/delivery_order.dart';
import '../../domain/models/product.dart';

final customerLocationProvider =
    StateNotifierProvider<CustomerLocationController, CustomerLocationState>((
      ref,
    ) {
      return CustomerLocationController(
        ref.read(locationServiceProvider),
      );
    });

final nearbyBusinessesProvider = Provider<List<Business>>((ref) {
  final useDemoMode = ref.watch(demoModeProvider);
  final hubBusinesses = ref.watch(
    deliveryHubProvider.select((state) => state.businesses),
  );
  final location = ref.watch(customerLocationProvider);
  final fallbackBusinesses = useDemoMode
      ? MockBusinessRepository().getNearbyBusinesses(
          userLatitude: MockCustomerSeedData.customerLatitude,
          userLongitude: MockCustomerSeedData.customerLongitude,
        )
      : const <Business>[];
  final sorted = [...(hubBusinesses.isEmpty ? fallbackBusinesses : hubBusinesses)];
  sorted.sort((a, b) {
    final aDistance = distanceInKm(
      fromLatitude: location.latitude,
      fromLongitude: location.longitude,
      toLatitude: a.latitude,
      toLongitude: a.longitude,
    );
    final bDistance = distanceInKm(
      fromLatitude: location.latitude,
      fromLongitude: location.longitude,
      toLatitude: b.latitude,
      toLongitude: b.longitude,
    );
    return aDistance.compareTo(bDistance);
  });
  return sorted;
});

final businessDetailProvider = Provider.family<Business?, String>((
  ref,
  businessId,
) {
  final useDemoMode = ref.watch(demoModeProvider);
  final businesses = ref.watch(
    deliveryHubProvider.select((state) => state.businesses),
  );
  for (final business in businesses) {
    if (business.id == businessId) return business;
  }
  if (!useDemoMode) {
    return null;
  }
  return MockBusinessRepository().getBusinessById(businessId);
});

final businessProductsProvider = Provider.family<List<Product>, String>((
  ref,
  businessId,
) {
  final useDemoMode = ref.watch(demoModeProvider);
  final hubProducts = ref.watch(
    deliveryHubProvider.select((state) => state.products),
  );
  final products = hubProducts
      .where((product) => product.businessId == businessId)
      .toList(growable: false);
  if (products.isNotEmpty) {
    return products;
  }
  if (!useDemoMode) {
    return const [];
  }
  return MockBusinessRepository().getProductsForBusiness(businessId);
});

final customerCurrentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authControllerProvider).currentUser;
});

final customerOrdersProvider = Provider<List<DeliveryOrder>>((ref) {
  final user = ref.watch(customerCurrentUserProvider);
  final orders = ref.watch(deliveryHubProvider.select((state) => state.orders));
  if (user == null) return const [];
  return orders
      .where((order) => order.customerId == user.id)
      .toList(growable: false);
});

final customerNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final user = ref.watch(customerCurrentUserProvider);
  final notifications = ref.watch(
    deliveryHubProvider.select((state) => state.notifications),
  );
  if (user == null) return const <AppNotification>[];
  return notifications
      .where((item) => item.userId == user.id)
      .toList(growable: false);
});

final cartControllerProvider = StateNotifierProvider<CartController, CartState>(
  (ref) {
    return CartController();
  },
);

class CustomerLocationState {
  const CustomerLocationState({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.fullAddress,
    this.isLoading = false,
    this.isFallback = false,
    this.errorMessage,
  });

  factory CustomerLocationState.initial() {
    return const CustomerLocationState(
      latitude: MockCustomerSeedData.customerLatitude,
      longitude: MockCustomerSeedData.customerLongitude,
      label: 'Default delivery area',
      fullAddress: 'East Legon, Accra',
      isLoading: true,
      isFallback: true,
    );
  }

  final double latitude;
  final double longitude;
  final String label;
  final String fullAddress;
  final bool isLoading;
  final bool isFallback;
  final String? errorMessage;

  bool get hasLiveLocation => !isFallback;
  bool get canUseAsDeliveryDestination => fullAddress.trim().isNotEmpty;

  CustomerLocationState copyWith({
    double? latitude,
    double? longitude,
    String? label,
    String? fullAddress,
    bool? isLoading,
    bool? isFallback,
    String? errorMessage,
  }) {
    return CustomerLocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      fullAddress: fullAddress ?? this.fullAddress,
      isLoading: isLoading ?? this.isLoading,
      isFallback: isFallback ?? this.isFallback,
      errorMessage: errorMessage,
    );
  }
}

class CustomerLocationController extends StateNotifier<CustomerLocationState> {
  CustomerLocationController(this._locationService)
    : super(CustomerLocationState.initial());

  final LocationService _locationService;

  Future<void> refreshLocation() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final resolved = await _locationService.getCurrentCustomerLocation();
    state = CustomerLocationState(
      latitude: resolved.latitude,
      longitude: resolved.longitude,
      label: resolved.label,
      fullAddress: resolved.fullAddress,
      isLoading: false,
      isFallback: resolved.isFallback,
      errorMessage: resolved.errorMessage,
    );
  }
}

class CartState {
  const CartState({this.business, this.items = const []});

  final Business? business;
  final List<CartItem> items;

  bool get isEmpty => items.isEmpty;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);
  double get deliveryFee => isEmpty ? 0 : 8.0;
  double get total => subtotal + deliveryFee;
}

enum AddToCartResult { added, updated, requiresReplacement }

class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState());

  AddToCartResult addProduct({
    required Business business,
    required Product product,
    int quantity = 1,
    bool replaceExistingCart = false,
  }) {
    var result = AddToCartResult.added;
    var items = [...state.items];

    if (state.business != null && state.business!.id != business.id) {
      if (!replaceExistingCart) {
        return AddToCartResult.requiresReplacement;
      }
      items = [];
    }

    final index = items.indexWhere((item) => item.productId == product.id);
    if (index >= 0) {
      final existing = items[index];
      items[index] = existing.copyWith(quantity: existing.quantity + quantity);
      result = AddToCartResult.updated;
    } else {
      items.add(CartItem.fromProduct(product, quantity: quantity));
    }

    state = CartState(business: business, items: items);
    return result;
  }

  void increaseQuantity(String productId) {
    state = CartState(
      business: state.business,
      items: [
        for (final item in state.items)
          if (item.productId == productId)
            item.copyWith(quantity: item.quantity + 1)
          else
            item,
      ],
    );
  }

  void decreaseQuantity(String productId) {
    final updated = <CartItem>[];
    for (final item in state.items) {
      if (item.productId != productId) {
        updated.add(item);
      } else if (item.quantity > 1) {
        updated.add(item.copyWith(quantity: item.quantity - 1));
      }
    }
    state = CartState(
      business: updated.isEmpty ? null : state.business,
      items: updated,
    );
  }

  void removeItem(String productId) {
    final updated = state.items
        .where((item) => item.productId != productId)
        .toList(growable: false);
    state = CartState(
      business: updated.isEmpty ? null : state.business,
      items: updated,
    );
  }

  void clear() {
    state = const CartState();
  }
}

double distanceInKm({
  required double fromLatitude,
  required double fromLongitude,
  required double toLatitude,
  required double toLongitude,
}) {
  final dx = fromLatitude - toLatitude;
  final dy = fromLongitude - toLongitude;
  return (dx * dx + dy * dy) * 111;
}
