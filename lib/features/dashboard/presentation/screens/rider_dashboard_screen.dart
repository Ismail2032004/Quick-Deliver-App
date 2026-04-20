import 'package:flutter/material.dart';

import '../../../rider/presentation/widgets/rider_dashboard_tabs.dart';
import '../widgets/dashboard_scaffold.dart';
import '../../../../shared/widgets/account_avatar_button.dart';

class RiderDashboardScreen extends StatelessWidget {
  const RiderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Rider workspace',
      subtitle:
          'Accept deliveries, update status, capture proof, and manage live tracking.',
      providerKey: 'rider-dashboard',
      headerAction: const AccountAvatarButton(
        fallbackIcon: Icons.two_wheeler_rounded,
        fallbackColor: Color(0xFFF97316),
      ),
      tabs: const [
        DashboardTabItem(
          label: 'Dispatch',
          icon: Icons.route_rounded,
          content: RiderDispatchTab(),
        ),
        DashboardTabItem(
          label: 'Deliveries',
          icon: Icons.two_wheeler_rounded,
          content: RiderDeliveriesTab(),
        ),
        DashboardTabItem(
          label: 'History',
          icon: Icons.history_rounded,
          content: RiderHistoryTab(),
        ),
        DashboardTabItem(
          label: 'Account',
          icon: Icons.person_outline_rounded,
          content: RiderAccountTab(),
        ),
      ],
    );
  }
}
