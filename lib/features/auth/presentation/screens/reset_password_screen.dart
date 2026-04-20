import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/password_recovery_service.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_session_coordinator.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final recovery = ref.watch(passwordRecoveryServiceProvider);
    final canReset = auth.currentUser != null || recovery.hasRecoveryContext;
    final isRecoveryMode = recovery.hasRecoveryContext;
    if (recovery.pendingResetNavigation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(passwordRecoveryServiceProvider).markResetRouteVisited();
      });
    }

    return AppShell(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton.filledTonal(
              onPressed: () => context.go(
                isRecoveryMode ? AppRoutes.login : AppRoutes.profile,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Choose a new password',
              subtitle:
                  'Use this screen after opening your reset link, or while signed in if you want to rotate your password.',
            ),
            const SizedBox(height: 20),
            if (!canReset)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset link required',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Open the password-reset link from your email on this device, or sign in first if you just want to change your password from inside the app.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF475569),
                        ),
                      ),
                      if (recovery.lastError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          recovery.lastError!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFFB91C1C)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Back to login',
                        icon: Icons.login_rounded,
                        onPressed: () => context.go(AppRoutes.login),
                      ),
                    ],
                  ),
                ),
              )
            else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _passwordController,
                        label: 'New password',
                        obscureText: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (value) {
                          if (value == null || value.trim().length < 8) {
                            return 'Use at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm password',
                        obscureText: true,
                        prefixIcon: Icons.verified_user_outlined,
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Update password',
                        icon: Icons.password_rounded,
                        isLoading: auth.isBusy,
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) {
                            return;
                          }
                          try {
                            await ref
                                .read(authControllerProvider)
                                .updatePassword(
                                  password: _passwordController.text.trim(),
                                );
                            if (isRecoveryMode) {
                              ref
                                  .read(passwordRecoveryServiceProvider)
                                  .clearRecoveryContext();
                              await ref
                                  .read(authSessionCoordinatorProvider)
                                  .signOut();
                            }
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isRecoveryMode
                                      ? 'Password updated. Sign in with your new password.'
                                      : 'Password updated successfully.',
                                ),
                              ),
                            );
                            context.go(
                              isRecoveryMode ? AppRoutes.login : AppRoutes.profile,
                            );
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        },
                      ),
                      if (auth.lastError != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            auth.lastError!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFFB91C1C)),
                          ),
                        ),
                      ],
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
