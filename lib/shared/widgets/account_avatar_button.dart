import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_user.dart';
import '../../core/router/app_router.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/controllers/auth_session_coordinator.dart';

class AccountAvatarButton extends ConsumerWidget {
  const AccountAvatarButton({
    super.key,
    required this.fallbackIcon,
    required this.fallbackColor,
  });

  final IconData fallbackIcon;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).currentUser;
    final avatarUrl = user?.avatarUrl?.trim();
    final initials = _initialsFor(user);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _showAccountMenu(context, ref, user),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: fallbackColor.withValues(alpha: 0.14),
        backgroundImage: avatarUrl?.isNotEmpty == true
            ? NetworkImage(avatarUrl!)
            : null,
        child: avatarUrl?.isNotEmpty == true
            ? null
            : Text(
                initials,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fallbackColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  Future<void> _showAccountMenu(
    BuildContext context,
    WidgetRef ref,
    AppUser? user,
  ) async {
    final parentContext = context;
    final avatarUrl = user?.avatarUrl?.trim();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: fallbackColor.withValues(alpha: 0.14),
                    backgroundImage: avatarUrl?.isNotEmpty == true
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: avatarUrl?.isNotEmpty == true
                        ? null
                        : Text(
                            _initialsFor(user),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: fallbackColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                  ),
                  title: Text(user?.name ?? 'QuickDeliver account'),
                  subtitle: Text(
                    user == null
                        ? 'Signed-out account'
                        : '${user.role.label} workspace',
                  ),
                ),
                const SizedBox(height: 8),
                _AccountActionTile(
                  icon: Icons.person_outline_rounded,
                  label: 'View account',
                  onTap: () {
                    Navigator.of(context).pop();
                    parentContext.push(AppRoutes.accountHub);
                  },
                ),
                _AccountActionTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {
                    Navigator.of(context).pop();
                    parentContext.push(AppRoutes.settings);
                  },
                ),
                _AccountActionTile(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Switch workspace',
                  enabled: user?.canSwitchRoles ?? false,
                  onTap: () {
                    Navigator.of(context).pop();
                    parentContext.push(AppRoutes.roleSelection);
                  },
                ),
                _AccountActionTile(
                  icon: Icons.logout_rounded,
                  label: 'Log out',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref
                        .read(authSessionCoordinatorProvider)
                        .confirmAndSignOut(parentContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _initialsFor(AppUser? user) {
    final parts = (user?.name ?? 'QuickDeliver User')
        .split(' ')
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'QD';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _AccountActionTile extends StatelessWidget {
  const _AccountActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: enabled ? onTap : null,
    );
  }
}
