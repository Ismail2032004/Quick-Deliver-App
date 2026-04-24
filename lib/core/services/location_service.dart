import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

class DemoCoordinate {
  const DemoCoordinate({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.isFallback = false,
    this.errorMessage,
  });

  final double latitude;
  final double longitude;
  final String label;
  final bool isFallback;
  final String? errorMessage;
}

class CustomerLocationSnapshot {
  const CustomerLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.fullAddress,
    this.isFallback = false,
    this.errorMessage,
  });

  final double latitude;
  final double longitude;
  final String label;
  final String fullAddress;
  final bool isFallback;
  final String? errorMessage;
}

class LiveLocationUpdate {
  const LiveLocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationService {
  const LocationService();

  static const _fallbackLatitude = 5.6037;
  static const _fallbackLongitude = -0.1870;
  static const _fallbackLabel = 'Accra fallback area';
  static const _fallbackAddress = 'Central Accra, Greater Accra';

  Future<DemoCoordinate> getCurrentOrMockLocation() async {
    try {
      final current = await getCurrentLiveLocation();
      return DemoCoordinate(
        latitude: current.latitude,
        longitude: current.longitude,
        label: 'Live device location',
      );
    } catch (error) {
      return DemoCoordinate(
        latitude: _fallbackLatitude,
        longitude: _fallbackLongitude,
        label: 'Mock location fallback',
        isFallback: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<CustomerLocationSnapshot> getCurrentCustomerLocation() async {
    try {
      await ensureCustomerLocationPermission();
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final fullAddress = await reverseGeocodeAddress(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      return CustomerLocationSnapshot(
        latitude: position.latitude,
        longitude: position.longitude,
        label: _shortLabelFromAddress(fullAddress),
        fullAddress: fullAddress,
      );
    } catch (error) {
      return CustomerLocationSnapshot(
        latitude: _fallbackLatitude,
        longitude: _fallbackLongitude,
        label: _fallbackLabel,
        fullAddress: _fallbackAddress,
        isFallback: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<LiveLocationUpdate> getCurrentLiveLocation() async {
    await ensureLiveTrackingPermission();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
    return LiveLocationUpdate(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
    );
  }

  Stream<LiveLocationUpdate> liveLocationStream({
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
    int distanceFilter = 20,
  }) async* {
    await ensureLiveTrackingPermission();
    yield* Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).map(
      (position) => LiveLocationUpdate(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
      ),
    );
  }

  Future<LocationPermission> ensureLiveTrackingPermission() async {
    return _ensureLocationPermission(
      servicesDisabledMessage:
          'Location services are turned off. Enable GPS/location services to share live rider updates.',
      deniedMessage:
          'Location permission was denied, so live rider tracking cannot start.',
      deniedForeverMessage:
          'Location permission is permanently denied. Re-enable it from system settings before using live rider tracking.',
    );
  }

  Future<void> ensureCustomerLocationPermission() async {
    await _ensureLocationPermission(
      servicesDisabledMessage:
          'Location services are turned off. Enable GPS/location services to use your current delivery area.',
      deniedMessage:
          'Location permission was denied, so QuickDeliver cannot read your current location yet.',
      deniedForeverMessage:
          'Location permission is permanently denied. Re-enable it from system settings to use your current location.',
    );
  }

  Future<String> reverseGeocodeAddress({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
      }
      final placemark = placemarks.first;
      final parts = [
        placemark.name,
        placemark.street,
        placemark.thoroughfare,
        placemark.subThoroughfare,
        placemark.subLocality,
        placemark.locality,
        placemark.subAdministrativeArea,
        placemark.administrativeArea,
        placemark.country,
      ]
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty && !_looksLikeCoordinates(item))
          .toList(growable: false);
      final dedupedParts = <String>[];
      for (final part in parts) {
        if (!dedupedParts.any(
          (existing) => existing.toLowerCase() == part.toLowerCase(),
        )) {
          dedupedParts.add(part);
        }
      }
      if (dedupedParts.isEmpty) {
        return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
      }
      return dedupedParts.join(', ');
    } catch (_) {
      return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    }
  }

  Future<LocationPermission> _ensureLocationPermission({
    required String servicesDisabledMessage,
    required String deniedMessage,
    required String deniedForeverMessage,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException(servicesDisabledMessage);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw LocationServiceException(deniedMessage);
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(deniedForeverMessage);
    }

    return permission;
  }

  Future<String?> riderBackgroundTrackingGuidance() async {
    final permission = await Geolocator.checkPermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Turn on device location services so QuickDeliver can keep sharing rider updates.';
    }
    return switch (permission) {
      LocationPermission.denied => 'Allow location permission to start live rider tracking.',
      LocationPermission.deniedForever =>
        'Location permission is blocked in system settings. Re-enable it before using live rider tracking.',
      LocationPermission.whileInUse =>
        'For stronger Android background tracking, allow location access all the time in system settings.',
      LocationPermission.always => null,
      LocationPermission.unableToDetermine =>
        'Location permission could not be confirmed yet. Review system settings if tracking does not update reliably.',
    };
  }

  String _shortLabelFromAddress(String address) {
    final pieces = address
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (pieces.length >= 2) {
      return '${pieces[0]}, ${pieces[1]}';
    }
    if (pieces.isNotEmpty) {
      return pieces.first;
    }
    return 'Current device location';
  }

  bool _looksLikeCoordinates(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(normalized);
  }
}
