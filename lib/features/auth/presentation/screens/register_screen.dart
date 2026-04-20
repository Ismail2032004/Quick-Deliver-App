import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  AppRole _selectedRole = AppRole.customer;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final awaitingVerification = auth.isAwaitingEmailVerification;

    return AppShell(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton.filledTonal(
              onPressed: () => context.go(AppRoutes.login),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Create your account',
              subtitle:
                  'Create your QuickDeliver account. If email confirmation is enabled, we will ask you to verify your email before you sign in.',
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: awaitingVerification
                    ? _VerificationPendingState(
                        email: auth.pendingVerificationEmail ?? '',
                        isBusy: auth.isBusy,
                        signupRole: auth.pendingSignupRole,
                        infoMessage: auth.lastInfoMessage,
                        errorMessage: auth.lastError,
                        onResend: () async {
                          try {
                            await ref
                                .read(authControllerProvider)
                                .resendVerificationEmail();
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        },
                        onBackToLogin: () => context.go(AppRoutes.login),
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _nameController,
                              label: 'Full name',
                              hint: 'Ama Boateng',
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
                              controller: _emailController,
                              label: 'Email address',
                              hint: 'ama@example.com',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.mail_outline_rounded,
                              validator: (value) {
                                if (value == null || !value.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _passwordController,
                              label: 'Password',
                              obscureText: true,
                              prefixIcon: Icons.lock_outline_rounded,
                              validator: (value) {
                                if (value == null || value.length < 8) {
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
                            const SizedBox(height: 18),
                            _SignupRoleSelector(
                              selectedRole: _selectedRole,
                              onChanged: (role) {
                                setState(() {
                                  _selectedRole = role;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            PrimaryButton(
                              label: 'Create account',
                              icon: Icons.arrow_forward_rounded,
                              isLoading: auth.isBusy,
                              onPressed: () async {
                                if (!_formKey.currentState!.validate()) return;
                                try {
                                  await ref.read(authControllerProvider).register(
                                        name: _nameController.text,
                                        email: _emailController.text,
                                        password: _passwordController.text,
                                        signupRole: _selectedRole,
                                      );
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString())),
                                  );
                                  return;
                                }
                                if (!context.mounted) return;
                                if (ref
                                    .read(authControllerProvider)
                                    .currentUser !=
                                    null) {
                                  context.go(AppRoutes.roleSelection);
                                }
                              },
                            ),
                            if (!AppConfig.isSupabaseConfigured &&
                                !AppConfig.demoMode) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Supabase is not configured yet. Add your Dart defines before creating an account.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF92400E),
                                      ),
                                ),
                              ),
                            ],
                            if (auth.lastInfoMessage != null) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  auth.lastInfoMessage!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF0F766E),
                                      ),
                                ),
                              ),
                            ],
                            if (auth.lastError != null) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  auth.lastError!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFFB91C1C),
                                      ),
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

class _VerificationPendingState extends StatelessWidget {
  const _VerificationPendingState({
    required this.email,
    required this.isBusy,
    required this.onResend,
    required this.onBackToLogin,
    required this.signupRole,
    this.infoMessage,
    this.errorMessage,
  });

  final String email;
  final bool isBusy;
  final AppRole signupRole;
  final String? infoMessage;
  final String? errorMessage;
  final Future<void> Function() onResend;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Account created',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _headlineCopy(email, signupRole),
        ),
        const SizedBox(height: 12),
        Text(
          _supportingCopy(signupRole),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
        ),
        if (infoMessage != null) ...[
          const SizedBox(height: 14),
          Text(
            infoMessage!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF0F766E)),
          ),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            errorMessage!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C)),
          ),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Resend verification email',
          icon: Icons.refresh_rounded,
          isLoading: isBusy,
          onPressed: onResend,
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Back to sign in',
          variant: ButtonVariant.outlined,
          onPressed: onBackToLogin,
        ),
      ],
    );
  }

  String _headlineCopy(String email, AppRole role) {
    return switch (role) {
      AppRole.customer =>
        'We created your customer account for $email. Check your email and open the verification link on this device to finish signing in.',
      AppRole.rider =>
        'We created your QuickDeliver account for $email. Check your email and open the verification link on this device to continue with customer access while your rider request enters review.',
      AppRole.owner =>
        'We created your QuickDeliver account for $email. Check your email and open the verification link on this device to continue with customer access while your business request enters review.',
    };
  }

  String _supportingCopy(AppRole role) {
    return switch (role) {
      AppRole.customer =>
        'Once your email is confirmed, return to the sign-in screen and continue normally.',
      AppRole.rider =>
        'After confirmation, QuickDeliver will take you to workspace selection with customer access available first. Rider tools stay locked until review is complete.',
      AppRole.owner =>
        'After confirmation, QuickDeliver will take you to workspace selection with customer access available first. Business tools stay locked until review is complete.',
    };
  }
}

class _SignupRoleSelector extends StatelessWidget {
  const _SignupRoleSelector({
    required this.selectedRole,
    required this.onChanged,
  });

  final AppRole selectedRole;
  final ValueChanged<AppRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your primary setup',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Customer access is available by default. Rider and business access stay aligned with QuickDeliver approval review.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),
        ...AppRole.values.map(
          (role) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SignupRoleCard(
              role: role,
              selected: selectedRole == role,
              onTap: () => onChanged(role),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignupRoleCard extends StatelessWidget {
  const _SignupRoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final AppRole role;
  final bool selected;
  final VoidCallback onTap;

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
    final helper = switch (role) {
      AppRole.customer => 'Start ordering as soon as your email is confirmed.',
      AppRole.rider =>
        'Create your account now, then continue with customer access while rider approval is reviewed.',
      AppRole.owner =>
        'Create your account now, then continue with customer access while your business approval is reviewed.',
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? accent : const Color(0xFFE2E8F0),
            width: selected ? 1.8 : 1,
          ),
          color: selected
              ? accent.withValues(alpha: 0.08)
              : Colors.white,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          role.label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded, color: accent),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(role.description),
                  const SizedBox(height: 6),
                  Text(
                    helper,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
