import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:waste_classification/core/config/app_config.dart';
import 'package:waste_classification/core/theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
          _InfoCard(
            icon: Icons.auto_awesome_rounded,
            title: 'settings.used_ai_title'.tr(),
            description: _usedAiDescription.tr(),
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

  String get _usedAiDescription {
    return switch (AppConfig.classifierMode) {
      ClassifierMode.api => 'settings.used_ai_api',
      ClassifierMode.gemini => 'settings.used_ai_gemini',
      ClassifierMode.groq => 'settings.used_ai_api',
      ClassifierMode.mock => 'settings.used_ai_demo',
      ClassifierMode.hfInference => 'settings.used_ai_hugging_face',
    };
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
