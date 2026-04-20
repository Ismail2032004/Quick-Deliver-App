import '../../features/customer/domain/models/product.dart';

abstract class ProductRepository {
  Stream<List<Product>> watchProducts();
  Future<List<Product>> getProductsByBusiness(String businessId);
  Stream<List<Product>> watchProductsByBusiness(String businessId);
  Future<void> saveProduct(Product product);
  Future<void> deleteProduct(String productId);
}
