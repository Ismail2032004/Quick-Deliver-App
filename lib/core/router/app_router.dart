import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/screens/account_hub_screen.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/customer/presentation/screens/business_detail_screen.dart';
import '../../features/customer/presentation/screens/business_list_screen.dart';
import '../../features/customer/presentation/screens/cart_screen.dart';
import '../../features/customer/presentation/screens/checkout_screen.dart';
import '../../features/customer/presentation/screens/customer_order_detail_screen.dart';
import '../../features/customer/presentation/screens/customer_tracking_screen.dart';
import '../../features/dashboard/presentation/screens/business_owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/customer_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/rider_dashboard_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/operations/domain/models/app_notification.dart';
import '../../features/operations/presentation/screens/notifications_screen.dart';
import '../../features/rider/presentation/screens/rider_delivery_detail_screen.dart';
import '../../features/rider/presentation/screens/rider_tracking_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../models/app_role.dart';
import '../services/password_recovery_service.dart';
import '../../features/customer/presentation/controllers/customer_providers.dart';
import '../../features/operations/presentation/controllers/delivery_hub_controller.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const roleSelection = '/role-selection';
  static const profile = '/profile';
  static const accountHub = '/account';
  static const settings = '/settings';
  static const customerNotifications = '/customer/notifications';
  static const ownerNotifications = '/owner/notifications';
  static const riderNotifications = '/rider/notifications';
  static const customerDashboard = '/dashboard/customer';
  static const riderDashboard = '/dashboard/rider';
  static const ownerDashboard = '/dashboard/owner';
  static const businessList = '/customer/businesses';
  static const cart = '/customer/cart';
  static const checkout = '/customer/checkout';
  static const customerOrderDetail = '/customer/orders';
  static const customerTracking = '/customer/tracking';
  static const riderDeliveryDetail = '/rider/delivery';
  static const riderTracking = '/rider/tracking';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authController = ref.read(authControllerProvider);
  final recoveryService = ref.read(passwordRecoveryServiceProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: Listenable.merge([authController, recoveryService]),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final authFlowRoutes = {
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
        AppRoutes.resetPassword,
      };
      final isInAuthFlow = authFlowRoutes.contains(location);

      if (!authController.isInitialized) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (!authController.hasSeenOnboarding) {
        return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }

      if (recoveryService.pendingResetNavigation &&
          location != AppRoutes.resetPassword) {
        return AppRoutes.resetPassword;
      }

      if (authController.currentUser == null) {
        final canAccessWhileLoggedOut =
            location == AppRoutes.login ||
            location == AppRoutes.register ||
            location == AppRoutes.forgotPassword ||
            (location == AppRoutes.resetPassword &&
                recoveryService.hasRecoveryContext);
        return canAccessWhileLoggedOut
            ? null
            : AppRoutes.login;
      }

      final role = authController.resolvedLandingRole;
      final dashboardRoute = switch (role) {
        AppRole.customer => AppRoutes.customerDashboard,
        AppRole.rider => AppRoutes.riderDashboard,
        AppRole.owner => AppRoutes.ownerDashboard,
      };

      if (authController.shouldShowWorkspaceChooser) {
        return location == AppRoutes.roleSelection
            ? null
            : AppRoutes.roleSelection;
      }

      if (location == AppRoutes.roleSelection) {
        return null;
      }

      if (location == AppRoutes.resetPassword) {
        return null;
      }

      if (isInAuthFlow) {
        return dashboardRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.roleSelection,
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountHub,
        builder: (context, state) => const AccountHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerDashboard,
        builder: (context, state) => const CustomerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerNotifications,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final notifications = ref.watch(customerNotificationsProvider);
            return NotificationsScreen(
              title: 'Customer notifications',
              subtitle: 'Live order and rider updates for your account.',
              notifications: notifications,
              onOpenOrder: (context, notification) async {
                if (notification.orderId == null) {
                  return;
                }
                context.push(
                  '${AppRoutes.customerOrderDetail}/${notification.orderId}',
                );
              },
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.businessList,
        builder: (context, state) => const BusinessListScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.businessList}/:businessId',
        builder: (context, state) => BusinessDetailScreen(
          businessId: state.pathParameters['businessId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.customerOrderDetail}/:orderId',
        builder: (context, state) => CustomerOrderDetailScreen(
          orderId: state.pathParameters['orderId']!,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.customerTracking}/:orderId',
        builder: (context, state) =>
            CustomerTrackingScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: AppRoutes.riderDashboard,
        builder: (context, state) => const RiderDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.riderNotifications,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final currentUser = ref.watch(authControllerProvider).currentUser;
            final notifications = ref.watch(
              deliveryHubProvider.select((state) => state.notifications),
            );
            final filtered = currentUser == null
                ? const <AppNotification>[]
                : notifications
                    .where((item) => item.userId == currentUser.id)
                    .toList(growable: false);
            return NotificationsScreen(
              title: 'Rider notifications',
              subtitle: 'Dispatch updates linked to your deliveries.',
              notifications: filtered,
              onOpenOrder: (context, notification) async {
                if (notification.orderId == null) {
                  return;
                }
                context.push(
                  '${AppRoutes.riderDeliveryDetail}/${notification.orderId}',
                );
              },
            );
          },
        ),
      ),
      GoRoute(
        path: '${AppRoutes.riderDeliveryDetail}/:orderId',
        builder: (context, state) => RiderDeliveryDetailScreen(
          orderId: state.pathParameters['orderId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.riderTracking,
        builder: (context, state) => const RiderTrackingScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.riderTracking}/:orderId',
        builder: (context, state) => RiderTrackingScreen(
          orderId: state.pathParameters['orderId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.ownerDashboard,
        builder: (context, state) => const BusinessOwnerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerNotifications,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final currentUser = ref.watch(authControllerProvider).currentUser;
            final notifications = ref.watch(
              deliveryHubProvider.select((state) => state.notifications),
            );
            final filtered = currentUser == null
                ? const <AppNotification>[]
                : notifications
                    .where((item) => item.userId == currentUser.id)
                    .toList(growable: false);
            return NotificationsScreen(
              title: 'Business notifications',
              subtitle: 'Recent alerts linked to your storefront.',
              notifications: filtered,
              onOpenOrder: (context, notification) async {
                context.go(AppRoutes.ownerDashboard);
              },
            );
          },
        ),
      ),
    ],
  );
});
