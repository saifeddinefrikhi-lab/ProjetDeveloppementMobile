import 'package:material_ui/material_ui.dart';
import 'package:waste_classification/core/config/app_config.dart';
import 'package:waste_classification/core/theme/app_colors.dart';
import 'package:waste_classification/features/auth/auth_widgets.dart';
import 'package:waste_classification/features/auth/reset_password_screen.dart';
import 'package:waste_classification/services/auth/backend_auth_service.dart';

class VerifyResetCodeScreen extends StatefulWidget {
  const VerifyResetCodeScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyResetCodeScreen> createState() => _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends State<VerifyResetCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _service = BackendAuthService(baseUrl: AppConfig.apiBaseUrl);
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _service.verifyPasswordResetCode(
        email: widget.email,
        code: _code.text,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        authFadeRoute(ResetPasswordScreen(token: token)),
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
      title: const Text('Verify reset code'),
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
                'Enter the code',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a six-digit code to ${widget.email}.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              if (_error != null) ...[
                AuthErrorBanner(message: _error!),
                const SizedBox(height: 18),
              ],
              const AuthFieldLabel('Reset code'),
              const SizedBox(height: 8),
              AuthField(
                controller: _code,
                hint: '123456',
                icon: Icons.pin_outlined,
                keyboardType: TextInputType.number,
                validator: (value) => value == null ||
                        !RegExp(r'^\d{6}$').hasMatch(value.trim())
                    ? 'Enter the six-digit code'
                    : null,
              ),
              const SizedBox(height: 28),
              AuthSubmitButton(
                label: 'Verify code',
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
