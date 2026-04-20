import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/maps_service.dart';
import '../../../../core/utils/order_destination_source_codec.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/tracking_map_card.dart';
import '../../../operations/presentation/controllers/tracking_map_providers.dart';
import '../controllers/customer_providers.dart';
import '../../domain/models/delivery_order.dart';

class CustomerTrackingScreen extends ConsumerWidget {
  const CustomerTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(customerOrdersProvider);
    final mapsService = ref.watch(mapsServiceProvider);

    DeliveryOrder? order;
    for (final item in orders) {
      if (item.id == orderId) {
        order = item;
        break;
      }
    }

    if (order == null) {
      return AppShell(
        child: const Center(
          child: Text('Tracking details are unavailable for this order.'),
        ),
      );
    }

    final business = ref.watch(orderBusinessProvider(order.businessId));
    final riderLocation = ref.watch(orderRiderLocationProvider(orderId));
    final destinationAsync = ref.watch(
      customerDestinationCoordinateProvider(orderId),
    );

    final businessPoint = business == null
        ? null
        : mapsService.coordinateFromRaw(
            latitude: business.latitude,
            longitude: business.longitude,
            label: business.name,
          );
    final riderPoint = riderLocation == null
        ? null
        : mapsService.coordinateFromRaw(
            latitude: riderLocation.latitude,
            longitude: riderLocation.longitude,
            label: riderLocation.riderName,
          );
    final destinationPoint = destinationAsync.valueOrNull;
    final activeTarget = order.status.index >= OrderStatus.pickedUp.index
        ? destinationPoint
        : businessPoint;

    final overviewRoute = ref.watch(
      routedPolylineProvider(
        RoutePolylineRequest(
          id: 'business-to-customer',
          start: businessPoint,
          end: destinationPoint,
          colorValue: 0xFF2563EB,
        ),
      ),
    );
    final riderRoute = ref.watch(
      routedPolylineProvider(
        RoutePolylineRequest(
          id: 'rider-to-target',
          start: riderPoint,
          end: activeTarget,
          colorValue: 0xFF0F766E,
          width: 6,
        ),
      ),
    );

    final trackingPoints = <TrackingCoordinate>[
      if (businessPoint != null) businessPoint,
      if (destinationPoint != null) destinationPoint,
      if (riderPoint != null) riderPoint,
    ];

    final markers = <TrackingMapMarker>{
      if (businessPoint != null)
        mapsService.marker(
          id: 'business',
          point: businessPoint,
          title: businessPoint.label,
          snippet: 'Pickup location',
          color: const Color(0xFF0EA5E9),
          icon: Icons.storefront_rounded,
        ),
      if (destinationPoint != null)
        mapsService.marker(
          id: 'customer',
          point: destinationPoint,
          title: order.customerName,
          snippet:
              '${order.destinationSource.label}: ${order.deliveryAddress}',
          color: const Color(0xFFF97316),
          icon: Icons.location_on_rounded,
        ),
      if (riderPoint != null)
        mapsService.marker(
          id: 'rider',
          point: riderPoint,
          title: riderPoint.label,
          snippet: 'Live rider position',
          color: const Color(0xFF16A34A),
          icon: Icons.delivery_dining_rounded,
        ),
    };

    final polylines = <TrackingMapPolyline>{
      if (businessPoint != null && destinationPoint != null)
        overviewRoute.valueOrNull?.polyline ??
            mapsService.directPolyline(
              id: 'business-to-customer',
              start: businessPoint,
              end: destinationPoint,
              colorValue: 0xFF2563EB,
            ),
      if (riderPoint != null && activeTarget != null)
        riderRoute.valueOrNull?.polyline ??
            mapsService.directPolyline(
              id: 'rider-to-target',
              start: riderPoint,
              end: activeTarget,
              colorValue: 0xFF0F766E,
              width: 6,
            ),
    };

