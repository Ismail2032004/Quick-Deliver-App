import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/order_status_codec.dart';
import '../../../../core/utils/order_workflow.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/phone_service.dart';
import '../../../../core/utils/delivery_user_messages.dart';
import '../../../../shared/widgets/safe_network_image.dart';
import '../../../../shared/widgets/order_status_timeline.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../customer/domain/models/delivery_order.dart';
import '../../../dashboard/presentation/controllers/dashboard_tab_controller.dart';
import '../../../settings/presentation/controllers/app_settings_controller.dart';
import '../../../account/presentation/controllers/account_preferences_controller.dart';
import '../../../operations/presentation/controllers/delivery_hub_controller.dart';

const _showRawAcceptDeliveryError = true;

class RiderDispatchTab extends ConsumerWidget {
  const RiderDispatchTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authControllerProvider).currentUser;
    final orders = ref.watch(
      deliveryHubProvider.select((state) => state.orders),
    );
    final notifications = ref.watch(
      deliveryHubProvider.select((state) => state.notifications),
    );
    final awaitingDecision = orders
        .where((order) => _isAwaitingRiderDecision(order, currentUser?.id))
        .length;
    final activeAssignments = orders
        .where((order) => _isActiveRiderOrder(order, currentUser?.id))
        .length;

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFFF97316), Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rider operations center',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Accept deliveries, update live status, capture proof photos, and keep customers informed.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
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
            _RiderMetricCard(
              label: 'Awaiting reply',
              value: '$awaitingDecision',
              color: const Color(0xFFF97316),
              icon: Icons.local_shipping_outlined,
              onTap: () {
                ref.read(dashboardTabProvider('rider-dashboard').notifier).state =
                    1;
              },
            ),
            _RiderMetricCard(
              label: 'Active',
              value: '$activeAssignments',
              color: const Color(0xFF0F766E),
              icon: Icons.assignment_turned_in_outlined,
              onTap: () {
                ref.read(dashboardTabProvider('rider-dashboard').notifier).state =
                    1;
              },
            ),
            _RiderMetricCard(
              label: 'Alerts',
              value: '${notifications.where((item) => !item.isRead).length}',
              color: const Color(0xFF2563EB),
              icon: Icons.notifications_active_outlined,
              onTap: () => context.push(AppRoutes.riderNotifications),
            ),
            _RiderMetricCard(
              label: 'Proof flow',
              value: 'Ready',
              color: const Color(0xFF2563EB),
              icon: Icons.camera_alt_outlined,
              onTap: () {
                DeliveryOrder? firstAssigned;
                for (final order in orders) {
                  if (_isProofEligibleOrder(order, currentUser?.id)) {
                    firstAssigned = order;
                    break;
                  }
                }

                if (firstAssigned == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open an active delivery to continue with proof capture.',
                      ),
                    ),
                  );
                  return;
                }

                context.push(
                  '${AppRoutes.riderDeliveryDetail}/${firstAssigned.id}',
                );
              },
            ),
            _RiderMetricCard(
              label: 'Tracking',
              value: 'Live',
              color: const Color(0xFF7C3AED),
              icon: Icons.my_location_rounded,
              onTap: () {
                DeliveryOrder? firstAssigned;
                for (final order in orders) {
                  if (_isTrackableRiderOrder(order, currentUser?.id)) {
                    firstAssigned = order;
                    break;
                  }
                }

                context.push(
                  firstAssigned == null
                      ? AppRoutes.riderTracking
                      : '${AppRoutes.riderTracking}/${firstAssigned.id}',
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class RiderAccountTab extends ConsumerWidget {
  const RiderAccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).currentUser;
    if (user == null) {
      return const EmptyStateView(
        title: 'Account unavailable',
        message: 'Sign in again to manage rider account tools.',
        icon: Icons.person_outline_rounded,
      );
    }
    final settings = ref.watch(appSettingsControllerProvider);
    final account = ref.watch(accountPreferencesProvider(user.id));

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Rider account',
                  subtitle:
                      'Profile, accessibility, support, and payout-style summary tools live here.',
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Weekly pay summary'),
                  subtitle: const Text(
                    '12 completed deliveries, GHS 248.00 estimated payout, average GHS 20.60 per trip.',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Current device preferences'),
                  subtitle: Text(
                    'Dark mode ${settings.darkModeEnabled ? 'on' : 'off'}, readable text ${settings.largerTextEnabled ? 'on' : 'off'}, notifications ${settings.pushNotificationsEnabled ? 'on' : 'off'}.',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.credit_card_outlined),
                  title: const Text('Saved payout method scaffold'),
                  subtitle: Text(
                    account.paymentMethods.isEmpty
                        ? 'No payout method placeholder saved yet.'
                        : account.paymentMethods.first.details,
                  ),
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Call support',
                  variant: ButtonVariant.outlined,
                  icon: Icons.support_agent_rounded,
                  onPressed: () async {
                    final result = await ref
                        .read(phoneServiceProvider)
                        .tryCallNumber(AppConstants.supportPhone);
                    if (!context.mounted || result.success) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.message)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RiderDeliveriesTab extends ConsumerWidget {
  const RiderDeliveriesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authControllerProvider).currentUser;
    final orders = ref.watch(
      deliveryHubProvider.select((state) => state.orders),
    );
    final awaitingDecisionOrders = orders
        .where((order) => _isAwaitingRiderDecision(order, currentUser?.id))
        .toList();
    final assignedOrders = orders
        .where((order) => _isVisibleAssignedOrder(order, currentUser?.id))
        .toList();

    return ListView(
      children: [
        const SectionHeader(
          title: 'Awaiting your decision',
          subtitle:
              'Review newly assigned deliveries and decide whether to accept them.',
        ),
        const SizedBox(height: 14),
        if (awaitingDecisionOrders.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: EmptyStateView(
              title: 'No assigned deliveries waiting',
              message:
                  'New rider assignments will appear here as soon as a business dispatches them to you.',
              icon: Icons.route_rounded,
            ),
          )
        else
          ...awaitingDecisionOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order.id} - ${order.businessName}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(order.deliveryAddress),
                      const SizedBox(height: 10),
                      Text(
                        'This delivery is ready for pickup and waiting for your response.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: currentUser == null
                                  ? null
                                  : () async {
                                      try {
                                        await ref
                                            .read(deliveryHubProvider.notifier)
                                            .acceptDelivery(order.id, currentUser);
                                        if (!context.mounted) {
                                          return;
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'You accepted ${order.id}.',
                                            ),
                                          ),
                                        );
                                      } catch (error) {
                                        if (!context.mounted) {
                                          return;
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              _showRawAcceptDeliveryError
                                                  ? 'Accept delivery error: ${error.toString()}'
                                                  : deliveryUserMessage(
                                                      error,
                                                      fallback:
                                                          'We couldn\'t accept this delivery. Please try again.',
                                                    ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              child: const Text('Accept delivery'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: currentUser == null
                                  ? null
                                  : () async {
                                      try {
                                        await ref
                                            .read(deliveryHubProvider.notifier)
                                            .declineDelivery(order.id, currentUser);
                                        if (!context.mounted) {
                                          return;
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'You declined ${order.id}.',
                                            ),
                                          ),
                                        );
                                      } catch (error) {
                                        if (!context.mounted) {
                                          return;
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              deliveryUserMessage(
                                                error,
                                                fallback:
                                                    'We couldn\'t decline this delivery. Please try again.',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              child: const Text('Decline delivery'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        const SectionHeader(
          title: 'Assigned deliveries',
          subtitle:
              'Open active deliveries to manage pickup, tracking, proof, and drop-off updates.',
        ),
        const SizedBox(height: 14),
        if (assignedOrders.isEmpty)
          const EmptyStateView(
            title: 'No assigned deliveries yet',
            message:
                'Accepted deliveries show up here with pickup, delivery, proof, and tracking actions.',
            icon: Icons.assignment_turned_in_outlined,
          )
        else
          ...assignedOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  title: Text('${order.id} - ${order.businessName}'),
                  subtitle: Text(
                    '${order.deliveryAddress} - ${_riderOrderSummary(order)}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(
                    '${AppRoutes.riderDeliveryDetail}/${order.id}',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class RiderHistoryTab extends ConsumerWidget {
  const RiderHistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authControllerProvider).currentUser;
    final orders = ref.watch(
      deliveryHubProvider.select((state) => state.orders),
    );
    final delivered = orders
        .where(
          (order) =>
              order.riderId == currentUser?.id &&
              order.status == OrderStatus.delivered,
        )
        .toList();

    if (delivered.isEmpty) {
      return const EmptyStateView(
        title: 'No completed deliveries yet',
        message:
            'Completed trips with proof and final status will appear here after dropoff.',
        icon: Icons.history_rounded,
      );
    }

    return ListView(
      children: [
        const SectionHeader(
          title: 'Delivery history',
          subtitle:
              'Review completed jobs, final delivery status, and any proof captured on the route.',
        ),
        const SizedBox(height: 14),
        for (final order in delivered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.id} - ${order.businessName}',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dropoff: ${order.deliveryAddress}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Final status: ${order.status.label}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF0F766E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OrderStatusTimeline(
                      currentStatus: order.status,
                      vertical: false,
                    ),
                    if (order.deliveryProofImageUrl != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SafeNetworkImage(
                          imageUrl: order.deliveryProofImageUrl!,
                          height: 150,
                          width: double.infinity,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: () => context.push(
                          '${AppRoutes.riderDeliveryDetail}/${order.id}',
                        ),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('View details'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RiderMetricCard extends StatelessWidget {
  const _RiderMetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
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
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isAwaitingRiderDecision(DeliveryOrder order, String? riderId) {
  return order.riderId == riderId && canRiderAccept(order);
}

bool _isActiveRiderOrder(DeliveryOrder order, String? riderId) {
  return order.riderId == riderId &&
      order.status != OrderStatus.cancelled &&
      order.status != OrderStatus.delivered &&
      !_isAwaitingRiderDecision(order, riderId);
}

bool _isVisibleAssignedOrder(DeliveryOrder order, String? riderId) {
  return _isActiveRiderOrder(order, riderId) ||
      order.status == OrderStatus.deliveredPendingProofReview;
}

bool _isProofEligibleOrder(DeliveryOrder order, String? riderId) {
  return order.riderId == riderId &&
      (order.status == OrderStatus.delivering ||
          order.status == OrderStatus.deliveredPendingProofReview);
}

bool _isTrackableRiderOrder(DeliveryOrder order, String? riderId) {
  return order.riderId == riderId &&
      order.status != OrderStatus.cancelled &&
      order.status != OrderStatus.delivered &&
      order.deliveryStatus != DeliveryProgressStatus.assigned;
}

String _riderOrderSummary(DeliveryOrder order) {
  if (order.deliveryStatus != null) {
    return order.deliveryStatus!.label;
  }
  return order.status.label;
}
