import 'package:flutter/material.dart';

class WasteCategory {
  const WasteCategory({
    required this.id,
    required this.nameEn,
    required this.nameFr,
    required this.nameAr,
    required this.descriptionEn,
    required this.descriptionFr,
    required this.descriptionAr,
    required this.disposalInstructionEn,
    required this.disposalInstructionFr,
    required this.disposalInstructionAr,
    required this.colorHex,
  });

  final String id;
  final String nameEn;
  final String nameFr;
  final String nameAr;
  final String descriptionEn;
  final String descriptionFr;
  final String descriptionAr;
  final String disposalInstructionEn;
  final String disposalInstructionFr;
  final String disposalInstructionAr;
  final String colorHex;

  String name(Locale locale) => switch (locale.languageCode) {
        'fr' => nameFr,
        'ar' => nameAr,
        _ => nameEn,
      };

  String description(Locale locale) => switch (locale.languageCode) {
        'fr' => descriptionFr,
        'ar' => descriptionAr,
        _ => descriptionEn,
      };

  String disposalInstruction(Locale locale) => switch (locale.languageCode) {
        'fr' => disposalInstructionFr,
        'ar' => disposalInstructionAr,
        _ => disposalInstructionEn,
      };

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
}
