import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/customer/data/mock/mock_customer_seed_data.dart';
import '../../features/customer/domain/models/business.dart';
import '../../features/customer/domain/models/delivery_order.dart';
import '../../features/customer/domain/models/product.dart';
import '../../features/operations/domain/models/app_notification.dart';
import '../../features/operations/domain/models/rider_location.dart';
import '../config/app_config.dart';
import '../models/app_role.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/business_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/rider_location_repository.dart';
import '../repositories/unavailable_repositories.dart';
import '../repositories/user_repository.dart';
import '../supabase/providers/supabase_client_provider.dart';
import '../supabase/repositories/supabase_auth_repository.dart';
import '../supabase/repositories/supabase_business_repository.dart';
import '../supabase/repositories/supabase_notification_repository.dart';
import '../supabase/repositories/supabase_order_repository.dart';
import '../supabase/repositories/supabase_product_repository.dart';
import '../supabase/repositories/supabase_rider_location_repository.dart';
import '../supabase/repositories/supabase_user_repository.dart';
import '../supabase/services/supabase_storage_service.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';

final demoModeProvider = Provider<bool>((ref) => AppConfig.demoMode);

final appUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider).currentUser?.id;
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  if (!AppConfig.isSupabaseConfigured) {
    return UnavailableUserRepository();
  }
  return SupabaseUserRepository(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!AppConfig.isSupabaseConfigured) {
    return UnavailableAuthRepository();
  }
  return SupabaseAuthRepository(
    client: ref.watch(supabaseClientProvider),
    userRepository: ref.watch(userRepositoryProvider),
  );
});

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  if (!AppConfig.isSupabaseConfigured) {
    return UnavailableBusinessRepository();
  }
  return SupabaseBusinessRepository(ref.watch(supabaseClientProvider));
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  if (!AppConfig.isSupabaseConfigured) {
    return UnavailableProductRepository();
  }
  return SupabaseProductRepository(ref.watch(supabaseClientProvider));
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  if (!AppConfig.isSupabaseConfigured) {
    return UnavailableOrderRepository();
  }
  return SupabaseOrderRepository(ref.watch(supabaseClientProvider));
});

final riderLocationRepositoryProvider = Provider<RiderLocationRepository>((ref) {
  if (!AppConfig.isSupabaseConfigured) {
    return UnavailableRiderLocationRepository();
  }
  return SupabaseRiderLocationRepository(ref.watch(supabaseClientProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (!AppConfig.isSupabaseConfigured) {
    return UnavailableNotificationRepository();
  }
  return SupabaseNotificationRepository(ref.watch(supabaseClientProvider));
});

final storageServiceProvider = Provider<SupabaseStorageService>((ref) {
  if (!AppConfig.isSupabaseConfigured) {
    throw StateError(
      'Supabase Storage is unavailable until SUPABASE_URL and SUPABASE_ANON_KEY are configured.',
    );
  }
  return SupabaseStorageService(ref.watch(supabaseClientProvider));
});

final appUsersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  if (ref.watch(demoModeProvider)) {
    return Stream.value(MockCustomerSeedData.users);
  }
  return ref.watch(userRepositoryProvider).watchUsers();
});

final riderUsersProvider = Provider<List<AppUser>>((ref) {
  final users = ref.watch(appUsersStreamProvider).valueOrNull ?? const <AppUser>[];
  return users.where((user) => user.role == AppRole.rider).toList(growable: false);
});

final businessesStreamProvider = StreamProvider<List<Business>>((ref) {
  if (ref.watch(demoModeProvider)) {
    return Stream.value(MockCustomerSeedData.businesses);
  }
  return ref.watch(businessRepositoryProvider).watchBusinesses();
});

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  if (ref.watch(demoModeProvider)) {
    return Stream.value(MockCustomerSeedData.products);
  }
  return ref.watch(productRepositoryProvider).watchProducts();
});

final ordersStreamProvider = StreamProvider<List<DeliveryOrder>>((ref) {
  if (ref.watch(demoModeProvider)) {
    return Stream.value(MockCustomerSeedData.initialOrders);
  }
  return ref.watch(orderRepositoryProvider).watchOrders();
});

final riderLocationsStreamProvider = StreamProvider<List<RiderLocation>>((ref) {
  if (ref.watch(demoModeProvider)) {
    return Stream.value(MockCustomerSeedData.riderLocations);
  }
  return ref.watch(riderLocationRepositoryProvider).watchActiveLocations();
});

final notificationsForUserProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, userId) {
      if (ref.watch(demoModeProvider)) {
        return Stream.value(
          MockCustomerSeedData.notifications
              .where((item) => item.userId == userId)
              .toList(growable: false),
        );
      }
      return ref.watch(notificationRepositoryProvider).watchNotifications(userId);
    });
