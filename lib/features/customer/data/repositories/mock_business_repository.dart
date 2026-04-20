import '../../domain/models/business.dart';
import '../../domain/models/product.dart';
import '../mock/mock_customer_seed_data.dart';

class MockBusinessRepository {
  List<Business> getNearbyBusinesses({
    required double userLatitude,
    required double userLongitude,
  }) {
    final businesses = [...MockCustomerSeedData.businesses];
    businesses.sort((a, b) {
      final aDistance = _distance(
        userLatitude,
        userLongitude,
        a.latitude,
        a.longitude,
      );
      final bDistance = _distance(
        userLatitude,
        userLongitude,
        b.latitude,
        b.longitude,
      );
      return aDistance.compareTo(bDistance);
    });
    return businesses;
  }

  Business? getBusinessById(String businessId) {
    for (final business in MockCustomerSeedData.businesses) {
      if (business.id == businessId) {
        return business;
      }
    }
    return null;
  }

  List<Product> getProductsForBusiness(String businessId) {
    return MockCustomerSeedData.products
        .where((product) => product.businessId == businessId)
        .toList(growable: false);
  }

  double distanceInKm({
    required double fromLatitude,
    required double fromLongitude,
    required Business business,
  }) {
    return _distance(
      fromLatitude,
      fromLongitude,
      business.latitude,
      business.longitude,
    );
  }

  double _distance(double lat1, double lon1, double lat2, double lon2) {
    final dx = lat1 - lat2;
    final dy = lon1 - lon2;
    return (dx * dx + dy * dy) * 111;
  }
}
