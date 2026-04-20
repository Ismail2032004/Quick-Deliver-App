import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/dashboard_tab_controller.dart';
import '../../../../shared/widgets/app_shell.dart';

class DashboardTabItem {
  const DashboardTabItem({
    required this.label,
    required this.icon,
    required this.content,
  });

  final String label;
  final IconData icon;
  final Widget content;
}

class DashboardScaffold extends ConsumerWidget {
  const DashboardScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.providerKey,
    required this.tabs,
    this.headerAction,
  });

  final String title;
  final String subtitle;
  final String providerKey;
  final List<DashboardTabItem> tabs;
  final Widget? headerAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(dashboardTabProvider(providerKey));

    return AppShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (headerAction != null) ...[
                const SizedBox(width: 12),
                headerAction!,
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          Expanded(child: tabs[index].content),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          ref.read(dashboardTabProvider(providerKey).notifier).state = value;
        },
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}
