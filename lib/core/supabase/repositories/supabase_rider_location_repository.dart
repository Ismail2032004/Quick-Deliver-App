import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/operations/domain/models/rider_location.dart';
import '../../repositories/rider_location_repository.dart';
import '../mappers/supabase_mappers.dart';
import '../supabase_tables.dart';

class SupabaseRiderLocationRepository implements RiderLocationRepository {
  SupabaseRiderLocationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> updateRiderLocation(RiderLocation location) async {
    await _client
        .from(SupabaseTables.riderLocations)
        .upsert(SupabaseMappers.riderLocationToMap(location));
  }

  @override
  Stream<List<RiderLocation>> watchActiveLocations({String? riderId}) {
    return _client
        .from(SupabaseTables.riderLocations)
        .stream(primaryKey: ['rider_id'])
        .order('updated_at')
        .map((rows) {
          final locations = rows
              .map(SupabaseMappers.riderLocationFromMap)
              .where((location) => location.isActive)
              .toList(growable: false);
          if (riderId == null) {
            return locations;
          }
          return locations
              .where((location) => location.riderId == riderId)
              .toList(growable: false);
        });
  }

  @override
  Stream<RiderLocation?> watchLocationForOrder(String orderId) {
    return watchActiveLocations().map((locations) {
      for (final location in locations.reversed) {
        if (location.orderId == orderId) {
          return location;
        }
      }
      return null;
    });
  }
}
