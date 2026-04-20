import 'package:flutter/material.dart';

import '../../../business_owner/presentation/widgets/owner_dashboard_tabs.dart';
import '../widgets/dashboard_scaffold.dart';
import '../../../../shared/widgets/account_avatar_button.dart';

class BusinessOwnerDashboardScreen extends StatelessWidget {
  const BusinessOwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Business workspace',
      subtitle:
          'Manage your storefront, products, incoming orders, and rider assignment in one place.',
      providerKey: 'owner-dashboard',
      headerAction: const AccountAvatarButton(
        fallbackIcon: Icons.storefront_rounded,
        fallbackColor: Color(0xFF2563EB),
      ),
      tabs: const [
        DashboardTabItem(
          label: 'Overview',
          icon: Icons.storefront_rounded,
          content: OwnerOverviewTab(),
        ),
        DashboardTabItem(
          label: 'Orders',
          icon: Icons.receipt_long_rounded,
          content: OwnerOrdersTab(),
        ),
        DashboardTabItem(
          label: 'Manage',
          icon: Icons.inventory_2_outlined,
          content: OwnerManageTab(),
        ),
        DashboardTabItem(
          label: 'Account',
          icon: Icons.person_outline_rounded,
          content: OwnerAccountTab(),
        ),
      ],
    );
  }
}
