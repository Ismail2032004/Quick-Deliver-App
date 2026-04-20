import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../customer/domain/models/delivery_order.dart';
import '../../../customer/presentation/controllers/customer_providers.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../../../../shared/widgets/account_avatar_button.dart';
import '../../../account/presentation/controllers/account_preferences_controller.dart';
import '../controllers/dashboard_tab_controller.dart';
import '../widgets/dashboard_scaffold.dart';
import '../../../../features/settings/presentation/controllers/app_settings_controller.dart';

class CustomerDashboardScreen extends StatelessWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Customer workspace',
      subtitle:
          'Discover nearby businesses, place orders, and stay on top of every delivery update.',
      providerKey: 'customer-dashboard',
      headerAction: const AccountAvatarButton(
        fallbackIcon: Icons.person_outline_rounded,
        fallbackColor: Color(0xFF0F766E),
      ),
      tabs: const [
        DashboardTabItem(
          label: 'Home',
          icon: Icons.home_rounded,
          content: CustomerHomeTab(),
        ),
        DashboardTabItem(
          label: 'Orders',
          icon: Icons.local_shipping_outlined,
          content: CustomerOrdersTab(),
        ),
        DashboardTabItem(
          label: 'Profile',
          icon: Icons.person_outline_rounded,
          content: CustomerAccountTab(),
        ),
      ],
    );
  }
}

