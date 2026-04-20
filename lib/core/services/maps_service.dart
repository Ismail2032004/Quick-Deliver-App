import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';

final mapsServiceProvider = Provider<MapsService>((ref) => const MapsService());

class MapsService {
  const MapsService();

  static const fallbackMessage =
      'Map tiles are unavailable right now, so QuickDeliver is showing a clean tracking fallback instead.';

  bool get isConfigured => AppConfig.isMapsConfigured;
  String get tileUrlTemplate => AppConfig.osmTileUrlTemplate;
  String get tileAttribution => AppConfig.osmTileAttribution;
  Uri get tileAttributionUrl =>
      Uri.parse('https://www.openstreetmap.org/copyright');

  bool isValidCoordinate(double latitude, double longitude) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        !(latitude == 0 && longitude == 0);
  }

  TrackingCoordinate? coordinateFromRaw({
    required double latitude,
    required double longitude,
    required String label,
  }) {
    if (!isValidCoordinate(latitude, longitude)) {
      return null;
    }
    return TrackingCoordinate(
      latitude: latitude,
      longitude: longitude,
      label: label,
    );
  }

  Future<TrackingCoordinate?> geocodeAddress(
    String address, {
    String? label,
  }) async {
    if (address.trim().isEmpty) {
      return null;
    }
    try {
      final results = await locationFromAddress(address);
      if (results.isEmpty) {
        return null;
      }
      final result = results.first;
      return coordinateFromRaw(
        latitude: result.latitude,
        longitude: result.longitude,
        label: label ?? address,
      );
    } catch (_) {
      return null;
    }
  }

  TrackingMapViewport initialViewportFor(List<TrackingCoordinate> points) {
    if (points.isEmpty) {
      return const TrackingMapViewport(
        center: LatLng(5.6037, -0.1870),
        zoom: 12.5,
      );
    }
    if (points.length == 1) {
      return TrackingMapViewport(center: points.first.latLng, zoom: 14.5);
    }

    return TrackingMapViewport(
      center: centerFor(points),
      zoom: zoomFor(points),
    );
  }

  LatLng centerFor(List<TrackingCoordinate> points) {
    final bounds = _boundsFor(points);
    return LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );
  }

  double zoomFor(List<TrackingCoordinate> points) {
    if (points.length <= 1) {
      return 14.5;
    }

    final bounds = _boundsFor(points);
    final latitudeSpan = (bounds.north - bounds.south).abs();
    final longitudeSpan = (bounds.east - bounds.west).abs();
    final maxSpan = math.max(latitudeSpan, longitudeSpan);

    if (maxSpan <= 0.005) {
      return 15.5;
    }
    if (maxSpan <= 0.01) {
      return 14.8;
    }
    if (maxSpan <= 0.025) {
      return 13.8;
    }
    if (maxSpan <= 0.05) {
      return 12.8;
    }
    if (maxSpan <= 0.1) {
      return 11.8;
    }
    return 10.8;
  }

  _TrackingBounds _boundsFor(List<TrackingCoordinate> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    if (minLat == maxLat) {
      minLat -= 0.01;
      maxLat += 0.01;
    }
    if (minLng == maxLng) {
      minLng -= 0.01;
      maxLng += 0.01;
    }

    return _TrackingBounds(
      south: minLat,
      north: maxLat,
      west: minLng,
      east: maxLng,
    );
  }

  TrackingMapPolyline directPolyline({
    required String id,
    required TrackingCoordinate start,
    required TrackingCoordinate end,
    required int colorValue,
    int width = 5,
  }) {
    return TrackingMapPolyline(
      id: id,
      points: [start.latLng, end.latLng],
      color: Color(colorValue),
      width: width,
    );
  }

  TrackingMapMarker marker({
    required String id,
    required TrackingCoordinate point,
    required String title,
    required String snippet,
    required Color color,
    required IconData icon,
  }) {
    return TrackingMapMarker(
      id: id,
      point: point,
      title: title,
      snippet: snippet,
      color: color,
      icon: icon,
    );
  }

  void fitMapToPoints(MapController controller, List<TrackingCoordinate> points) {
    if (points.isEmpty) {
      return;
    }
    final viewport = initialViewportFor(points);
    controller.move(viewport.center, viewport.zoom);
  }
}

class TrackingCoordinate {
  const TrackingCoordinate({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;

  LatLng get latLng => LatLng(latitude, longitude);

  TrackingCoordinate copyWithLabel(String nextLabel) {
    return TrackingCoordinate(
      latitude: latitude,
      longitude: longitude,
      label: nextLabel,
    );
  }
}

class TrackingMapMarker {
  const TrackingMapMarker({
    required this.id,
    required this.point,
    required this.title,
    required this.snippet,
    required this.color,
    required this.icon,
  });

  final String id;
  final TrackingCoordinate point;
  final String title;
  final String snippet;
  final Color color;
  final IconData icon;
}

class TrackingMapPolyline {
  const TrackingMapPolyline({
    required this.id,
    required this.points,
    required this.color,
    this.width = 5,
  });

  final String id;
  final List<LatLng> points;
  final Color color;
  final int width;
}

class TrackingMapViewport {
  const TrackingMapViewport({
    required this.center,
    required this.zoom,
  });

  final LatLng center;
  final double zoom;
}

class _TrackingBounds {
  const _TrackingBounds({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
  });

  final double south;
  final double north;
  final double west;
  final double east;
}
