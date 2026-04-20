import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/customer/domain/models/business.dart';
import '../../repositories/business_repository.dart';
import '../mappers/supabase_mappers.dart';
import '../supabase_tables.dart';

class SupabaseBusinessRepository implements BusinessRepository {
  SupabaseBusinessRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Business>> getBusinesses() async {
    final response = await _client
        .from(SupabaseTables.businesses)
        .select()
        .order('created_at');
    return response
        .map<Business>(SupabaseMappers.businessFromMap)
        .toList(growable: false);
  }

  @override
  Future<Business?> getBusinessById(String businessId) async {
    final response = await _client
        .from(SupabaseTables.businesses)
        .select()
        .eq('id', businessId)
        .maybeSingle();
    if (response == null) {
      return null;
    }
    return SupabaseMappers.businessFromMap(response);
  }

  @override
  Future<Business?> getBusinessByOwner(String ownerId) async {
    final response = await _client
        .from(SupabaseTables.businesses)
        .select()
        .eq('owner_id', ownerId)
        .limit(1)
        .maybeSingle();
    if (response == null) {
      return null;
    }
    return SupabaseMappers.businessFromMap(response);
  }

  @override
  Stream<List<Business>> watchBusinesses({String? ownerId}) {
    return _client
        .from(SupabaseTables.businesses)
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) {
          final businesses = rows
              .map(SupabaseMappers.businessFromMap)
              .toList(growable: false);
          if (ownerId == null) {
            return businesses;
          }
          return businesses
              .where((business) => business.ownerId == ownerId)
              .toList(growable: false);
        });
  }

  @override
  Future<void> saveBusiness(Business business) async {
    await _client
        .from(SupabaseTables.businesses)
        .upsert(SupabaseMappers.businessToMap(business));
  }
}
