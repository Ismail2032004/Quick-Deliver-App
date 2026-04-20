import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/camera_service.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/safe_network_image.dart';
import '../../../../shared/widgets/section_header.dart';
import '../controllers/auth_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _avatarPath = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.currentUser;
    final trimmedName = user?.name.trim() ?? '';
    final initial = trimmedName.isEmpty ? 'Q' : trimmedName.substring(0, 1);

    return AppShell(
      child: SingleChildScrollView(
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
                    title: 'Profile',
                    subtitle:
                        'Update your account details and keep your role-specific workspace data current.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: const Color(0xFFE6FFFB),
                        child: ClipOval(
                          child: _avatarPath != null && _avatarPath!.isNotEmpty
                              ? SafeNetworkImage(
                                  imageUrl: _avatarPath!,
                                  width: 76,
                                  height: 76,
                                  placeholderIcon: Icons.person_outline_rounded,
                                  placeholderLabel: user?.name,
                                )
                              : Text(
                                  initial.toUpperCase(),
                                  style: Theme.of(context).textTheme.headlineSmall
                                      ?.copyWith(
                                        color: const Color(0xFF0F766E),
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(user?.role.label ?? 'QuickDeliver account'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        user?.email ?? 'Signed-in account',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final image = await ref
                                .read(cameraServiceProvider)
                                .captureProofImage(label: 'avatar');
                            if (image == null) {
                              return;
                            }
                            setState(() {
                              _avatarPath = image.path;
                            });
                          },
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Update avatar'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _nameController,
                        label: 'Full name',
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().length < 3) {
                            return 'Enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _phoneController,
                        label: 'Phone number',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Add a phone number for calls and rider updates';
                          }
                          if (value.trim().length < 8) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Save profile',
                        icon: Icons.save_outlined,
                        isLoading: auth.isBusy,
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) {
                            return;
                          }
                          try {
                            await ref.read(authControllerProvider).updateProfile(
                                  fullName: _nameController.text,
                                  phoneNumber: _phoneController.text,
                                  avatarUrl: _avatarPath,
                                );
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile updated successfully.'),
                            ),
                          );
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            context.go(AppRoutes.profile);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Reset password',
                        icon: Icons.lock_reset_rounded,
                        variant: ButtonVariant.outlined,
                        onPressed: () => context.push(AppRoutes.resetPassword),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
