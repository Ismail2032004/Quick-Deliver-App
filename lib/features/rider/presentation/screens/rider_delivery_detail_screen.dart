import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/camera_service.dart';
import '../../../../core/services/live_delivery_tracking_service.dart';
import '../../../../core/services/maps_service.dart';
import '../../../../core/services/phone_service.dart';
import '../../../../core/utils/delivery_user_messages.dart';
import '../../../../core/utils/order_workflow.dart';
import '../../../../core/utils/order_status_codec.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/contact_action_bar.dart';
import '../../../../shared/widgets/order_status_timeline.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/safe_network_image.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/tracking_map_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../customer/domain/models/business.dart';
import '../../../customer/domain/models/delivery_order.dart';
import '../../../operations/domain/models/rider_location.dart';
import '../../../operations/presentation/controllers/tracking_map_providers.dart';
import '../../../operations/presentation/controllers/delivery_hub_controller.dart';

const _showRawProofUploadError = true;
const _showRawAcceptDeliveryError = true;

class RiderDeliveryDetailScreen extends ConsumerWidget {
  const RiderDeliveryDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(deliveryHubProvider);
    final mapsService = ref.watch(mapsServiceProvider);
    final liveTracking = ref.watch(liveDeliveryTrackingServiceProvider);
    final currentUser = ref.watch(authControllerProvider).currentUser;
    final orders = hub.orders;
    DeliveryOrder? order;
    for (final item in orders) {
      if (item.id == orderId) {
        order = item;
        break;
      }
    }
    if (order == null) {
      return const _DeliveryNotFoundView();
    }
    final currentOrder = order;
    if (currentUser == null || currentOrder.riderId != currentUser.id) {
      return const _DeliveryNotFoundView(
        message:
            'This delivery is not assigned to the signed-in rider right now.',
      );
    }
    Business? business;
    for (final item in hub.businesses) {
      if (item.id == currentOrder.businessId) {
        business = item;
        break;
      }
    }

    RiderLocation? riderLocation;
    if (currentOrder.riderId != null) {
      for (final location in hub.riderLocations) {
        if (location.riderId == currentOrder.riderId &&
            location.orderId == currentOrder.id) {
          riderLocation = location;
          break;
        }
      }
    }

    final destinationAsync = ref.watch(
      orderDestinationCoordinateProvider(currentOrder.id),
    );
    final pickupPoint = business == null
        ? null
        : mapsService.coordinateFromRaw(
            latitude: business.latitude,
            longitude: business.longitude,
            label: business.name,
          );
    final dropoffPoint = destinationAsync.valueOrNull == null
        ? null
        : destinationAsync.valueOrNull!.copyWithLabel(currentOrder.customerName);
    final riderPoint = riderLocation == null
        ? null
        : mapsService.coordinateFromRaw(
            latitude: riderLocation.latitude,
            longitude: riderLocation.longitude,
            label: riderLocation.riderName,
          );
    final activeTarget = currentOrder.status.index >= OrderStatus.pickedUp.index
        ? dropoffPoint
        : pickupPoint;
    final overviewRoute = ref.watch(
      routedPolylineProvider(
        RoutePolylineRequest(
          id: 'route-overview',
          start: pickupPoint,
          end: dropoffPoint,
          colorValue: 0xFF7C3AED,
        ),
      ),
    );
    final riderRoute = ref.watch(
      routedPolylineProvider(
        RoutePolylineRequest(
          id: 'rider-to-target',
          start: riderPoint,
          end: activeTarget,
          colorValue: 0xFFF97316,
          width: 6,
        ),
      ),
    );
    final mapPoints = <TrackingCoordinate>[
      if (pickupPoint != null) pickupPoint,
      if (dropoffPoint != null) dropoffPoint,
      if (riderPoint != null) riderPoint,
    ];
    final mapMarkers = <TrackingMapMarker>{
      if (pickupPoint != null)
        mapsService.marker(
          id: 'pickup',
          point: pickupPoint,
          title: pickupPoint.label,
          snippet: 'Pickup',
          color: const Color(0xFF0EA5E9),
          icon: Icons.storefront_rounded,
        ),
      if (dropoffPoint != null)
        mapsService.marker(
          id: 'dropoff',
          point: dropoffPoint,
          title: currentOrder.customerName,
          snippet: currentOrder.deliveryAddress,
          color: const Color(0xFFF97316),
          icon: Icons.location_on_rounded,
        ),
      if (riderPoint != null)
        mapsService.marker(
          id: 'rider',
          point: riderPoint,
          title: riderPoint.label,
          snippet: 'Live rider location',
          color: const Color(0xFF16A34A),
          icon: Icons.delivery_dining_rounded,
        ),
    };
    final mapPolylines = <TrackingMapPolyline>{
      if (pickupPoint != null && dropoffPoint != null)
        overviewRoute.valueOrNull?.polyline ??
            mapsService.directPolyline(
              id: 'route-overview',
              start: pickupPoint,
              end: dropoffPoint,
              colorValue: 0xFF7C3AED,
            ),
      if (riderPoint != null && activeTarget != null)
        riderRoute.valueOrNull?.polyline ??
            mapsService.directPolyline(
              id: 'rider-to-target',
              start: riderPoint,
              end: activeTarget,
              colorValue: 0xFFF97316,
              width: 6,
            ),
    };

