import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/models/app_role.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/order_destination_source_codec.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../dashboard/presentation/controllers/dashboard_tab_controller.dart';
import '../../../operations/presentation/controllers/delivery_hub_controller.dart';
import '../controllers/customer_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const _savedAddressKey = 'quickdeliver.saved_delivery_address';

  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();
  bool _placingOrder = false;
  bool _saveAsDefault = true;
  OrderDestinationSource _destinationSource = OrderDestinationSource.manual;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadSavedAddress);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_savedAddressKey);
    if (!mounted) {
      return;
    }
    _addressController.text = saved?.trim().isNotEmpty == true
        ? saved!
        : 'Hostel Block C, East Legon';
  }

  Future<void> _useCurrentLocation() async {
    await ref.read(customerLocationProvider.notifier).refreshLocation();
    final location = ref.read(customerLocationProvider);
    if (!location.hasLiveLocation || !location.canUseAsDeliveryDestination) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            location.errorMessage ??
                'Your current location is unavailable right now. You can still type a delivery address manually.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _destinationSource = OrderDestinationSource.currentLocation;
      _addressController.text = location.fullAddress;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final user = ref.watch(customerCurrentUserProvider);
    final location = ref.watch(customerLocationProvider);

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
                  title: 'Checkout',
                  subtitle:
                      'Choose a destination, confirm delivery details, and place your order.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cart.business?.name ?? 'Selected business',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${cart.totalQuantity} items - GHS ${cart.total.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'Your delivery destination is captured as an order snapshot at checkout. Change it here before placing the order.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delivery destination',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                ChoiceChip(
                                  label: const Text('Type address'),
                                  selected: _destinationSource ==
                                      OrderDestinationSource.manual,
                                  onSelected: (_) {
                                    setState(() {
                                      _destinationSource =
                                          OrderDestinationSource.manual;
                                    });
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Use current location'),
                                  selected: _destinationSource ==
                                      OrderDestinationSource.currentLocation,
                                  onSelected: (_) => _useCurrentLocation(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _destinationSource.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _destinationSource ==
                                            OrderDestinationSource.currentLocation
                                        ? location.fullAddress
                                        : 'Enter the exact address the rider should deliver to.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: const Color(0xFF475569),
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.tonalIcon(
                                          onPressed: _useCurrentLocation,
                                          icon: location.isLoading
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.my_location_rounded,
                                                ),
                                          label: const Text(
                                            'Refresh current location',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (location.errorMessage != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      location.errorMessage!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF92400E),
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _addressController,
                              label: 'Delivery address',
                              prefixIcon: Icons.location_on_outlined,
                              enabled: _destinationSource ==
                                  OrderDestinationSource.manual,
                              validator: (value) {
                                if (value == null || value.trim().length < 5) {
                                  return 'Enter a delivery address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _destinationSource ==
                                      OrderDestinationSource.currentLocation
                                  ? 'QuickDeliver is using your current device location snapshot for this order.'
                                  : 'Typed addresses are fixed to the order once you place it.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _noteController,
                              label: 'Delivery note',
                              hint: 'Optional instructions for the rider',
                              prefixIcon: Icons.note_alt_outlined,
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Ordering as ${user?.name ?? 'Customer'}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: const Color(0xFF64748B)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _saveAsDefault,
                              onChanged: (value) {
                                setState(() {
                                  _saveAsDefault = value;
                                });
                              },
                              title:
                                  const Text('Save as default delivery address'),
                              subtitle: const Text(
                                'This address will prefill the next time you check out on this device.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Place order',
            icon: Icons.check_circle_outline_rounded,
            isLoading: _placingOrder,
            onPressed: cart.isEmpty
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _placingOrder = true);
                    await Future<void>.delayed(const Duration(milliseconds: 500));

                    final currentUser = user;
                    final snapshotAddress = _addressController.text.trim();
                    try {
                      if (_saveAsDefault) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(_savedAddressKey, snapshotAddress);
                      }
                      final order = await ref
                          .read(deliveryHubProvider.notifier)
                          .createOrder(
                            business: cart.business!,
                            customer:
                                currentUser ??
                                const AppUser(
                                  id: 'demo-customer',
                                  name: 'QuickDeliver Customer',
                                  email: 'customer@quickdeliver.demo',
                                  role: AppRole.customer,
                                  phoneNumber: '+233200000000',
                                ),
                            deliveryAddress: snapshotAddress,
                            destinationSource: _destinationSource,
                            destinationLatitude:
                                _destinationSource ==
                                        OrderDestinationSource.currentLocation
                                    ? location.latitude
                                    : null,
                            destinationLongitude:
                                _destinationSource ==
                                        OrderDestinationSource.currentLocation
                                    ? location.longitude
                                    : null,
                            cartItems: cart.items,
                            note: _noteController.text.trim().isEmpty
                                ? null
                                : _noteController.text.trim(),
                          );

                      ref.read(cartControllerProvider.notifier).clear();
                      ref
                              .read(
                                dashboardTabProvider(
                                  'customer-dashboard',
                                ).notifier,
                              )
                              .state =
                          1;
                      await ref
                          .read(notificationServiceProvider)
                          .showOrderUpdate(
                            title: 'Order placed',
                            body: '${order.id} was created successfully.',
                            orderId: order.id,
                          );

                      if (!mounted) return;
                      setState(() => _placingOrder = false);

                      await showDialog<void>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Order created'),
                            content: Text(
                              '${order.id} has been placed successfully and added to your live order history.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Continue'),
                              ),
                            ],
                          );
                        },
                      );

                      if (!mounted) return;
                      context.go(AppRoutes.customerDashboard);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order ${order.id} placed successfully.'),
                        ),
                      );
                    } catch (error) {
                      if (!mounted) {
                        return;
                      }
                      setState(() => _placingOrder = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}
