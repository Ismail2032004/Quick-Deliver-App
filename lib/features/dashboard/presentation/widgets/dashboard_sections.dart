import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/dashboard_metric_card.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../../../auth/presentation/controllers/auth_session_coordinator.dart';

class OverviewPanel extends StatelessWidget {
  const OverviewPanel({
    super.key,
    required this.heroTitle,
    required this.heroBody,
    required this.metrics,
    required this.highlights,
  });

  final String heroTitle;
  final String heroBody;
  final List<MetricItem> metrics;
  final List<String> highlights;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _HeroCard(title: heroTitle, body: heroBody),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final item = metrics[index];
            return DashboardMetricCard(
              label: item.label,
              value: item.value,
              icon: item.icon,
              color: item.color,
            );
          },
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Workspace highlights',
                  subtitle:
                      'These sections are structured to connect cleanly to live data and services.',
                ),
                const SizedBox(height: 18),
                for (final item in highlights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ActivityPanel extends StatelessWidget {
  const ActivityPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 16),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                leading: CircleAvatar(
                  backgroundColor: item.color.withValues(alpha: 0.12),
                  child: Icon(item.icon, color: item.color),
                ),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                trailing: item.trailing == null
                    ? null
                    : Text(
                        item.trailing!,
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: item.color),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class UtilityPanel extends ConsumerWidget {
  const UtilityPanel({
    super.key,
    required this.role,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final AppRole role;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Workspace actions',
                  subtitle:
                      'Switch workspaces, update your profile, and manage the active app session.',
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Profile',
                  icon: Icons.person_outline_rounded,
                  onPressed: () => context.push(AppRoutes.profile),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Switch role',
                  variant: ButtonVariant.tonal,
                  icon: Icons.swap_horiz_rounded,
                  onPressed: () => context.go(AppRoutes.roleSelection),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Sign out',
                  variant: ButtonVariant.outlined,
                  icon: Icons.logout_rounded,
                  onPressed: () async {
                    await ref
                        .read(authSessionCoordinatorProvider)
                        .confirmAndSignOut(context);
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  'Support line: ${AppConstants.supportPhone}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: role == AppRole.rider
                ? const ErrorStateView(
                    message:
                        'Live delivery tracking, maps, and proof capture are scaffolded and ready for backend/device configuration.',
                  )
                : EmptyStateView(
                    title: emptyTitle,
                    message: emptyMessage,
                    actionLabel: 'Open role selection',
                    onAction: () => context.go(AppRoutes.roleSelection),
                  ),
          ),
        ),
      ],
    );
  }
}

class MetricItem {
  const MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class ActivityItem {
  const ActivityItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? trailing;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}