    return AppShell(
      child: ListView(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SectionHeader(
                  title: currentOrder.id,
                  subtitle:
                      '${currentOrder.businessName} to ${currentOrder.deliveryAddress}',
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
                  const SectionHeader(
                    title: 'Pickup and dropoff',
                    subtitle:
                        'Keep the route details visible while you manage status updates and proof.',
                  ),
                  const SizedBox(height: 14),
                  _LocationTile(
                    icon: Icons.storefront_rounded,
                    title: business?.name ?? currentOrder.businessName,
                    subtitle: business == null
                        ? 'Pickup details will appear once the store profile is linked.'
                        : '${business.address}\n${business.latitude.toStringAsFixed(4)}, ${business.longitude.toStringAsFixed(4)}',
                  ),
                  const SizedBox(height: 12),
                  _LocationTile(
                    icon: Icons.location_on_outlined,
                    title: currentOrder.customerName,
                    subtitle: currentOrder.deliveryAddress,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InfoChip(label: 'Order ID', value: currentOrder.id),
                      _InfoChip(
                        label: 'Status',
                        value: currentOrder.status.label,
                      ),
                      _InfoChip(
                        label: 'Items',
                        value: '${currentOrder.totalItems}',
                      ),
                    ],
                  ),
                  if (riderLocation != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Latest rider update: ${riderLocation.latitude.toStringAsFixed(4)}, ${riderLocation.longitude.toStringAsFixed(4)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                  if (riderRoute.valueOrNull != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      riderRoute.valueOrNull!.isFallback
                          ? 'The active rider leg is using a direct-line fallback until routed directions are available again.'
                          : riderRoute.valueOrNull!.isCached
                          ? 'The active rider leg is using a cached road route to reduce redraw jitter.'
                          : 'The active rider leg is using a routed road path.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: riderRoute.valueOrNull!.isFallback
                            ? const Color(0xFF92400E)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    riderPoint == null
                        ? 'Route preview is still focused on pickup and drop-off. Once your live rider position is shared, the orange rider leg appears on top of the main route.'
                        : 'The purple path shows the full trip overview, while the orange path highlights your current rider leg.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TrackingMapCard(
                    mapsService: mapsService,
                    title: 'Navigation preview',
                    subtitle: currentOrder.status.index >= OrderStatus.pickedUp.index
                        ? 'Drop-off is highlighted while the rider is delivering.'
                        : 'Pickup is highlighted until the order is collected.',
                    markers: mapMarkers,
                    polylines: mapPolylines,
                    legendItems: const [
                      TrackingMapLegendItem(
                        label: 'Pickup',
                        color: Color(0xFF0EA5E9),
                        icon: Icons.storefront_rounded,
                      ),
                      TrackingMapLegendItem(
                        label: 'Drop-off',
                        color: Color(0xFFF97316),
                        icon: Icons.location_on_rounded,
                      ),
                      TrackingMapLegendItem(
                        label: 'Rider',
                        color: Color(0xFF16A34A),
                        icon: Icons.delivery_dining_rounded,
                      ),
                    ],
                    interactionHint: 'Drag to pan and pinch to zoom the preview map.',
                    trackingPoints: mapPoints,
                    height: 220,
                    fallbackMessage: destinationAsync.isLoading
                        ? 'Resolving the delivery destination for the map preview...'
                        : MapsService.fallbackMessage,
                  ),
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
                  Text(
                    'Delivery flow',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  OrderStatusTimeline(currentStatus: currentOrder.status),
                  const SizedBox(height: 14),
                  Text(
                    _riderStageGuidance(currentOrder),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RiderDetailActionBar(order: currentOrder),
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
                    title: 'Proof workflow',
                    subtitle:
                        'Upload delivery proof only after the drop-off is complete. The business confirms the final delivery after reviewing it.',
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: currentOrder.deliveryProofImageUrl == null
                        ? 'Upload delivery proof'
                        : 'Retake delivery proof',
                    variant: ButtonVariant.tonal,
                    icon: Icons.verified_outlined,
                    onPressed: canAttachDeliveryProof(currentOrder)
                        ? () async {
                            final image = await _chooseProofImage(
                              context,
                              ref,
                              label: 'delivery',
                            );
                            if (image == null ||
                                image.bytes == null ||
                                image.bytes!.isEmpty) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No image was captured. Please try again.',
                                  ),
                                ),
                              );
                              return;
                            }
                            try {
                              await ref
                                  .read(deliveryHubProvider.notifier)
                                  .attachDeliveryProof(
                                    orderId: currentOrder.id,
                                    image: image,
                                  );
                              await ref
                                  .read(liveDeliveryTrackingServiceProvider)
                                  .stopTracking(markInactive: true);
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Delivery proof uploaded for ${currentOrder.id}. Waiting for business review.',
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
                                    _showRawProofUploadError
                                        ? 'Proof upload error: ${error.toString()}'
                                        : deliveryUserMessage(
                                            error,
                                            fallback:
                                                'Proof upload failed. Please try again.',
                                          ),
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choose camera for a fresh drop-off photo, or use a local image when emulator camera capture is unreliable.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label:
                        liveTracking.isTracking &&
                            liveTracking.activeOrderId == currentOrder.id
                        ? 'Stop continuous live tracking'
                        : 'Start continuous live tracking',
                    icon: liveTracking.isTracking &&
                            liveTracking.activeOrderId == currentOrder.id
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    onPressed: canPublishRiderLocation(currentOrder)
                        ? () async {
                            final wasTracking =
                                liveTracking.isTracking &&
                                liveTracking.activeOrderId == currentOrder.id;
                            try {
                              if (wasTracking) {
                                await ref
                                    .read(liveDeliveryTrackingServiceProvider)
                                    .stopTracking(markInactive: false);
                              } else {
                                await ref
                                    .read(liveDeliveryTrackingServiceProvider)
                                    .startTracking(currentOrder);
                              }
                              if (!context.mounted) {
                                return;
                              }
                              final message =
                                  wasTracking
                                  ? 'Continuous live tracking stopped for this delivery.'
                                  : 'Continuous live tracking started. The map will begin preferring your live rider leg whenever fresh rider location is available.';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message)),
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
                                          'We couldn\'t update live tracking right now. Please try again.',
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Send one-time location ping',
                    variant: ButtonVariant.outlined,
                    icon: Icons.my_location_rounded,
                    onPressed: canPublishRiderLocation(currentOrder)
                        ? () async {
                            try {
                              await ref
                                  .read(liveDeliveryTrackingServiceProvider)
                                  .sendSingleUpdate(currentOrder);
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Sent one location ping for this delivery.',
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
                                          'We couldn\'t send a location ping right now. Please try again.',
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Use the one-time ping when you only need to refresh your position once. Use continuous live tracking when the business and customer should follow the trip in real time.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  if (liveTracking.lastError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      deliveryUserMessage(
                        liveTracking.lastError!,
                        fallback:
                            'We couldn\'t keep live tracking active. Please try again.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ] else if (liveTracking.isRunningInBackground &&
                      liveTracking.activeOrderId == currentOrder.id) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Android background tracking is active for this delivery. Keep location permission and the ongoing notification available for better reliability.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                  ] else if (liveTracking.isPausedByLifecycle &&
                      liveTracking.activeOrderId == currentOrder.id) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Live tracking is paused because the app is not in the foreground. Return to the app to resume updates.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ] else if (liveTracking.statusMessage != null &&
                      liveTracking.activeOrderId == currentOrder.id) ...[
                    const SizedBox(height: 12),
                    Text(
                      liveTracking.statusMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                  if (currentOrder.deliveryProofImageUrl != null) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SafeNetworkImage(
                        imageUrl: currentOrder.deliveryProofImageUrl!,
                        height: 180,
                        width: double.infinity,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
            onCallCustomer: currentOrder.customerPhone.trim().isEmpty
                ? null
                : () async {
                    final result = await ref
                        .read(phoneServiceProvider)
                        .tryCallNumber(currentOrder.customerPhone);
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
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFFFF7ED),
            child: Icon(icon, color: const Color(0xFFF97316)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryNotFoundView extends StatelessWidget {
  const _DeliveryNotFoundView({
    this.message =
        'This delivery is unavailable right now. Try reopening it from the rider dashboard.',
  });

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
                Icons.local_shipping_outlined,
                size: 52,
                color: Color(0xFF64748B),
              ),
              const SizedBox(height: 16),
              Text(
                'Delivery not found',
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

class _RiderDetailActionBar extends ConsumerWidget {
  const _RiderDetailActionBar({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authControllerProvider).currentUser;
    final rider = currentUser;
    if (rider == null) {
      return const SizedBox.shrink();
    }

    Future<void> handleStatusUpdate(
      OrderStatus status, {
      required String successMessage,
      bool stopTracking = false,
    }) async {
      try {
        await ref.read(deliveryHubProvider.notifier).updateOrderStatus(
          order.id,
          status,
        );
        if (stopTracking) {
          await ref
              .read(liveDeliveryTrackingServiceProvider)
              .stopTracking(markInactive: true);
        }
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
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
                    'We couldn\'t update the delivery status. Please try again.',
              ),
            ),
          ),
        );
      }
    }

    if (canRiderAccept(order)) {
      return Row(
        children: [
          Expanded(
            child: FilledButton.tonal(
              onPressed: () async {
                try {
                  await ref
                      .read(deliveryHubProvider.notifier)
                      .acceptDelivery(order.id, rider);
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('You accepted ${order.id}.')),
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
              onPressed: () async {
                try {
                  await ref.read(deliveryHubProvider.notifier).declineDelivery(
                    order.id,
                    rider,
                  );
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'You declined ${order.id}. It is ready for reassignment.',
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
      );
    }

    if (canRiderMarkPickedUp(order)) {
      return FilledButton.tonalIcon(
        onPressed: () => handleStatusUpdate(
          OrderStatus.pickedUp,
          successMessage: '${order.id} marked as picked up.',
        ),
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('Mark picked up'),
      );
    }

    if (canRiderMarkDelivering(order)) {
      return FilledButton.tonalIcon(
        onPressed: () => handleStatusUpdate(
          OrderStatus.delivering,
          successMessage: '${order.id} is now marked delivering.',
        ),
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text('Mark delivering'),
      );
    }

    if (order.status == OrderStatus.deliveredPendingProofReview) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Delivery proof has been submitted. Wait for the business to confirm the final delivery.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF475569),
          ),
        ),
      );
    }

    if (order.status == OrderStatus.delivered) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'This delivery is complete and confirmed.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF475569),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'No rider action is needed for this stage right now.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF475569),
        ),
      ),
    );
  }
}

String _riderStageGuidance(DeliveryOrder order) {
  return switch (order.deliveryStatus) {
    DeliveryProgressStatus.assigned =>
      'This delivery is assigned to you and waiting for your response.',
    DeliveryProgressStatus.accepted =>
      'You accepted this delivery. Mark it picked up once the order is in hand.',
    DeliveryProgressStatus.pickedUp =>
      'Pickup is complete. Mark the order delivering when you leave for the customer.',
    DeliveryProgressStatus.delivering =>
      'You are on the way. Upload delivery proof after reaching the customer.',
    DeliveryProgressStatus.proofReview =>
      'Proof is uploaded. The business is now reviewing the final handoff.',
    DeliveryProgressStatus.delivered =>
      'This delivery is complete.',
    DeliveryProgressStatus.cancelled =>
      'This delivery was cancelled.',
    null => switch (order.status) {
        OrderStatus.ready =>
          'This delivery is waiting for rider acceptance before pickup begins.',
        OrderStatus.pickedUp =>
          'Pickup is recorded. Move into delivery when you leave the business.',
        OrderStatus.delivering =>
          'You are currently delivering this order.',
        OrderStatus.deliveredPendingProofReview =>
          'Proof is uploaded and waiting for business confirmation.',
        OrderStatus.delivered => 'This delivery is complete.',
        OrderStatus.cancelled => 'This delivery was cancelled.',
        _ => 'Follow the current delivery stage shown above.',
      },
  };
}

Future<PickedProofImage?> _chooseProofImage(
  BuildContext context,
  WidgetRef ref, {
  required String label,
}) async {
  return showModalBottomSheet<PickedProofImage?>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      Future<void> choose(ImageSource source) async {
        final image = await ref.read(cameraServiceProvider).pickProofImage(
          label: label,
          source: source,
        );
        if (!sheetContext.mounted) {
          return;
        }
        if (image == null) {
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            SnackBar(
              content: Text(
                source == ImageSource.camera
                    ? 'Camera capture was not saved. You can choose a local image instead.'
                    : 'No local image was selected. Please try again.',
              ),
            ),
          );
          return;
        }
        Navigator.of(sheetContext).pop(image);
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Add delivery proof',
                subtitle:
                    'Capture a fresh proof photo or choose a local image from this device.',
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Capture proof photo',
                icon: Icons.photo_camera_back_outlined,
                onPressed: () => choose(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Choose local image',
                variant: ButtonVariant.tonal,
                icon: Icons.photo_library_outlined,
                onPressed: () => choose(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    },
  );
}
