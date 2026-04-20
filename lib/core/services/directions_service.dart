import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import 'maps_service.dart';

final directionsServiceProvider = Provider<DirectionsService>((ref) {
  return const DirectionsService();
});

class DirectionsService {
  const DirectionsService();

  static final Map<_RouteCacheKey, _CachedRouteEntry> _cache =
      <_RouteCacheKey, _CachedRouteEntry>{};
  static const _requestTimeout = Duration(seconds: 8);
  static const _cacheTtl = Duration(seconds: 75);

  bool get isConfigured => AppConfig.isRoutingConfigured;

  Future<RouteFetchResult> fetchRoute({
    required TrackingCoordinate start,
    required TrackingCoordinate end,
  }) async {
    if (!isConfigured) {
      return const RouteFetchResult(
        points: [],
        source: RouteSource.unavailable,
        message: 'Routing is not configured.',
      );
    }

    final cacheKey = _RouteCacheKey.from(start: start, end: end);
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) <= _cacheTtl) {
      return RouteFetchResult(
        points: cached.points,
        source: RouteSource.cache,
        message: 'Using a cached road route.',
      );
    }

    final baseUri = Uri.parse(AppConfig.osrmRouteBaseUrl);
    final uri = baseUri.replace(
      path:
          '${baseUri.path}/route/v1/driving/'
          '${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
      },
    );

    final response = await _performRequestWithRetry(uri);
    if (response == null || response.statusCode != 200) {
      return RouteFetchResult(
        points: const [],
        source: RouteSource.failed,
        message: response == null
            ? 'Routing request timed out.'
            : 'Routing request failed with status ${response.statusCode}.',
      );
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = decoded['routes'] as List<dynamic>? ?? const [];
      if (routes.isEmpty) {
        return const RouteFetchResult(
          points: [],
          source: RouteSource.failed,
          message: 'No routes were returned for this segment.',
        );
      }

      final firstRoute = routes.first as Map<String, dynamic>;
      final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>? ?? const [];
      if (coordinates.length < 2) {
        return const RouteFetchResult(
          points: [],
          source: RouteSource.failed,
          message: 'The routing response did not include enough geometry.',
        );
      }

      final points = coordinates
          .whereType<List<dynamic>>()
          .where((item) => item.length >= 2)
          .map(
            (item) => TrackingCoordinate(
              latitude: (item[1] as num).toDouble(),
              longitude: (item[0] as num).toDouble(),
              label: 'Route point',
            ),
          )
          .toList(growable: false);
      if (points.length < 2) {
        return const RouteFetchResult(
          points: [],
          source: RouteSource.failed,
          message: 'The decoded route geometry was incomplete.',
        );
      }
      _cache[cacheKey] = _CachedRouteEntry(
        points: points,
        cachedAt: DateTime.now(),
      );
      return const RouteFetchResult(
        points: [],
        source: RouteSource.failed,
        message: '',
      ).copyWith(
        points: points,
        source: RouteSource.network,
        message: 'Using a routed road path.',
      );
    } catch (_) {
      return const RouteFetchResult(
        points: [],
        source: RouteSource.failed,
        message: 'Routing data could not be parsed cleanly.',
      );
    }
  }

  TrackingMapPolyline routedPolyline({
    required String id,
    required List<TrackingCoordinate> points,
    required int colorValue,
    int width = 5,
  }) {
    return TrackingMapPolyline(
      id: id,
      points: points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList(growable: false),
      color: Color(colorValue),
      width: width,
    );
  }

  Future<http.Response?> _performRequestWithRetry(Uri uri) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http.get(uri).timeout(_requestTimeout);
        if (response.statusCode >= 500 && attempt == 0) {
          continue;
        }
        return response;
      } on TimeoutException {
        if (attempt == 1) {
          return null;
        }
      } catch (_) {
        if (attempt == 1) {
          return null;
        }
      }
    }
    return null;
  }
}

enum RouteSource { network, cache, failed, unavailable }

class RouteFetchResult {
  const RouteFetchResult({
    required this.points,
    required this.source,
    required this.message,
  });

  final List<TrackingCoordinate> points;
  final RouteSource source;
  final String message;

  bool get hasGeometry => points.length >= 2;
  bool get isRouted =>
      source == RouteSource.network || source == RouteSource.cache;

  RouteFetchResult copyWith({
    List<TrackingCoordinate>? points,
    RouteSource? source,
    String? message,
  }) {
    return RouteFetchResult(
      points: points ?? this.points,
      source: source ?? this.source,
      message: message ?? this.message,
    );
  }
}

class _RouteCacheKey {
  const _RouteCacheKey({
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
  });

  factory _RouteCacheKey.from({
    required TrackingCoordinate start,
    required TrackingCoordinate end,
  }) {
    return _RouteCacheKey(
      startLatitude: _quantize(start.latitude),
      startLongitude: _quantize(start.longitude),
      endLatitude: _quantize(end.latitude),
      endLongitude: _quantize(end.longitude),
    );
  }

  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;

  @override
  bool operator ==(Object other) {
    return other is _RouteCacheKey &&
        other.startLatitude == startLatitude &&
        other.startLongitude == startLongitude &&
        other.endLatitude == endLatitude &&
        other.endLongitude == endLongitude;
  }

  @override
  int get hashCode =>
      Object.hash(startLatitude, startLongitude, endLatitude, endLongitude);

  static double _quantize(double value) => double.parse(value.toStringAsFixed(4));
}

class _CachedRouteEntry {
  const _CachedRouteEntry({
    required this.points,
    required this.cachedAt,
  });

  final List<TrackingCoordinate> points;
  final DateTime cachedAt;
}
