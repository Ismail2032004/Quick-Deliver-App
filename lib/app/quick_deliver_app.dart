import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_providers.dart';
import '../core/router/app_router.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/presentation/controllers/app_settings_controller.dart';

class QuickDeliverApp extends ConsumerWidget {
  const QuickDeliverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(
      appUserIdProvider,
      (previous, next) {
        ref
            .read(notificationServiceProvider)
            .syncPushRegistration(previousUserId: previous, currentUserId: next);
      },
    );
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(appSettingsControllerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'QuickDeliver',
      theme: AppTheme.themeFor(settings, brightness: Brightness.light),
      darkTheme: AppTheme.themeFor(settings, brightness: Brightness.dark),
      themeMode: settings.themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(settings.textScaleFactor),
            disableAnimations: settings.reducedMotionEnabled,
            boldText: settings.highContrastEnabled,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}
