import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_classification/core/theme/app_colors.dart';
import 'package:waste_classification/data/models/user_model.dart';
import 'package:waste_classification/features/auth/auth_provider.dart';
import 'package:waste_classification/features/auth/auth_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isSavingProfile = false;
  bool _isChangingPassword = false;

  String? _profileError;
  String? _passwordError;
  String? _profileSuccess;
  String? _passwordSuccess;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) _nameCtrl.text = user.name;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() {
      _isSavingProfile = true;
      _profileError = null;
      _profileSuccess = null;
    });

    final error = await ref.read(authProvider.notifier).updateProfile(
          name: _nameCtrl.text,
        );

    if (!mounted) return;
    setState(() {
      _isSavingProfile = false;
      if (error == null) {
        _profileSuccess = 'Profile details updated!';
      } else {
        _profileError = error;
      }
    });
  }

  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() {
      _isChangingPassword = true;
      _passwordError = null;
      _passwordSuccess = null;
    });

    final error = await ref.read(authProvider.notifier).changePassword(
          currentPassword: _currentPassCtrl.text,
          newPassword: _newPassCtrl.text,
        );

    if (!mounted) return;
    setState(() {
      _isChangingPassword = false;
      if (error == null) {
        _passwordSuccess = 'Password changed successfully!';
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      } else {
        _passwordError = error;
      }
    });
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?'),
        content: const Text(
            'You will need to sign in again to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorText),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profile & Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvatarHeader(user: user),
            const SizedBox(height: 28),

            // ═══════════════════════════════════════════
            // SECTION 1: Personal Details
            // ═══════════════════════════════════════════
            _CardContainer(
              title: 'Account Information',
              icon: Icons.person_outline_rounded,
              child: Form(
                key: _profileFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_profileSuccess != null) ...[
                      _SuccessMessage(message: _profileSuccess!),
                      const SizedBox(height: 14),
                    ],
                    if (_profileError != null) ...[
                      AuthErrorBanner(message: _profileError!),
                      const SizedBox(height: 14),
                    ],
                    const AuthFieldLabel('Full Name'),
                    const SizedBox(height: 8),
                    AuthField(
                      controller: _nameCtrl,
                      hint: 'Your full name',
                      icon: Icons.person_outline,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Name is required';
                        if (v.trim().length < 2) return 'Name too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const AuthFieldLabel('Email Address'),
                    const SizedBox(height: 8),
                    _ReadonlyField(
                      value: user.email,
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),
                    const AuthFieldLabel('Member Since'),
                    const SizedBox(height: 8),
                    _ReadonlyField(
                      value: _formatDate(user.createdAt),
                      icon: Icons.calendar_today_outlined,
                    ),
                    const SizedBox(height: 20),
                    AuthSubmitButton(
                      label: 'Save Profile',
                      isLoading: _isSavingProfile,
                      onTap: _saveProfile,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ═══════════════════════════════════════════
            // SECTION 2: Change Password
            // ═══════════════════════════════════════════
            _CardContainer(
              title: 'Change Password',
              icon: Icons.lock_outline_rounded,
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_passwordSuccess != null) ...[
                      _SuccessMessage(message: _passwordSuccess!),
                      const SizedBox(height: 14),
                    ],
                    if (_passwordError != null) ...[
                      AuthErrorBanner(message: _passwordError!),
                      const SizedBox(height: 14),
                    ],
                    const AuthFieldLabel('Current Password'),
                    const SizedBox(height: 8),
                    AuthField(
                      controller: _currentPassCtrl,
                      hint: 'Enter your current password',
                      icon: Icons.lock_outline,
                      obscure: _obscureCurrent,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const AuthFieldLabel('New Password'),
                    const SizedBox(height: 8),
                    AuthField(
                      controller: _newPassCtrl,
                      hint: 'At least 6 characters',
                      icon: Icons.key_rounded,
                      obscure: _obscureNew,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter your new password';
                        }
                        if (v.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        if (v == _currentPassCtrl.text) {
                          return 'New password must be different from current';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const AuthFieldLabel('Confirm New Password'),
                    const SizedBox(height: 8),
                    AuthField(
                      controller: _confirmPassCtrl,
                      hint: 'Re-enter new password',
                      icon: Icons.check_circle_outline,
                      obscure: _obscureConfirm,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Confirm your new password';
                        }
                        if (v != _newPassCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    AuthSubmitButton(
                      label: 'Update Password',
                      isLoading: _isChangingPassword,
                      onTap: _updatePassword,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Avatar Header ─────────────────────────────────────────────────────────────

class _AvatarHeader extends StatelessWidget {
  final UserModel user;
  const _AvatarHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF8FC9A9), Color(0xFF5FA084)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Center(
              child: Text(
                user.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card Container ────────────────────────────────────────────────────────────

class _CardContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _CardContainer({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryDark, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.border, height: 1),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Readonly Field ────────────────────────────────────────────────────────────

class _ReadonlyField extends StatelessWidget {
  final String value;
  final IconData icon;
  const _ReadonlyField({required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(Icons.lock_outline, color: AppColors.border, size: 16),
        ],
      ),
    );
  }
}

// ── Success Message ───────────────────────────────────────────────────────────

class _SuccessMessage extends StatelessWidget {
  final String message;
  const _SuccessMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.organic.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryDark, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.primaryDark, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
