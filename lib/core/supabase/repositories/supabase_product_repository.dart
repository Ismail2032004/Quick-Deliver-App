import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/customer/domain/models/product.dart';
import '../../repositories/product_repository.dart';
import '../mappers/supabase_mappers.dart';
import '../supabase_tables.dart';

class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<Product>> watchProducts() {
    return _client
        .from(SupabaseTables.products)
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map(
          (rows) => rows
              .map(SupabaseMappers.productFromMap)
              .toList(growable: false),
        );
  }

  @override
  Future<List<Product>> getProductsByBusiness(String businessId) async {
    final response = await _client
        .from(SupabaseTables.products)
        .select()
        .eq('business_id', businessId)
        .order('created_at');
    return response
        .map<Product>(SupabaseMappers.productFromMap)
        .toList(growable: false);
  }

  @override
  Stream<List<Product>> watchProductsByBusiness(String businessId) {
    return watchProducts().map(
      (products) => products
          .where((product) => product.businessId == businessId)
          .toList(growable: false),
    );
  }

  @override
  Future<void> saveProduct(Product product) async {
    await _client
        .from(SupabaseTables.products)
        .upsert(SupabaseMappers.productToMap(product));
  }

  @override
  Future<void> deleteProduct(String productId) async {
    await _client.from(SupabaseTables.products).delete().eq('id', productId);
  }
}