    final fallbackMessage = destinationAsync.isLoading
        ? 'Resolving the delivery destination for the map view...'
        : destinationPoint == null
        ? 'The delivery address could not be pinned yet, so tracking is staying in summary mode.'
        : MapsService.fallbackMessage;

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
                  title: 'Delivery tracking',
                  subtitle: '${order.businessName} to ${order.deliveryAddress}',
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
                  TrackingMapCard(
                    mapsService: mapsService,
                    title: 'Live map',
                    subtitle:
                        'Track the business, your delivery location, and the rider position on OpenStreetMap tiles.',
                    markers: markers,
                    polylines: polylines,
                    legendItems: const [
                      TrackingMapLegendItem(
                        label: 'Business',
                        color: Color(0xFF0EA5E9),
                        icon: Icons.storefront_rounded,
                      ),
                      TrackingMapLegendItem(
                        label: 'Destination',
                        color: Color(0xFFF97316),
                        icon: Icons.location_on_rounded,
                      ),
                      TrackingMapLegendItem(
                        label: 'Rider',
                        color: Color(0xFF16A34A),
                        icon: Icons.delivery_dining_rounded,
                      ),
                    ],
                    interactionHint: 'Drag to pan and pinch to zoom the map.',
                    trackingPoints: trackingPoints,
                    fallbackMessage: fallbackMessage,
                  ),
                  const SizedBox(height: 16),
                  _InfoBanner(
                    title: order.riderName == null
                        ? 'Awaiting rider assignment'
                        : 'Assigned rider',
                    body: order.riderName == null
                        ? 'A rider has not been assigned yet, so the map will update as soon as dispatch begins.'
                        : '${order.riderName} is handling this order${order.riderPhone == null ? '.' : ' and can be reached from your order details screen.'}',
                  ),
                  const SizedBox(height: 14),
                  _InfoBanner(
                    title: 'Destination snapshot',
                    body: order.destinationSource ==
                            OrderDestinationSource.currentLocation
                        ? 'The destination marker shows the current-location snapshot captured at checkout. It does not move with the device after the order is placed.'
                        : 'The destination marker shows the typed delivery address captured at checkout. It stays fixed for this order.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricChip(
                        label: 'Status',
                        value: _statusLabel(order.status),
                      ),
                      _MetricChip(
                        label: 'ETA',
                        value: _etaText(
                          status: order.status,
                          baseMinutes: business?.estimatedDeliveryMinutes,
                        ),
                      ),
                      _MetricChip(
                        label: 'Items',
                        value: '${order.totalItems}',
                      ),
                      _MetricChip(
                        label: 'Total',
                        value: 'GHS ${order.totalAmount.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    destinationAsync.isLoading
                        ? 'Resolving destination pin for ${order.deliveryAddress}'
                        : riderPoint == null
                        ? 'No live rider update yet. The map is currently showing the business and your fixed destination only.'
                        : '${_routeModeLabel(
                              riderRoute.valueOrNull,
                              activeTargetLabel: order.status.index >=
                                      OrderStatus.pickedUp.index
                                  ? 'delivery destination'
                                  : 'pickup point',
                            )} Latest rider update: ${riderPoint.latitude.toStringAsFixed(4)}, ${riderPoint.longitude.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  if (overviewRoute.valueOrNull != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      overviewRoute.valueOrNull!.isFallback
                          ? 'Store-to-destination overview is using a direct line because a road route was not available.'
                          : 'Store-to-destination overview is using a routed road path.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: overviewRoute.valueOrNull!.isFallback
                            ? const Color(0xFF92400E)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                  if (destinationAsync.hasError) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Map note: the delivery address could not be geocoded, so the destination marker is using a fallback when possible.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _etaText({
    required OrderStatus status,
    required int? baseMinutes,
  }) {
    if (status == OrderStatus.delivered) {
      return 'Delivered';
    }
    if (status == OrderStatus.deliveredPendingProofReview) {
      return 'Proof review';
    }
    if (status == OrderStatus.cancelled) {
      return 'Cancelled';
    }
    final minutes = switch (status) {
      OrderStatus.pending => baseMinutes ?? 30,
      OrderStatus.confirmed => (baseMinutes ?? 30) - 5,
      OrderStatus.preparing => (baseMinutes ?? 30) - 8,
      OrderStatus.ready => 15,
      OrderStatus.pickedUp => 12,
      OrderStatus.delivering => 8,
      OrderStatus.deliveredPendingProofReview => 5,
      OrderStatus.delivered => 0,
      OrderStatus.cancelled => 0,
    };
    return '${minutes.clamp(5, 60)} min';
  }

  String _statusLabel(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => 'Pending confirmation',
      OrderStatus.confirmed => 'Confirmed by business',
      OrderStatus.preparing => 'Being prepared',
      OrderStatus.ready => 'Ready for pickup',
      OrderStatus.pickedUp => 'Picked up',
      OrderStatus.delivering => 'Out for delivery',
      OrderStatus.deliveredPendingProofReview => 'Awaiting proof review',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  String _routeModeLabel(
    RoutePolylineResolution? route, {
    required String activeTargetLabel,
  }) {
    if (route == null) {
      return 'Preparing the rider route to the $activeTargetLabel.';
    }
    if (route.isFallback) {
      return 'The rider line is using a direct-line fallback to the $activeTargetLabel.';
    }
    return 'The rider line is using a routed road path to the $activeTargetLabel.';
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

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
