import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/services/phone_service.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../settings/presentation/controllers/app_settings_controller.dart';
import '../controllers/account_preferences_controller.dart';

class AccountHubScreen extends ConsumerWidget {
  const AccountHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.currentUser;
    if (user == null) {
      return AppShell(
        child: Center(
          child: Text(
            'Sign in to manage your account.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }
    final account = ref.watch(accountPreferencesProvider(user.id));
    final settings = ref.watch(appSettingsControllerProvider);

    return AppShell(
      child: ListView(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SectionHeader(
                  title: 'Account',
                  subtitle:
                      'Manage profile access, preferences, addresses, payments, and support for your ${user.role.label.toLowerCase()} workspace.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF0F766E)
                          .withValues(alpha: 0.14),
                      backgroundImage:
                          user.avatarUrl?.trim().isNotEmpty == true
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl?.trim().isNotEmpty == true
                          ? null
                          : Text(
                              _initials(user.name),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF0F766E),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                    ),
                    title: Text(user.name),
                    subtitle: Text(
                      '${user.email}\n${user.phoneNumber?.trim().isNotEmpty == true ? user.phoneNumber! : 'Add a phone number in your profile.'}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: user.approvedRoles
                        .map(
                          (role) => Chip(
                            avatar: Icon(_iconForRole(role), size: 18),
                            label: Text('${role.label} access'),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                  label: 'Open profile details',
                  icon: Icons.person_outline_rounded,
                  onPressed: () => context.push(AppRoutes.profile),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Open settings',
                  variant: ButtonVariant.tonal,
                  icon: Icons.settings_outlined,
                  onPressed: () => context.push(AppRoutes.settings),
                ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (user.role == AppRole.customer) ...[
            _CustomerSavedAddressesCard(userId: user.id, account: account),
            const SizedBox(height: 16),
            _CustomerPaymentMethodsCard(userId: user.id, account: account),
            const SizedBox(height: 16),
          ],
          if (user.role == AppRole.owner) ...[
            _RoleSupportCard(
              title: 'Business owner support',
              body:
                  'Storefront verification, support contact, and workspace settings are handled here while your public business profile stays on the business dashboard.',
              primaryLabel: 'Call support',
              onPrimary: () => _callSupport(context, ref),
            ),
            const SizedBox(height: 16),
          ],
          if (user.role == AppRole.rider) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Rider summary',
                      subtitle:
                          'A lightweight earnings snapshot keeps the rider workspace feeling closer to a real courier app.',
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: const [
                        _SummaryChip(
                          label: 'This week',
                          value: 'GHS 248.00',
                        ),
                        _SummaryChip(
                          label: 'Completed',
                          value: '12 trips',
                        ),
                        _SummaryChip(
                          label: 'Avg per trip',
                          value: 'GHS 20.60',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _RoleSupportCard(
              title: 'Rider support',
              body:
                  'Need help with a live delivery, safety issue, or account review? Contact support directly from your rider account center.',
              primaryLabel: 'Call support',
              onPrimary: () => _callSupport(context, ref),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Active preferences',
                    subtitle:
                        'A quick summary of the settings currently active on this device.',
                  ),
                  const SizedBox(height: 14),
                  _PreferenceLine(
                    label: 'Theme',
                    value: settings.darkModeEnabled ? 'Dark' : 'Light',
                  ),
                  _PreferenceLine(
                    label: 'Readable text',
                    value: settings.largerTextEnabled ? 'On' : 'Off',
                  ),
                  _PreferenceLine(
                    label: 'Reduced motion',
                    value: settings.reducedMotionEnabled ? 'On' : 'Off',
                  ),
                  _PreferenceLine(
                    label: 'High contrast',
                    value: settings.highContrastEnabled ? 'On' : 'Off',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _callSupport(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(phoneServiceProvider)
        .tryCallNumber(AppConstants.supportPhone);
    if (!context.mounted || result.success) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  String _initials(String name) {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'QD';
    }
    if (parts.length < 2) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  IconData _iconForRole(AppRole role) {
    return switch (role) {
      AppRole.customer => Icons.shopping_bag_outlined,
      AppRole.owner => Icons.storefront_rounded,
      AppRole.rider => Icons.two_wheeler_rounded,
    };
  }
}

class _CustomerSavedAddressesCard extends ConsumerWidget {
  const _CustomerSavedAddressesCard({
    required this.userId,
    required this.account,
  });

  final String userId;
  final AccountPreferencesState account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Saved addresses',
              subtitle:
                  'Keep frequently used drop-off locations ready for checkout.',
            ),
            const SizedBox(height: 14),
            ...account.savedAddresses.map(
              (address) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(address.label),
                subtitle: Text(address.address),
                trailing: IconButton(
                  onPressed: () => ref
                      .read(accountPreferencesProvider(userId).notifier)
                      .removeSavedAddress(address),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showAddAddressDialog(context, ref, userId),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add saved address'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddAddressDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final labelController = TextEditingController();
    final addressController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add saved address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (labelController.text.trim().isEmpty ||
                    addressController.text.trim().isEmpty) {
                  return;
                }
                await ref
                    .read(accountPreferencesProvider(userId).notifier)
                    .addSavedAddress(
                      SavedAddress(
                        label: labelController.text.trim(),
                        address: addressController.text.trim(),
                      ),
                    );
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _CustomerPaymentMethodsCard extends ConsumerWidget {
  const _CustomerPaymentMethodsCard({
    required this.userId,
    required this.account,
  });

  final String userId;
  final AccountPreferencesState account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Payment methods',
              subtitle:
                  'Store ready-to-use payment method placeholders until a live processor is connected.',
            ),
            const SizedBox(height: 14),
            ...account.paymentMethods.map(
              (method) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.credit_card_outlined),
                title: Text(method.label),
                subtitle: Text(method.details),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (method.isDefault) const Chip(label: Text('Default')),
                    IconButton(
                      onPressed: () => ref
                          .read(accountPreferencesProvider(userId).notifier)
                          .removePaymentMethod(method),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showAddMethodDialog(context, ref, userId),
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Add payment method'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMethodDialog(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final labelController = TextEditingController(text: 'Mobile money');
    final detailsController = TextEditingController();
    var isDefault = false;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add payment method'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Method'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    decoration: const InputDecoration(
                      labelText: 'Reference details',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: isDefault,
                    onChanged: (value) => setState(() => isDefault = value),
                    title: const Text('Set as default'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (labelController.text.trim().isEmpty ||
                        detailsController.text.trim().isEmpty) {
                      return;
                    }
                    await ref
                        .read(accountPreferencesProvider(userId).notifier)
                        .addPaymentMethod(
                          PaymentMethodSnapshot(
                            label: labelController.text.trim(),
                            details: detailsController.text.trim(),
                            isDefault: isDefault,
                          ),
                        );
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RoleSupportCard extends StatelessWidget {
  const _RoleSupportCard({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: title, subtitle: body),
            const SizedBox(height: 14),
            PrimaryButton(
              label: primaryLabel,
              icon: Icons.support_agent_rounded,
              onPressed: onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceLine extends StatelessWidget {
  const _PreferenceLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
