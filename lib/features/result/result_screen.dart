import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:waste_classification/core/theme/app_colors.dart';
import 'package:waste_classification/core/widgets/waste_category_icon.dart';
import 'package:waste_classification/data/models/classification_result.dart';
import 'package:waste_classification/data/models/scan_result.dart';
import 'package:waste_classification/data/seed/waste_categories.dart';
import 'package:waste_classification/features/scan/scan_screen.dart';
import 'package:waste_classification/services/classifier/model_label_mapper.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    required this.scanResult,
    required this.classification,
    super.key,
  });

  final ScanResult scanResult;
  final ClassificationResult classification;

  void _scanAgain(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ScanScreen()),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = WasteCategories.byId(scanResult.categoryId);
    final modelLabel = ModelLabelMapper.translationKeyFor(
      classification.modelLabel,
    ).tr();
    final confidence = classification.confidence.clamp(0, 1).toDouble();
    final isLowConfidence = confidence < 0.5;

    return Scaffold(
      appBar: AppBar(
        title: Text('result.title'.tr()),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'common.home'.tr(),
            onPressed: () => _goHome(context),
            icon: const Icon(Icons.home_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: kIsWeb
                  ? const ColoredBox(
                      color: AppColors.primaryLight,
                      child: Center(
                        child: Icon(
                          Icons.photo_camera_outlined,
                          size: 48,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    )
                  : Image.file(
                      File(scanResult.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.primaryLight,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: WasteCategoryIcon(categoryId: category.id, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'result.classified_as'.tr(),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.name(context.locale),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        modelLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isLowConfidence) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.errorText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'result.low_confidence'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.errorText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _Section(
            title: 'result.about_title'.tr(),
            icon: Icons.info_outline_rounded,
            child: Text(
              category.description(context.locale),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 22),
          _Section(
            title: 'result.disposal_title'.tr(),
            icon: Icons.recycling_rounded,
            child: Text(
              category.disposalInstruction(context.locale),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 22),
          _Section(
            title: 'result.confidence_title'.tr(),
            icon: Icons.analytics_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: confidence,
                    minHeight: 9,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'result.confidence_value'.tr(
                    namedArgs: {'value': (confidence * 100).round().toString()},
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          FilledButton.icon(
            onPressed: () => _scanAgain(context),
            icon: const Icon(Icons.center_focus_strong_rounded),
            label: Text('result.scan_again'.tr()),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _goHome(context),
            icon: const Icon(Icons.home_outlined),
            label: Text('result.back_home'.tr()),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 21, color: AppColors.primaryDark),
            const SizedBox(width: 9),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}
