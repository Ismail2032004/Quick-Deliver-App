import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../controllers/customer_providers.dart';
import '../widgets/cart_item_tile.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);

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
              const Expanded(
                child: SectionHeader(
                  title: 'Your cart',
                  subtitle:
                      'Review items, adjust quantities, and continue to checkout.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: cart.isEmpty
                ? EmptyStateView(
                    title: 'Your cart is ready for its first item',
                    message:
                        'Add a few products from a nearby business to continue with checkout.',
                    actionLabel: 'Browse businesses',
                    onAction: () => context.go(AppRoutes.businessList),
                  )
                : ListView(
                    children: [
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE6FFFB),
                            child: Icon(
                              Icons.storefront_rounded,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          title: Text(cart.business?.name ?? 'Business'),
                          subtitle: Text(
                            '${cart.totalQuantity} items in this order',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFFFFF7ED),
                        child: const ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(0xFFFFEDD5),
                            child: Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFC2410C),
                            ),
                          ),
                          title: Text('Single-business cart'),
                          subtitle: Text(
                            'QuickDeliver keeps one business per cart. Starting a new cart from another business will ask for confirmation before clearing these items.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...cart.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CartItemTile(
                            item: item,
                            onIncrease: () {
                              ref
                                  .read(cartControllerProvider.notifier)
                                  .increaseQuantity(item.productId);
                            },
                            onDecrease: () {
                              ref
                                  .read(cartControllerProvider.notifier)
                                  .decreaseQuantity(item.productId);
                            },
                            onRemove: () {
                              ref
                                  .read(cartControllerProvider.notifier)
                                  .removeItem(item.productId);
                            },
                          ),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              _SummaryRow(
                                label: 'Subtotal',
                                value: cart.subtotal,
                              ),
                              const SizedBox(height: 10),
                              _SummaryRow(
                                label: 'Delivery fee',
                                value: cart.deliveryFee,
                              ),
                              const Divider(height: 26),
                              _SummaryRow(
                                label: 'Total',
                                value: cart.total,
                                emphasize: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (!cart.isEmpty) ...[
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Continue to checkout',
              icon: Icons.lock_rounded,
              onPressed: () => context.push(AppRoutes.checkout),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text('GHS ${value.toStringAsFixed(2)}', style: style),
      ],
    );
  }
}
