import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waste_classification/core/config/app_config.dart';
import 'package:waste_classification/core/theme/app_colors.dart';
import 'package:waste_classification/data/local/groq_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  bool _obscureKey = true;
  bool _isSavingKey = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final key = await groqPreferences.getApiKey();
    if (key != null && key.isNotEmpty && mounted) {
      setState(() => _apiKeyCtrl.text = key);
    }
  }

  Future<void> _saveApiKey() async {
    setState(() {
      _isSavingKey = true;
    });

    await groqPreferences.saveApiKey(_apiKeyCtrl.text.trim());

    if (!mounted) return;
    setState(() {
      _isSavingKey = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('settings.groq_key_saved'.tr()),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentLanguage = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Language Section ──
          Text(
            'settings.language_section'.tr(),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'settings.language_description'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _LanguageTile(
            title: 'settings.english'.tr(),
            subtitle: 'settings.english_native'.tr(),
            selected: currentLanguage == 'en',
            onTap: () => context.setLocale(const Locale('en')),
          ),
          const SizedBox(height: 10),
          _LanguageTile(
            title: 'settings.french'.tr(),
            subtitle: 'settings.french_native'.tr(),
            selected: currentLanguage == 'fr',
            onTap: () => context.setLocale(const Locale('fr')),
          ),
          const SizedBox(height: 10),
          _LanguageTile(
            title: 'settings.arabic'.tr(),
            subtitle: 'settings.arabic_native'.tr(),
            selected: currentLanguage == 'ar',
            onTap: () => context.setLocale(const Locale('ar')),
          ),

          const SizedBox(height: 30),

          // ── AI Section ──
          Text('settings.ai_section'.tr(), style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _GroqConfigCard(
            controller: _apiKeyCtrl,
            obscureKey: _obscureKey,
            isSaving: _isSavingKey,
            onToggleVisibility: () => setState(() => _obscureKey = !_obscureKey),
            onSave: _saveApiKey,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.lock_outline_rounded,
            title: 'settings.privacy_title'.tr(),
            description: 'settings.privacy_local'.tr(),
          ),

          const SizedBox(height: 30),
          Center(
            child: Text(
              'settings.version'.tr(
                namedArgs: {'version': AppConfig.appVersion},
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroqConfigCard extends StatelessWidget {
  final TextEditingController controller;
  final bool obscureKey;
  final bool isSaving;
  final VoidCallback onToggleVisibility;
  final VoidCallback onSave;

  const _GroqConfigCard({
    required this.controller,
    required this.obscureKey,
    required this.isSaving,
    required this.onToggleVisibility,
    required this.onSave,
  });

  Future<void> _openGroqConsole() async {
    final uri = Uri.parse('https://console.groq.com/keys');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF16A34A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Groq Vision AI',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Qwen 2.5 27B Vision · Ultra-fast (0.2s)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '● Active',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StepHint(
            step: '1',
            text: 'Get your free Groq API key',
            trailing: TextButton.icon(
              onPressed: _openGroqConsole,
              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
              label: const Text('Open Groq'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const _StepHint(
            step: '2',
            text: 'Click "Create API Key" → copy key (starts with gsk_)',
          ),
          const _StepHint(
            step: '3',
            text: 'Paste your key below and tap Save Key',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            obscureText: obscureKey,
            decoration: InputDecoration(
              hintText: 'settings.groq_key_hint'.tr(),
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
              ),
              filled: true,
              fillColor: AppColors.primaryLight.withValues(alpha: 0.35),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.8),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: onToggleVisibility,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text('settings.groq_key_save'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHint extends StatelessWidget {
  final String step;
  final String text;
  final Widget? trailing;

  const _StepHint({required this.step, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {

  const _LanguageTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryLight : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primaryDark : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
