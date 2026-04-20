import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/app_role.dart';
import '../../../../core/models/role_application.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_session_coordinator.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.currentUser;
    final approvedRoles = auth.approvedRoles;
    final isPostLoginChooser = auth.shouldShowWorkspaceChooser;
    final firstName = user?.name.trim().split(' ').first ?? 'there';

    return AppShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          SectionHeader(
            title: 'Choose workspace',
            subtitle: user == null
                ? 'Sign in to view your available QuickDeliver workspaces.'
                : isPostLoginChooser
                ? 'Welcome back, $firstName. Choose the QuickDeliver workspace you want to enter now.'
                : approvedRoles.length > 1
                ? 'Choose from the workspaces already approved for your account.'
                : 'This account currently has ${approvedRoles.first.label.toLowerCase()} access. Additional roles require review before they appear here.',
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                const _SectionLabel('Continue as'),
                const SizedBox(height: 12),
                ...approvedRoles.map(
                  (role) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _RoleCard(
                      role: role,
                      status: RoleApplicationStatus.approved,
                      actionLabel: 'Continue as ${role.label}',
                      enabled: true,
                      isCurrent: user?.role == role,
                      onSelect: () async {
                              try {
                                if (user?.role != role) {
                                  await ref
                                      .read(authControllerProvider)
                                      .selectRole(role);
                                }
                              } catch (error) {
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                                return;
                              }
                              if (!context.mounted) {
                                return;
                              }
                              ref
                                  .read(authControllerProvider)
                                  .markWorkspaceChooserSeen();
                              context.go(AuthController.routeForRole(role));
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _SectionLabel('Role applications'),
                const SizedBox(height: 12),
                if (!approvedRoles.contains(AppRole.owner))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _RoleCard(
                      role: AppRole.owner,
                      status: user?.ownerApplicationStatus ??
                          RoleApplicationStatus.notApplied,
                      actionLabel:
                          _applicationActionLabel(user?.ownerApplicationStatus),
                      enabled: (user?.ownerApplicationStatus ??
                              RoleApplicationStatus.notApplied) !=
                          RoleApplicationStatus.pending &&
                          (user?.ownerApplicationStatus ??
                                  RoleApplicationStatus.notApplied) !=
                              RoleApplicationStatus.suspended,
                      onSelect: () => _showApplicationSheet(
                        context,
                        ref,
                        role: AppRole.owner,
                      ),
                    ),
                  ),
                if (!approvedRoles.contains(AppRole.rider))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _RoleCard(
                      role: AppRole.rider,
                      status: user?.riderApplicationStatus ??
                          RoleApplicationStatus.notApplied,
                      actionLabel:
                          _applicationActionLabel(user?.riderApplicationStatus),
                      enabled: (user?.riderApplicationStatus ??
                              RoleApplicationStatus.notApplied) !=
                          RoleApplicationStatus.pending &&
                          (user?.riderApplicationStatus ??
                                  RoleApplicationStatus.notApplied) !=
                              RoleApplicationStatus.suspended,
                      onSelect: () => _showApplicationSheet(
                        context,
                        ref,
                        role: AppRole.rider,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isPostLoginChooser)
            PrimaryButton(
              label: 'Not you? Log out',
              variant: ButtonVariant.outlined,
              onPressed: () async {
                await ref
                    .read(authSessionCoordinatorProvider)
                    .confirmAndSignOut(context);
              },
            )
          else
            PrimaryButton(
              label: 'Back to account',
              variant: ButtonVariant.outlined,
              onPressed: () => context.pop(),
            ),
        ],
      ),
    );
  }

  static String _applicationActionLabel(RoleApplicationStatus? status) {
    return switch (status ?? RoleApplicationStatus.notApplied) {
      RoleApplicationStatus.notApplied => 'Start application',
      RoleApplicationStatus.pending => 'Pending review',
      RoleApplicationStatus.rejected => 'Update application',
      RoleApplicationStatus.suspended => 'Access suspended',
      RoleApplicationStatus.approved => 'Approved',
    };
  }

  static Future<void> _showApplicationSheet(
    BuildContext context,
    WidgetRef ref, {
    required AppRole role,
  }) async {
    final nameA = role == AppRole.owner ? 'Business name' : 'Vehicle type';
    final nameB = role == AppRole.owner ? 'Business category' : 'Service region';
    final nameC = role == AppRole.owner ? 'Store phone' : 'Emergency contact';
    final nameD = role == AppRole.owner ? 'Business address' : 'Phone number';
    final nameE =
        role == AppRole.owner ? 'Store description' : 'License / ID note';

    final aController = TextEditingController();
    final bController = TextEditingController();
    final cController = TextEditingController();
    final dController = TextEditingController();
    final eController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              SectionHeader(
                title: '${role.label} application',
                subtitle: role == AppRole.owner
                    ? 'Submit your storefront details for approval before business tools are unlocked.'
                    : 'Submit your rider details for approval before dispatch tools are unlocked.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: aController,
                decoration: InputDecoration(labelText: nameA),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bController,
                decoration: InputDecoration(labelText: nameB),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cController,
                decoration: InputDecoration(labelText: nameC),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dController,
                decoration: InputDecoration(labelText: nameD),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: eController,
                decoration: InputDecoration(
                  labelText: nameE,
                  helperText:
                      'Use this field as a placeholder for uploaded documents or additional verification notes.',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Submit for review',
                icon: Icons.verified_user_outlined,
                onPressed: () async {
                  if ([aController, bController, cController, dController]
                      .any((controller) => controller.text.trim().isEmpty)) {
                    return;
                  }
                  await ref.read(authControllerProvider).submitRoleApplication(
                    role: role,
                    formData: {
                      'field_a': aController.text.trim(),
                      'field_b': bController.text.trim(),
                      'field_c': cController.text.trim(),
                      'field_d': dController.text.trim(),
                      'field_e': eController.text.trim(),
                    },
                  );
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${role.label} application submitted for review.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.status,
    required this.actionLabel,
    required this.enabled,
    this.isCurrent = false,
    this.onSelect,
  });

  final AppRole role;
  final RoleApplicationStatus status;
  final String actionLabel;
  final bool enabled;
  final bool isCurrent;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = switch (role) {
      AppRole.customer => const Color(0xFF0F766E),
      AppRole.rider => const Color(0xFFF97316),
      AppRole.owner => const Color(0xFF2563EB),
    };
    final icon = switch (role) {
      AppRole.customer => Icons.person_outline_rounded,
      AppRole.rider => Icons.two_wheeler_rounded,
      AppRole.owner => Icons.storefront_rounded,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    role.label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isCurrent && status == RoleApplicationStatus.approved)
                  const Chip(label: Text('Current'))
                else
                  Chip(label: Text(status.label)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              status == RoleApplicationStatus.approved
                  ? role.description
                  : status.helperCopy(role),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: actionLabel,
              onPressed: enabled ? onSelect : null,
            ),
          ],
        ),
      ),
    );
  }
}
