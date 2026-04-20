import 'package:flutter/material.dart';

import '../../../../shared/widgets/safe_network_image.dart';
import '../../domain/models/business.dart';

class BusinessListTile extends StatelessWidget {
  const BusinessListTile({
    super.key,
    required this.business,
    required this.distanceKm,
    required this.onTap,
  });

  final Business business;
  final double distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeNetworkImage(
                imageUrl: business.imageUrl,
                width: 92,
                height: 92,
                borderRadius: BorderRadius.circular(22),
                placeholderLabel: business.category,
                placeholderIcon: Icons.storefront_rounded,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            business.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${business.estimatedDeliveryMinutes} min',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: const Color(0xFFC2410C),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      business.category,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      business.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChipLabel(
                          label: '${distanceKm.toStringAsFixed(1)} km away',
                        ),
                        _ChipLabel(
                          label: '${business.rating.toStringAsFixed(1)} rating',
                        ),
                        for (final tag in business.tags.take(1))
                          _ChipLabel(label: tag),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
