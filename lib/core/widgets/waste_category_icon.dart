import 'package:flutter/material.dart';
import 'package:waste_classification/core/theme/app_colors.dart';

/// A small, platform-rendered icon for each waste category.
///
/// Material icons remain sharp at every screen density and avoid the
/// overlapping SVG strokes that previously appeared as black or white marks.
class WasteCategoryIcon extends StatelessWidget {
  const WasteCategoryIcon({
    required this.categoryId,
    this.size = 24,
    this.color = AppColors.primaryDark,
    super.key,
  });

  final String categoryId;
  final double size;
  final Color color;

  static IconData iconFor(String categoryId) => switch (categoryId) {
    'organic' => Icons.eco_rounded,
    'recyclable' => Icons.recycling_rounded,
    _ => Icons.delete_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Icon(
      iconFor(categoryId),
      color: color,
      size: size,
      semanticLabel: null,
    );
  }
}
