import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/directions_service.dart';
import '../../../../core/services/maps_service.dart';
import '../../../../core/utils/order_destination_source_codec.dart';
import '../../../customer/domain/models/business.dart';
import '../../../customer/domain/models/delivery_order.dart';
import '../../../operations/domain/models/rider_location.dart';
import '../../../customer/presentation/controllers/customer_providers.dart';
import 'delivery_hub_controller.dart';

final orderBusinessProvider =
    Provider.family<Business?, String>((ref, businessId) {
  final businesses = ref.watch(
    deliveryHubProvider.select((state) => state.businesses),
  );
  for (final business in businesses) {
    if (business.id == businessId) {
      return business;
    }
  }
  return null;
});

final orderRiderLocationProvider =
    Provider.family<RiderLocation?, String>((ref, orderId) {
  final riderLocations = ref.watch(
    deliveryHubProvider.select((state) => state.riderLocations),
  );
  for (final location in riderLocations) {
    if (location.orderId == orderId) {
      return location;
    }
  }
  return null;
});

final customerDestinationCoordinateProvider =
    FutureProvider.family<TrackingCoordinate?, String>((ref, orderId) async {
      final orders = ref.watch(customerOrdersProvider);
      for (final order in orders) {
        if (order.id == orderId) {
          return _resolveOrderDestination(ref, order);
        }
      }
      return null;
    });

final orderDestinationCoordinateProvider =
    FutureProvider.family<TrackingCoordinate?, String>((ref, orderId) async {
      final orders = ref.watch(
        deliveryHubProvider.select((state) => state.orders),
      );
      for (final order in orders) {
        if (order.id == orderId) {
          return _resolveOrderDestination(ref, order);
        }
      }
      return null;
    });

final deliveryAddressCoordinateProvider =
    FutureProvider.family<TrackingCoordinate?, String>((ref, address) async {
      return ref.read(mapsServiceProvider).geocodeAddress(address);
    });

final routedPolylineProvider =
    FutureProvider.family<RoutePolylineResolution?, RoutePolylineRequest>((
      ref,
      request,
    ) async {
      final cachedResolution = _RouteResolutionCache.lookup(request.id);
      if (request.start == null || request.end == null) {
        return cachedResolution;
      }

      final routeResult = await ref
          .read(directionsServiceProvider)
          .fetchRoute(start: request.start!, end: request.end!);
      if (routeResult.hasGeometry) {
        final resolution = RoutePolylineResolution(
          polyline: ref.read(directionsServiceProvider).routedPolyline(
            id: request.id,
            points: routeResult.points,
            colorValue: request.colorValue,
            width: request.width,
          ),
          isFallback: false,
          source: routeResult.source,
          message: routeResult.message,
        );
        _RouteResolutionCache.store(request.id, resolution);
        return resolution;
      }
      final fallbackResolution = RoutePolylineResolution(
        polyline: ref.read(mapsServiceProvider).directPolyline(
          id: request.id,
          start: request.start!,
          end: request.end!,
          colorValue: request.colorValue,
          width: request.width,
        ),
        isFallback: true,
        source: routeResult.source,
        message: routeResult.message.isEmpty
            ? 'Using a direct-line fallback for this route segment.'
            : '${routeResult.message} Using a direct-line fallback for this segment.',
      );
      _RouteResolutionCache.store(request.id, fallbackResolution);
      return fallbackResolution;
    });

class RoutePolylineRequest {
  const RoutePolylineRequest({
    required this.id,
    required this.start,
    required this.end,
    required this.colorValue,
    this.width = 5,
  });

  final String id;
  final TrackingCoordinate? start;
  final TrackingCoordinate? end;
  final int colorValue;
  final int width;

  @override
  bool operator ==(Object other) {
    return other is RoutePolylineRequest &&
        other.id == id &&
        other.start?.latitude == start?.latitude &&
        other.start?.longitude == start?.longitude &&
        other.end?.latitude == end?.latitude &&
        other.end?.longitude == end?.longitude &&
        other.colorValue == colorValue &&
        other.width == width;
  }

  @override
  int get hashCode => Object.hash(
    id,
    start?.latitude,
    start?.longitude,
    end?.latitude,
    end?.longitude,
    colorValue,
    width,
  );
}

class RoutePolylineResolution {
  const RoutePolylineResolution({
    required this.polyline,
    required this.isFallback,
    required this.source,
    required this.message,
  });

  final TrackingMapPolyline polyline;
  final bool isFallback;
  final RouteSource source;
  final String message;

  bool get isCached => source == RouteSource.cache;
  bool get isRouted => !isFallback;
}

class _RouteResolutionCache {
  static final Map<String, _CachedRouteResolution> _entries =
      <String, _CachedRouteResolution>{};
  static const _ttl = Duration(seconds: 45);

  static RoutePolylineResolution? lookup(String id) {
    final entry = _entries[id];
    if (entry == null) {
      return null;
    }
    if (DateTime.now().difference(entry.cachedAt) > _ttl) {
      _entries.remove(id);
      return null;
    }
    return entry.resolution;
  }

  static void store(String id, RoutePolylineResolution resolution) {
    _entries[id] = _CachedRouteResolution(
      resolution: resolution,
      cachedAt: DateTime.now(),
    );
  }
}

class _CachedRouteResolution {
  const _CachedRouteResolution({
    required this.resolution,
    required this.cachedAt,
  });

  final RoutePolylineResolution resolution;
  final DateTime cachedAt;
}

Future<TrackingCoordinate?> _resolveOrderDestination(
  Ref ref,
  DeliveryOrder order,
) async {
  final rawCoordinate = ref.read(mapsServiceProvider).coordinateFromRaw(
    latitude: order.destinationLatitude ?? 0,
    longitude: order.destinationLongitude ?? 0,
    label: order.customerName,
  );
  if (rawCoordinate != null) {
    return rawCoordinate;
  }
  final geocoded = await ref.read(mapsServiceProvider).geocodeAddress(
    order.deliveryAddress,
    label: order.customerName,
  );
  if (geocoded != null) {
    return geocoded;
  }
  if (order.destinationSource == OrderDestinationSource.currentLocation) {
    final fallback = ref.read(customerLocationProvider);
    return TrackingCoordinate(
      latitude: fallback.latitude,
      longitude: fallback.longitude,
      label: order.customerName,
    );
  }
  return null;
}
