import '../../features/customer/domain/models/business.dart';

abstract class BusinessRepository {
  Future<List<Business>> getBusinesses();
  Future<Business?> getBusinessById(String businessId);
  Future<Business?> getBusinessByOwner(String ownerId);
  Stream<List<Business>> watchBusinesses({String? ownerId});
  Future<void> saveBusiness(Business business);
}
