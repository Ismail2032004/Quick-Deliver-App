import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/phone_service.dart';
import '../../../../core/utils/order_destination_source_codec.dart';
import '../../../../core/utils/order_workflow.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/contact_action_bar.dart';
import '../../../../shared/widgets/order_status_timeline.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/safe_network_image.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../domain/models/delivery_order.dart';
import '../controllers/customer_providers.dart';
import '../../../operations/presentation/controllers/delivery_hub_controller.dart';

class CustomerOrderDetailScreen extends ConsumerWidget {
  const CustomerOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(customerOrdersProvider);
    DeliveryOrder? order;
    for (final item in orders) {
      if (item.id == orderId) {
        order = item;
        break;
      }
    }

    if (order == null) {
      return const _OrderNotFoundView(
        title: 'Order not found',
        message:
            'This order is unavailable right now. Try reopening it from your order history.',
      );
    }
    final currentOrder = order;

    return AppShell(
      child: ListView(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SectionHeader(
                  title: currentOrder.id,
                  subtitle:
                      '${currentOrder.businessName} - ${currentOrder.totalItems} items',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status timeline',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  OrderStatusTimeline(currentStatus: currentOrder.status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Order details',
                    subtitle:
                        'Proof images, delivery destination, and communication options.',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentOrder.destinationSource.label,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (canEditDeliveryDestination(currentOrder))
                              TextButton.icon(
                                onPressed: () => _showEditDestinationSheet(
                                  context,
                                  ref,
                                  currentOrder,
                                ),
                                icon: const Icon(Icons.edit_location_alt_outlined),
                                label: const Text('Edit'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Deliver to: ${currentOrder.deliveryAddress}'),
                        const SizedBox(height: 4),
                        Text(
                          canEditDeliveryDestination(currentOrder)
                              ? 'You can still update this destination until the rider picks up the order.'
                              : currentOrder.destinationSource ==
                                      OrderDestinationSource.currentLocation
                                  ? 'This destination was captured from the customer device location at checkout and is now locked for this order.'
                                  : 'This typed delivery address was captured at checkout and is now locked for this order.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RiderInfoCard(order: currentOrder),
                  if (currentOrder.note != null) ...[
                    const SizedBox(height: 8),
                    Text('Note: ${currentOrder.note}'),
                  ],
                  const SizedBox(height: 14),
                  ContactActionBar(
                    onCallBusiness: currentOrder.businessPhone == null
                        ? null
                        : () async {
                            final result = await ref
                                .read(phoneServiceProvider)
                                .tryCallNumber(currentOrder.businessPhone);
                            if (!context.mounted || result.success) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                          },
                    onCallRider: currentOrder.riderPhone == null
                        ? null
                        : () async {
                            final result = await ref
                                .read(phoneServiceProvider)
                                .tryCallNumber(currentOrder.riderPhone);
                            if (!context.mounted || result.success) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                          },
                  ),
                  const SizedBox(height: 12),
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
                  if (currentOrder.pickupProofImageUrl != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Pickup proof',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SafeNetworkImage(
                        imageUrl: currentOrder.pickupProofImageUrl!,
                        height: 180,
                        width: double.infinity,
                        placeholderIcon: Icons.receipt_long_rounded,
                        placeholderLabel: 'Pickup proof',
                      ),
                    ),
                  ],
                  if (currentOrder.deliveryProofImageUrl != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Delivery proof',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SafeNetworkImage(
                        imageUrl: currentOrder.deliveryProofImageUrl!,
                        height: 180,
                        width: double.infinity,
                        placeholderIcon: Icons.verified_outlined,
                        placeholderLabel: 'Delivery proof',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Open tracking view',
            icon: Icons.map_outlined,
            onPressed: () => context.push(
              '${AppRoutes.customerTracking}/${currentOrder.id}',
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showEditDestinationSheet(
  BuildContext context,
  WidgetRef ref,
  DeliveryOrder order,
) async {
  final addressController = TextEditingController(text: order.deliveryAddress);
  var destinationSource = order.destinationSource;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final location = ref.read(customerLocationProvider);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                const SectionHeader(
                  title: 'Update delivery destination',
                  subtitle:
                      'You can only change the destination before rider pickup starts.',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('Type address'),
                      selected: destinationSource == OrderDestinationSource.manual,
                      onSelected: (_) => setState(() {
                        destinationSource = OrderDestinationSource.manual;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Use current location'),
                      selected: destinationSource ==
                          OrderDestinationSource.currentLocation,
                      onSelected: (_) async {
                        await ref
                            .read(customerLocationProvider.notifier)
                            .refreshLocation();
                        final latest = ref.read(customerLocationProvider);
                        if (!latest.canUseAsDeliveryDestination) {
                          return;
                        }
                        setState(() {
                          destinationSource =
                              OrderDestinationSource.currentLocation;
                          addressController.text = latest.fullAddress;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: addressController,
                  enabled: destinationSource == OrderDestinationSource.manual,
                  decoration: const InputDecoration(
                    labelText: 'Delivery address',
                  ),
                ),
                if (location.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    location.errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Save destination',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () async {
                    if (addressController.text.trim().isEmpty) {
                      return;
                    }
                    final latest = ref.read(customerLocationProvider);
                    try {
                      await ref
                          .read(deliveryHubProvider.notifier)
                          .updateDeliveryDestination(
                            orderId: order.id,
                            deliveryAddress: addressController.text.trim(),
                            destinationSource: destinationSource,
                            destinationLatitude:
                                destinationSource ==
                                        OrderDestinationSource.currentLocation
                                    ? latest.latitude
                                    : null,
                            destinationLongitude:
                                destinationSource ==
                                        OrderDestinationSource.currentLocation
                                    ? latest.longitude
                                    : null,
                          );
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                      return;
                    }
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _RiderInfoCard extends StatelessWidget {
  const _RiderInfoCard({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    final assigned = order.riderName != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: assigned ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assigned ? 'Assigned rider' : 'Awaiting rider assignment',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            assigned
                ? '${order.riderName} is handling this delivery. Tracking becomes clearer as the rider shares live updates.'
                : 'A business will assign a rider soon. You can still follow status updates from this page.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
            ),
          ),
          if (assigned && order.riderPhone != null) ...[
            const SizedBox(height: 6),
            Text(
              'Phone: ${order.riderPhone}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF0F766E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderNotFoundView extends StatelessWidget {
  const _OrderNotFoundView({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                size: 52,
                color: Color(0xFF64748B),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
