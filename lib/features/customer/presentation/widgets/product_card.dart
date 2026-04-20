import 'package:flutter/material.dart';

import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/safe_network_image.dart';
import '../../domain/models/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onView,
    required this.onAdd,
  });

  final Product product;
  final VoidCallback onView;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeNetworkImage(
                imageUrl: product.imageUrl,
                height: 150,
                width: double.infinity,
                borderRadius: BorderRadius.circular(22),
                placeholderLabel: product.category,
                placeholderIcon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 14),
              Text(
                product.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                product.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'GHS ${product.price.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${product.preparationMinutes} min',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Details',
                      variant: ButtonVariant.outlined,
                      onPressed: onView,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Add',
                      icon: Icons.add_shopping_cart_rounded,
                      onPressed: onAdd,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
