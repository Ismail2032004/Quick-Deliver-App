import '../../features/operations/domain/models/rider_location.dart';

abstract class RiderLocationRepository {
  Future<void> updateRiderLocation(RiderLocation location);
  Stream<List<RiderLocation>> watchActiveLocations({String? riderId});
  Stream<RiderLocation?> watchLocationForOrder(String orderId);
}
