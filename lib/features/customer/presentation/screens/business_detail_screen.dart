import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/phone_service.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/contact_action_bar.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/safe_network_image.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../../domain/models/business.dart';
import '../../domain/models/product.dart';
import '../controllers/customer_providers.dart';
import '../widgets/product_card.dart';

class BusinessDetailScreen extends ConsumerWidget {
  const BusinessDetailScreen({super.key, required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessDetailProvider(businessId));
    final products = ref.watch(businessProductsProvider(businessId));
    final cart = ref.watch(cartControllerProvider);

    if (business == null) {
      return AppShell(
        child: ListView(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton.filledTonal(
                onPressed: () => context.go(AppRoutes.businessList),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(height: 18),
            const EmptyStateView(
              title: 'Business not found',
              message:
                  'This business is unavailable right now. Return to the nearby businesses list and try another store.',
            ),
          ],
        ),
      );
    }

    return AppShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  business.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BusinessHero(
                    business: business,
                    onCallBusiness: () async {
                      final result = await ref
                          .read(phoneServiceProvider)
                          .tryCallNumber(business.phoneNumber);
                      if (!context.mounted || result.success) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.message)),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    title: 'Popular products',
                    subtitle:
                        'Tap any product card to view details and add it straight to your cart.',
                  ),
                  const SizedBox(height: 16),
                  if (products.isEmpty)
                    const EmptyStateView(
                      title: 'No products listed yet',
                      message:
                          'This business has not added products yet. Try another store or update the owner inventory.',
                    )
                  else
                    ...products.map(
                      (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: ProductCard(
                          product: product,
                          onView: () =>
                              _showProductSheet(context, ref, business, product),
                          onAdd: () =>
                              _addProductToCart(context, ref, business, product),
                        ),
                      ),
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: cart.isEmpty
                ? 'Open cart'
                : 'Open cart (${cart.totalQuantity}) - GHS ${cart.total.toStringAsFixed(2)}',
            onPressed: () => context.push(AppRoutes.cart),
            icon: Icons.shopping_cart_checkout_rounded,
          ),
        ],
      ),
    );
  }

  void _showProductSheet(
    BuildContext context,
    WidgetRef ref,
    Business business,
    Product product,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeNetworkImage(
                  imageUrl: product.imageUrl,
                  height: 200,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(24),
                  placeholderLabel: product.category,
                  placeholderIcon: Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 18),
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(product.description),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetaChip(label: product.category),
                    _MetaChip(label: 'GHS ${product.price.toStringAsFixed(2)}'),
                    _MetaChip(label: '${product.preparationMinutes} min prep'),
                  ],
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Add to cart',
                  icon: Icons.add_shopping_cart_rounded,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _addProductToCart(context, ref, business, product);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addProductToCart(
    BuildContext context,
    WidgetRef ref,
    Business business,
    Product product,
  ) async {
    final cartController = ref.read(cartControllerProvider.notifier);
    var replacedCart = false;
    var result = cartController.addProduct(business: business, product: product);

    if (result == AddToCartResult.requiresReplacement) {
      final existingBusiness = ref.read(cartControllerProvider).business;
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new cart?'),
          content: Text(
            'Your cart contains items from ${existingBusiness?.name ?? 'another business'}. Starting a new cart will clear the current cart.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep current cart'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start new cart'),
            ),
          ],
        ),
      );

      if (shouldReplace != true) {
        return;
      }

      result = cartController.addProduct(
        business: business,
        product: product,
        replaceExistingCart: true,
      );
      replacedCart = true;
    }

    if (!context.mounted) {
      return;
    }

    final message = switch (result) {
      AddToCartResult.added => replacedCart
          ? 'Started a new cart for ${business.name}. ${product.name} was added.'
          : '${product.name} added to cart.',
      AddToCartResult.updated =>
        'Updated ${product.name} quantity in your cart.',
      AddToCartResult.requiresReplacement =>
        'Your cart still contains items from another business.',
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BusinessHero extends StatelessWidget {
  const _BusinessHero({
    required this.business,
    required this.onCallBusiness,
  });

  final Business business;
  final VoidCallback onCallBusiness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeNetworkImage(
              imageUrl: business.imageUrl,
              height: 220,
              width: double.infinity,
              borderRadius: BorderRadius.circular(24),
              placeholderLabel: business.category,
              placeholderIcon: Icons.storefront_rounded,
            ),
            const SizedBox(height: 18),
            Text(
              business.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              business.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              business.address,
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                  ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetaChip(label: business.category),
                _MetaChip(label: '${business.rating.toStringAsFixed(1)} rating'),
                _MetaChip(
                  label: '${business.estimatedDeliveryMinutes} min delivery',
                ),
              ],
            ),
            const SizedBox(height: 16),
            ContactActionBar(onCallBusiness: onCallBusiness),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}
