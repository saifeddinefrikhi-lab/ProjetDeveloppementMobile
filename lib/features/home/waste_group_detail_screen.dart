import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:waste_classification/core/theme/app_colors.dart';
import 'package:waste_classification/core/widgets/waste_category_icon.dart';
import 'package:waste_classification/data/models/waste_category.dart';
import 'package:waste_classification/features/scan/scan_screen.dart';

class WasteGroupDetailScreen extends StatelessWidget {
  const WasteGroupDetailScreen({
    super.key,
    required this.category,
  });

  final WasteCategory category;

  List<_GroupItemInfo> _getItemsForCategory(String categoryId, Locale locale) {
    final lang = locale.languageCode;
    switch (categoryId) {
      case 'organic':
        return [
          _GroupItemInfo(
            title: lang == 'fr'
                ? 'Déchets alimentaires'
                : (lang == 'ar' ? 'بقايا الطعام' : 'Food Organics'),
            description: lang == 'fr'
                ? 'Fruits, légumes, marc de café, restes de repas, coquilles d\'œufs'
                : (lang == 'ar'
                    ? 'فواكه، خضراوات، بقايا طعام، قشور البيض، تفل القهوة'
                    : 'Fruits, vegetables, food scraps, coffee grounds, eggshells'),
            icon: Icons.restaurant_rounded,
          ),
          _GroupItemInfo(
            title: lang == 'fr'
                ? 'Végétaux'
                : (lang == 'ar' ? 'مخلفات نباتية' : 'Vegetation'),
            description: lang == 'fr'
                ? 'Feuilles, herbe coupée, petites branches, fleurs fanées'
                : (lang == 'ar'
                    ? 'أوراق شجر، أعشاب، أغصان صغيرة، زهور ذابلة'
                    : 'Leaves, grass clippings, small branches, wilted flowers'),
            icon: Icons.yard_rounded,
          ),
        ];
      case 'recyclable':
        return [
          _GroupItemInfo(
            title: lang == 'fr' ? 'Plastique' : (lang == 'ar' ? 'بلاستيك' : 'Plastic'),
            description: lang == 'fr'
                ? 'Bouteilles d\'eau, flacons, récipients propres'
                : (lang == 'ar'
                    ? 'زجاجات مياه، عبوات منظفات، حاويات نظيفة'
                    : 'Bottles, jugs, clean food containers'),
            icon: Icons.local_drink_rounded,
          ),
          _GroupItemInfo(
            title: lang == 'fr' ? 'Papier' : (lang == 'ar' ? 'ورق' : 'Paper'),
            description: lang == 'fr'
                ? 'Journaux, magazines, feuilles de bureau, prospectus'
                : (lang == 'ar'
                    ? 'جرائد، مجلات، أوراق مكتبية، كتيبات'
                    : 'Newspapers, magazines, office paper, envelopes'),
            icon: Icons.description_rounded,
          ),
          _GroupItemInfo(
            title: lang == 'fr' ? 'Carton' : (lang == 'ar' ? 'كرتون' : 'Cardboard'),
            description: lang == 'fr'
                ? 'Cartons d\'emballage, boîtes de céréales, briques de lait'
                : (lang == 'ar'
                    ? 'صناديق شحن، علب كرتون، عبوات تغليف'
                    : 'Shipping boxes, cereal boxes, cardboard packaging'),
            icon: Icons.inventory_2_rounded,
          ),
          _GroupItemInfo(
            title: lang == 'fr' ? 'Verre' : (lang == 'ar' ? 'زجاج' : 'Glass'),
            description: lang == 'fr'
                ? 'Bouteilles en verre, bocaux alimentaires, pots'
                : (lang == 'ar'
                    ? 'قوارير زجاجية، برطمانات طعام، أوعية'
                    : 'Glass bottles, food jars, beverage containers'),
            icon: Icons.wine_bar_rounded,
          ),
          _GroupItemInfo(
            title: lang == 'fr' ? 'Métal' : (lang == 'ar' ? 'معادن' : 'Metal'),
            description: lang == 'fr'
                ? 'Canettes de boisson, boîtes de conserve, barquettes alu'
                : (lang == 'ar'
                    ? 'علب مشروبات، علب حفظ الأغذية، رقائق معدنية'
                    : 'Drink cans, food tins, aluminum trays'),
            icon: Icons.hardware_rounded,
          ),
        ];
      case 'other':
      default:
        return [
          _GroupItemInfo(
            title: lang == 'fr'
                ? 'Déchets résiduels'
                : (lang == 'ar' ? 'نفايات متنوعة' : 'Miscellaneous Trash'),
            description: lang == 'fr'
                ? 'Emballages souillés, céramiques cassées, litières, éponges'
                : (lang == 'ar'
                    ? 'أشياء ملوثة، خزف مكسور، مناديل غير قابلة للتدوير'
                    : 'Soiled packaging, broken ceramics, non-recyclable items'),
            icon: Icons.delete_outline_rounded,
          ),
          _GroupItemInfo(
            title: lang == 'fr'
                ? 'Déchets textiles'
                : (lang == 'ar' ? 'منسوجات وأقمشة' : 'Textile Trash'),
            description: lang == 'fr'
                ? 'Vêtements usagés, tissus déchirés, chiffons'
                : (lang == 'ar'
                    ? 'ملابس قديمة تالفة، أقمشة ممزقة، مناشف مستعملة'
                    : 'Worn-out clothes, torn fabrics, rags'),
            icon: Icons.checkroom_rounded,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.locale;
    final items = _getItemsForCategory(category.id, locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name(locale)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // ── Hero Banner ──
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: category.color.withValues(alpha: 0.8)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: WasteCategoryIcon(categoryId: category.id, size: 40),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name(locale),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'waste_group.title'.tr(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── About Section ──
            _DetailCard(
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.primaryDark,
              iconBgColor: AppColors.primaryLight,
              title: 'waste_group.about_title'.tr(),
              content: category.description(locale),
            ),

            const SizedBox(height: 14),

            // ── Disposal Instruction Section ──
            _DetailCard(
              icon: Icons.recycling_rounded,
              iconColor: const Color(0xFF16A34A),
              iconBgColor: const Color(0xFFDCFCE7),
              title: 'waste_group.disposal_title'.tr(),
              content: category.disposalInstruction(locale),
            ),

            const SizedBox(height: 20),

            // ── Common Items in This Group ──
            Text(
              'waste_group.items_title'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.icon,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Scan Button ──
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ScanScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt_rounded),
                label: Text('waste_group.scan_button'.tr()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupItemInfo {
  const _GroupItemInfo({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
