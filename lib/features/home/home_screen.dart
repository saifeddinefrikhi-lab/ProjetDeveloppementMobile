import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:waste_classification/core/config/app_config.dart';
import 'package:waste_classification/core/theme/app_colors.dart';
import 'package:waste_classification/core/widgets/app_launcher_icon.dart';
import 'package:waste_classification/core/widgets/waste_category_icon.dart';
import 'package:waste_classification/data/seed/waste_categories.dart';
import 'package:waste_classification/features/home/waste_group_detail_screen.dart';
import 'package:waste_classification/features/scan/scan_screen.dart';
import 'package:waste_classification/features/settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openScan(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ScanScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              sliver: SliverList.list(
                children: [
                  _HomeHeader(
                    onSettingsPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'home.eyebrow'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('home.title'.tr(), style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 10),
                  Text(
                    'home.subtitle'.tr(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _ScanHeroCard(onPressed: () => _openScan(context)),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'home.categories_title'.tr(),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      _ModeBadge(),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...WasteCategories.all.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CategoryPreview(
                        categoryId: category.id,
                        color: category.color,
                        title: category.name(context.locale),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WasteGroupDetailScreen(category: category),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: AppColors.primaryDark,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'home.privacy_note'.tr(),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSettingsPressed});

  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppLauncherIcon(),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'app_name'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'settings.title'.tr(),
          onPressed: onSettingsPressed,
          icon: const Icon(Icons.tune_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
            foregroundColor: AppColors.primaryDark,
          ),
        ),
      ],
    );
  }
}

class _ScanHeroCard extends StatelessWidget {
  const _ScanHeroCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Text(
                  'home.ai_badge'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'home.scan_card_title'.tr(),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'home.scan_card_subtitle'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text('home.scan_action'.tr()),
          ),
        ],
      ),
    );
  }
}

class _CategoryPreview extends StatelessWidget {
  const _CategoryPreview({
    required this.categoryId,
    required this.color,
    required this.title,
    this.onTap,
  });

  final String categoryId;
  final Color color;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: WasteCategoryIcon(categoryId: categoryId, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mode = AppConfig.classifierMode;
    final isGroq = mode == ClassifierMode.groq;
    final isGemini = mode == ClassifierMode.gemini;
    final isApi = mode == ClassifierMode.api;

    final labelKey = isGroq
        ? 'mode.groq'
        : (isGemini
            ? 'mode.gemini'
            : (isApi ? 'mode.api' : 'mode.demo'));

    final isAi = isGroq || isGemini || isApi;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAi ? AppColors.primaryLight : const Color(0xFFFFF5DD),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        labelKey.tr(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: isAi ? AppColors.primaryDark : const Color(0xFF8A6A25),
        ),
      ),
    );
  }
}
