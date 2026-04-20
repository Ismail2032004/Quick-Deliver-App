import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/live_delivery_tracking_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../customer/presentation/controllers/customer_providers.dart';
import 'auth_controller.dart';

final authSessionCoordinatorProvider = Provider<AuthSessionCoordinator>((ref) {
  return AuthSessionCoordinator(ref);
});

class AuthSessionCoordinator {
  AuthSessionCoordinator(this._ref);

  final Ref _ref;

  Future<void> signOut() async {
    try {
      await _ref.read(liveDeliveryTrackingServiceProvider).stopTracking(
        markInactive: true,
      );
    } catch (_) {
      // Continue signing out even if tracking teardown has already been interrupted.
    }
    try {
      await _ref
          .read(notificationServiceProvider)
          .cancelLiveTrackingNotification();
    } catch (_) {
      // Local notification cleanup is best-effort during logout.
    }
    _ref.read(cartControllerProvider.notifier).clear();
    await _ref.read(authControllerProvider).signOut();
  }

  Future<void> confirmAndSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log out'),
          content: const Text(
            'Are you sure you want to log out of QuickDeliver on this device?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Stay signed in'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await signOut();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    context.go(AppRoutes.login);
  }
}
