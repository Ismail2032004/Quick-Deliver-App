import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/maps_service.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/tracking_map_card.dart';
import '../../../customer/domain/models/delivery_order.dart';
import '../../../operations/presentation/controllers/tracking_map_providers.dart';
import '../../../operations/presentation/controllers/delivery_hub_controller.dart';

class RiderTrackingScreen extends ConsumerWidget {
  const RiderTrackingScreen({super.key, this.orderId});

  final String? orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(deliveryHubProvider);
    final mapsService = ref.watch(mapsServiceProvider);
    DeliveryOrder? order;
    if (orderId != null) {
      for (final item in hub.orders) {
        if (item.id == orderId) {
          order = item;
          break;
        }
      }
    }

    if (order == null) {
      return AppShell(
        child: const Center(
          child: Text('Open an assigned delivery to use rider tracking.'),
        ),
      );
    }

    final business = ref.watch(orderBusinessProvider(order.businessId));
    final riderLocation = ref.watch(orderRiderLocationProvider(order.id));
    final destinationAsync = ref.watch(
      orderDestinationCoordinateProvider(order.id),
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
        : destinationAsync.valueOrNull!.copyWithLabel(order.customerName);
    final riderPoint = riderLocation == null
        ? null
        : mapsService.coordinateFromRaw(
            latitude: riderLocation.latitude,
            longitude: riderLocation.longitude,
            label: riderLocation.riderName,
          );
    final activeTarget = order.status.index >= OrderStatus.pickedUp.index
        ? dropoffPoint
        : pickupPoint;
    final overviewRoute = ref.watch(
      routedPolylineProvider(
        RoutePolylineRequest(
          id: 'pickup-to-dropoff',
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

    final trackingPoints = <TrackingCoordinate>[
      if (pickupPoint != null) pickupPoint,
      if (dropoffPoint != null) dropoffPoint,
      if (riderPoint != null) riderPoint,
    ];

    final markers = <TrackingMapMarker>{
      if (pickupPoint != null)
        mapsService.marker(
          id: 'pickup',
          point: pickupPoint,
          title: pickupPoint.label,
          snippet: 'Pickup location',
          color: const Color(0xFF0EA5E9),
          icon: Icons.storefront_rounded,
        ),
      if (dropoffPoint != null)
        mapsService.marker(
          id: 'dropoff',
          point: dropoffPoint,
          title: order.customerName,
          snippet: order.deliveryAddress,
          color: const Color(0xFFF97316),
          icon: Icons.location_on_rounded,
        ),
      if (riderPoint != null)
        mapsService.marker(
          id: 'rider',
          point: riderPoint,
          title: riderPoint.label,
          snippet: 'Your current location',
          color: const Color(0xFF16A34A),
          icon: Icons.delivery_dining_rounded,
        ),
    };

    final polylines = <TrackingMapPolyline>{
      if (pickupPoint != null && dropoffPoint != null)
        overviewRoute.valueOrNull?.polyline ??
            mapsService.directPolyline(
              id: 'pickup-to-dropoff',
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

    final fallbackMessage = destinationAsync.isLoading
        ? 'Resolving the drop-off address for the live rider map...'
        : dropoffPoint == null
        ? 'The drop-off point could not be pinned yet, so tracking is staying in summary mode.'
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
                  title: 'Live tracking',
                  subtitle:
                      '${order.businessName} to ${order.deliveryAddress}',
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
                    title: 'Route map',
                    subtitle:
                        'Track pickup, drop-off, and your live rider position on OpenStreetMap tiles.',
                    markers: markers,
                    polylines: polylines,
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
                    interactionHint: 'Drag to pan and pinch to zoom the map.',
                    trackingPoints: trackingPoints,
                    fallbackMessage: fallbackMessage,
                  ),
                  const SizedBox(height: 16),
                  _TrackingInfoLine(
                    label: 'Route',
                    value:
                        '${order.businessName} -> ${order.deliveryAddress}',
                  ),
                  const SizedBox(height: 10),
                  _TrackingInfoLine(
                    label: 'Active target',
                    value: order.status.index >= OrderStatus.pickedUp.index
                        ? 'Head to customer drop-off'
                        : 'Head to business pickup',
                  ),
                  const SizedBox(height: 10),
                  _TrackingInfoLine(
                    label: 'Active route mode',
                    value: riderRoute.valueOrNull == null
                        ? 'Refreshing the live route segment.'
                        : riderRoute.valueOrNull!.isFallback
                        ? 'Using a direct-line fallback for the current rider leg.'
                        : riderRoute.valueOrNull!.isCached
                        ? 'Using a cached road route until the rider moves meaningfully.'
                        : 'Using a routed road path for the current rider leg.',
                  ),
                  const SizedBox(height: 10),
                  _TrackingInfoLine(
                    label: 'Rider status',
                    value: order.riderName == null
                        ? 'No active rider assignment for this delivery yet.'
                        : '${order.riderName} is currently ${_statusLabel(order.status).toLowerCase()}.',
                  ),
                  const SizedBox(height: 10),
                  _TrackingInfoLine(
                    label: 'Latest location',
                    value: riderPoint == null
                        ? 'No live location has been shared for this order yet.'
                        : '${riderPoint.latitude.toStringAsFixed(4)}, ${riderPoint.longitude.toStringAsFixed(4)}',
                  ),
                  if (destinationAsync.hasError) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Map note: the drop-off address could not be geocoded, so the map is prioritizing the live rider and pickup markers.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ] else if (overviewRoute.valueOrNull != null &&
                      overviewRoute.valueOrNull!.isFallback) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Map note: the pickup-to-drop-off overview is using a direct line because routed directions were unavailable.',
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

  String _statusLabel(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => 'Pending',
      OrderStatus.confirmed => 'Confirmed',
      OrderStatus.preparing => 'Preparing',
      OrderStatus.ready => 'Ready for pickup',
      OrderStatus.pickedUp => 'Picked up',
      OrderStatus.delivering => 'Delivering',
      OrderStatus.deliveredPendingProofReview => 'Proof submitted',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };
  }
}

class _TrackingInfoLine extends StatelessWidget {
  const _TrackingInfoLine({required this.label, required this.value});

  final String label;
  final String value;

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
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
