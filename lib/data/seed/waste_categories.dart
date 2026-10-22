import 'package:waste_classification/data/models/waste_category.dart';

abstract final class WasteCategories {
  static const organic = WasteCategory(
    id: 'organic',
    nameEn: 'Organic waste',
    nameFr: 'Déchets organiques',
    nameAr: 'نفايات عضوية',
    descriptionEn: 'Waste from food or plants that can break down naturally.',
    descriptionFr:
        'Déchets d\'origine alimentaire ou végétale, naturellement biodégradables.',
    descriptionAr:
        'نفايات ناتجة عن الأطعمة أو النباتات قابلة للتحلل بيولوجياً.',
    disposalInstructionEn:
        'Remove plastic bags and contaminants. Put it in the organic bin or composting area when available.',
    disposalInstructionFr:
        'Retirez les emballages en plastique. Déposez dans le bac à compost ou la poubelle de biodéchets.',
    disposalInstructionAr:
        'أزل الأكياس البلاستيكية والملوثات، وضعها في حاوية المواد العضوية أو منطقة التسميد.',
    colorHex: '#A9D8B4',
  );

  static const recyclable = WasteCategory(
    id: 'recyclable',
    nameEn: 'Recyclable waste',
    nameFr: 'Déchets recyclables',
    nameAr: 'نفايات قابلة لإعادة التدوير',
    descriptionEn:
        'Materials that can be collected and processed into new products.',
    descriptionFr:
        'Matériaux pouvant être collectés et transformés en nouveaux produits.',
    descriptionAr: 'مواد يمكن جمعها ومعالجتها لإنتاج منتجات جديدة.',
    disposalInstructionEn:
        'Rinse away food or liquid residue, let it dry, and place it in the recycling bin.',
    disposalInstructionFr:
        'Rincez les résidus d\'aliments ou liquides, séchez et déposez dans le bac de recyclage.',
    disposalInstructionAr:
        'اشطف بقايا الطعام أو السوائل، واتركها تجف ثم ضعها في حاوية إعادة التدوير.',
    colorHex: '#F2DDA4',
  );

  static const other = WasteCategory(
    id: 'other',
    nameEn: 'Other waste',
    nameFr: 'Autres déchets',
    nameAr: 'نفايات أخرى',
    descriptionEn:
        'Waste that does not decompose easily or fit common recycling streams.',
    descriptionFr:
        'Déchets non recyclables ou ne convenant pas aux filières de tri classiques.',
    descriptionAr:
        'نفايات غير قابلة للتحلل بسهولة ولا تنتمي إلى مسارات إعادة التدوير العادية.',
    disposalInstructionEn:
        'Place it in the general waste bin. Take batteries, chemicals, or electronics to a dedicated collection point.',
    disposalInstructionFr:
        'Jetez dans le bac d\'ordures ménagères. Pour les piles ou l\'électronique, apportez-les en point de collecte.',
    disposalInstructionAr:
        'ضعها في حاوية النفايات العامة. خذ البطاريات أو الإلكترونيات إلى نقاط التجميع المخصصة.',
    colorHex: '#D6D9D5',
  );

  static const all = [organic, recyclable, other];

  static WasteCategory byId(String id) =>
      all.firstWhere((category) => category.id == id, orElse: () => other);
}
