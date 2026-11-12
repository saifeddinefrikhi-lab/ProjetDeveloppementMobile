import 'package:material_ui/material_ui.dart';
import 'package:waste_classification/core/config/app_config.dart';
import 'package:waste_classification/core/theme/app_colors.dart';
import 'package:waste_classification/features/auth/auth_widgets.dart';
import 'package:waste_classification/services/auth/backend_auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _service = BackendAuthService(baseUrl: AppConfig.apiBaseUrl);
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.resetPassword(
        token: widget.token,
        newPassword: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Choose a new password'),
      leading: const BackButton(color: AppColors.textPrimary),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                AuthErrorBanner(message: _error!),
                const SizedBox(height: 18),
              ],
              const AuthFieldLabel('New password'),
              const SizedBox(height: 8),
              AuthField(
                controller: _password,
                hint: 'At least 8 characters',
                icon: Icons.lock_outline,
                obscure: true,
                validator: (value) => value == null || value.length < 8
                    ? 'Password must be at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 20),
              const AuthFieldLabel('Confirm password'),
              const SizedBox(height: 8),
              AuthField(
                controller: _confirmation,
                hint: 'Repeat your new password',
                icon: Icons.lock_outline,
                obscure: true,
                validator: (value) =>
                    value != _password.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 28),
              AuthSubmitButton(
                label: 'Reset password',
                isLoading: _loading,
                onTap: _submit,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
