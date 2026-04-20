import 'package:flutter/material.dart';

import 'primary_button.dart';

class ContactActionBar extends StatelessWidget {
  const ContactActionBar({
    super.key,
    this.onCallBusiness,
    this.onCallRider,
    this.onCallCustomer,
  });

  final VoidCallback? onCallBusiness;
  final VoidCallback? onCallRider;
  final VoidCallback? onCallCustomer;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (onCallBusiness != null)
        PrimaryButton(
          label: 'Call business',
          variant: ButtonVariant.outlined,
          icon: Icons.storefront_rounded,
          onPressed: onCallBusiness,
        ),
      if (onCallRider != null)
        PrimaryButton(
          label: 'Call rider',
          variant: ButtonVariant.outlined,
          icon: Icons.two_wheeler_rounded,
          onPressed: onCallRider,
        ),
      if (onCallCustomer != null)
        PrimaryButton(
          label: 'Call customer',
          variant: ButtonVariant.outlined,
          icon: Icons.person_outline_rounded,
          onPressed: onCallCustomer,
        ),
    ];

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            children: [
              for (final button in buttons) ...[
                button,
                if (button != buttons.last) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              Expanded(child: buttons[i]),
              if (i != buttons.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}
