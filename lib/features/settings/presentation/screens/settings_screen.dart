import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/section_header.dart';
import '../controllers/app_settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final controller = ref.read(appSettingsControllerProvider.notifier);

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
              const Expanded(
                child: SectionHeader(
                  title: 'Settings',
                  subtitle:
                      'Manage notifications, appearance, accessibility, and device preferences.',
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
                  Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: settings.pushNotificationsEnabled,
                    onChanged: (value) =>
                        controller.update(pushNotificationsEnabled: value),
                    title: const Text('Push notifications'),
                    subtitle: const Text(
                      'Receive order, dispatch, and delivery updates on this device.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: settings.soundEnabled,
                    onChanged: (value) =>
                        controller.update(soundEnabled: value),
                    title: const Text('Notification sound'),
                    subtitle: const Text(
                      'Play a sound when a new alert arrives.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: settings.vibrationEnabled,
                    onChanged: (value) =>
                        controller.update(vibrationEnabled: value),
                    title: const Text('Vibration'),
                    subtitle: const Text(
                      'Use vibration cues for important delivery updates.',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance and accessibility',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: settings.darkModeEnabled,
                    onChanged: (value) =>
                        controller.update(darkModeEnabled: value),
                    title: const Text('Dark mode'),
                    subtitle: const Text(
                      'Use a darker appearance across the app.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: settings.largerTextEnabled,
                    onChanged: (value) =>
                        controller.update(largerTextEnabled: value),
                    title: const Text('Readable text mode'),
                    subtitle: const Text(
                      'Increase text size slightly across the interface.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: settings.reducedMotionEnabled,
                    onChanged: (value) =>
                        controller.update(reducedMotionEnabled: value),
                    title: const Text('Reduced motion'),
                    subtitle: const Text(
                      'Reduce app animation where possible.',
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: settings.highContrastEnabled,
                    onChanged: (value) =>
                        controller.update(highContrastEnabled: value),
                    title: const Text('High contrast'),
                    subtitle: const Text(
                      'Increase contrast for stronger visual separation.',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy and language',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(settings.locationSharingDescription),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: settings.languageCode,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(
                        value: 'coming-soon',
                        child: Text('More languages soon'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      controller.update(languageCode: value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