class CustomerHomeTab extends ConsumerWidget {
  const CustomerHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(nearbyBusinessesProvider);
    final location = ref.watch(customerLocationProvider);
    final cart = ref.watch(cartControllerProvider);
    final notifications = ref.watch(customerNotificationsProvider);
    final unreadNotifications = notifications
        .where((item) => !item.isRead)
        .length;

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF0F766E), Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to order from nearby stores',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                location.hasLiveLocation
                    ? '${location.label}. Nearby businesses are ranked from your live device location.'
                    : '${location.fullAddress}. Nearby businesses are using a fallback delivery area until you refresh location access.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final useVerticalLayout = constraints.maxWidth < 360;

                  if (useVerticalLayout) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PrimaryButton(
                          label: 'Browse businesses',
                          onPressed: () => context.push(AppRoutes.businessList),
                          icon: Icons.storefront_rounded,
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: cart.isEmpty
                              ? 'Open cart'
                              : 'Open cart (${cart.totalQuantity})',
                          variant: ButtonVariant.tonal,
                          onPressed: () => context.push(AppRoutes.cart),
                          icon: Icons.shopping_cart_outlined,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Browse businesses',
                          onPressed: () => context.push(AppRoutes.businessList),
                          icon: Icons.storefront_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: cart.isEmpty
                              ? 'Open cart'
                              : 'Open cart (${cart.totalQuantity})',
                          variant: ButtonVariant.tonal,
                          onPressed: () => context.push(AppRoutes.cart),
                          icon: Icons.shopping_cart_outlined,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.12,
          children: [
            MetricItemCard(
              label: 'Nearby stores',
              value: '${businesses.length}',
              icon: Icons.store_mall_directory_rounded,
              color: const Color(0xFF0F766E),
              onTap: () => context.push(AppRoutes.businessList),
            ),
            MetricItemCard(
              label: 'Items in cart',
              value: '${cart.totalQuantity}',
              icon: Icons.shopping_cart_checkout_rounded,
              color: const Color(0xFFF97316),
              onTap: () => context.push(AppRoutes.cart),
            ),
            MetricItemCard(
              label: 'Alerts',
              value: '$unreadNotifications',
              icon: Icons.notifications_active_outlined,
              color: Color(0xFF2563EB),
              onTap: () => context.push(AppRoutes.customerNotifications),
            ),
            MetricItemCard(
              label: 'Order flow',
              value: 'Ready',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF0F766E),
              onTap: () {
                ref
                    .read(dashboardTabProvider('customer-dashboard').notifier)
                    .state = 1;
              },
            ),
            MetricItemCard(
              label: 'Tracking',
              value: 'GPS-like',
              icon: Icons.near_me_rounded,
              color: Color(0xFF7C3AED),
              onTap: () {
                DeliveryOrder? activeOrder;
                for (final order in ref.read(customerOrdersProvider)) {
                  if (order.trackingEnabled) {
                    activeOrder = order;
                    break;
                  }
                }

                if (activeOrder == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Live tracking opens as soon as you have an active delivery.',
                      ),
                    ),
                  );
                  return;
                }

                context.push(
                  '${AppRoutes.customerTracking}/${activeOrder.id}',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionHeader(
          title: 'Recommended for you',
          subtitle: 'Preview the first businesses in the local discovery feed.',
        ),
        const SizedBox(height: 14),
        ...businesses
            .take(2)
            .map(
              (business) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE6FFFB),
                      child: Text(
                        business.name.substring(0, 1),
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(business.name),
                    subtitle: Text(
                      '${distanceInKm(fromLatitude: location.latitude, fromLongitude: location.longitude, toLatitude: business.latitude, toLongitude: business.longitude).toStringAsFixed(1)} km away - ${business.category}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(
                      '${AppRoutes.businessList}/${business.id}',
                    ),
                  ),
                ),
              ),
            ),
        if (notifications.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionHeader(
            title: 'Latest updates',
            subtitle:
                'Recent alerts help customers stay informed while orders move through the workflow.',
          ),
          const SizedBox(height: 14),
          ...notifications
              .take(2)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFF7ED),
                        child: Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFFC2410C),
                        ),
                      ),
                      title: Text(item.title),
                      subtitle: Text(item.body),
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class CustomerAccountTab extends ConsumerWidget {
  const CustomerAccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(customerCurrentUserProvider);
    if (user == null) {
      return const EmptyStateView(
        title: 'Account unavailable',
        message: 'Sign in again to manage your customer account settings.',
        icon: Icons.person_outline_rounded,
      );
    }
    final account = ref.watch(accountPreferencesProvider(user.id));
    final settings = ref.watch(appSettingsControllerProvider);

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Account tools',
                  subtitle:
                      'Saved addresses, payment methods, and personal preferences stay ready for checkout.',
                ),
                const SizedBox(height: 14),
                _QuickActionTile(
                  icon: Icons.location_on_outlined,
                  title: 'Saved addresses',
                  subtitle:
                      '${account.savedAddresses.length} locations ready for faster checkout.',
                ),
                _QuickActionTile(
                  icon: Icons.credit_card_outlined,
                  title: 'Payment methods',
                  subtitle:
                      '${account.paymentMethods.length} saved payment placeholders managed from your account center.',
                ),
                _QuickActionTile(
                  icon: Icons.tune_rounded,
                  title: 'Preferences',
                  subtitle:
                      'Dark mode ${settings.darkModeEnabled ? 'on' : 'off'}, readable text ${settings.largerTextEnabled ? 'on' : 'off'}.',
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Open account center',
                  icon: Icons.manage_accounts_outlined,
                  onPressed: () => context.push(AppRoutes.accountHub),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Open settings',
                  variant: ButtonVariant.tonal,
                  icon: Icons.settings_outlined,
                  onPressed: () => context.push(AppRoutes.settings),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class CustomerOrdersTab extends ConsumerWidget {
  const CustomerOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(customerOrdersProvider);

    if (orders.isEmpty) {
      return EmptyStateView(
        title: 'No orders yet',
        message:
            'Your orders will appear here with live status labels and delivery details.',
        actionLabel: 'Browse businesses',
        onAction: () => context.push(AppRoutes.businessList),
      );
    }

    return ListView(
      children: [
        const SectionHeader(
          title: 'Order history',
          subtitle:
              'New checkouts appear here immediately so every order stays visible from payment to dropoff.',
        ),
        const SizedBox(height: 16),
        ...orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                leading: CircleAvatar(
                  backgroundColor: _statusColor(
                    order.status,
                  ).withValues(alpha: 0.14),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: _statusColor(order.status),
                  ),
                ),
                title: Text('${order.id} - ${order.businessName}'),
                subtitle: Text(
                  '${order.totalItems} items - ${_statusLabel(order.status)} - GHS ${order.totalAmount.toStringAsFixed(2)}',
                ),
                trailing: Text(
                  '${order.createdAt.day}/${order.createdAt.month}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                onTap: () => context.push(
                  '${AppRoutes.customerOrderDetail}/${order.id}',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Color _statusColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => const Color(0xFFC2410C),
      OrderStatus.confirmed => const Color(0xFF0F766E),
      OrderStatus.preparing => const Color(0xFF2563EB),
      OrderStatus.ready => const Color(0xFF7C3AED),
      OrderStatus.pickedUp => const Color(0xFF0F766E),
      OrderStatus.delivering => const Color(0xFF0891B2),
      OrderStatus.deliveredPendingProofReview => const Color(0xFF2563EB),
      OrderStatus.delivered => const Color(0xFF15803D),
      OrderStatus.cancelled => const Color(0xFFDC2626),
    };
  }

  static String _statusLabel(OrderStatus status) {
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

class MetricItemCard extends StatelessWidget {
  const MetricItemCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(icon, color: color),
              ),
              const Spacer(),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
