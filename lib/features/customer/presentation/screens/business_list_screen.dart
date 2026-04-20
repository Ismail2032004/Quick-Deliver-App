import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../controllers/customer_providers.dart';
import '../widgets/business_list_tile.dart';

class BusinessListScreen extends ConsumerStatefulWidget {
  const BusinessListScreen({super.key});

  @override
  ConsumerState<BusinessListScreen> createState() => _BusinessListScreenState();
}

class _BusinessListScreenState extends ConsumerState<BusinessListScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(customerLocationProvider.notifier).refreshLocation(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businesses = ref.watch(nearbyBusinessesProvider);
    final location = ref.watch(customerLocationProvider);

    return AppShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => context.go(AppRoutes.customerDashboard),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: SectionHeader(
                  title: 'Nearby businesses',
                  subtitle:
                      'Explore restaurants, pharmacies, and local stores near your current delivery area.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE0F2FE),
                        child: Icon(
                          Icons.my_location_rounded,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current location'),
                            const SizedBox(height: 4),
                            Text(
                              location.fullAddress,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFF475569),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => ref
                            .read(customerLocationProvider.notifier)
                            .refreshLocation(),
                        icon: location.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      location.hasLiveLocation
                          ? 'Using your device location to rank nearby businesses and estimate distance.'
                          : location.errorMessage ??
                              'Location permission is unavailable, so QuickDeliver is using a fallback area. You can still browse stores and type your address at checkout.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: location.hasLiveLocation
                            ? const Color(0xFF0F766E)
                            : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: businesses.isEmpty
                ? const EmptyStateView(
                    title: 'No nearby businesses yet',
                    message:
                        'Try again later or add more businesses in your backend.',
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: businesses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final business = businesses[index];
                      final distanceKm = distanceInKm(
                        fromLatitude: location.latitude,
                        fromLongitude: location.longitude,
                        toLatitude: business.latitude,
                        toLongitude: business.longitude,
                      );
                      return BusinessListTile(
                        business: business,
                        distanceKm: distanceKm,
                        onTap: () => context.push(
                          '${AppRoutes.businessList}/${business.id}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
