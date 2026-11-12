import 'package:material_ui/material_ui.dart';
import 'package:waste_classification/core/config/app_config.dart';
import 'package:waste_classification/core/theme/app_colors.dart';
import 'package:waste_classification/features/auth/auth_widgets.dart';
import 'package:waste_classification/features/auth/verify_reset_code_screen.dart';
import 'package:waste_classification/services/auth/backend_auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _service = BackendAuthService(baseUrl: AppConfig.apiBaseUrl);
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.requestPasswordReset(email: _email.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        authFadeRoute(VerifyResetCodeScreen(email: _email.text.trim())),
      );
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Reset password'),
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
              const Text(
                'Forgot your password?',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'Enter your email and we will send you a six-digit reset code.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              if (_error != null) ...[
                AuthErrorBanner(message: _error!),
                const SizedBox(height: 18),
              ],
              const AuthFieldLabel('Email'),
              const SizedBox(height: 8),
              AuthField(
                controller: _email,
                hint: 'you@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 24),
              AuthSubmitButton(
                label: 'Send reset code',
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
