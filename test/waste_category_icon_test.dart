import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_classification/core/widgets/waste_category_icon.dart';

void main() {
  test('uses a distinct Material icon for each waste category', () {
    expect(WasteCategoryIcon.iconFor('organic'), Icons.eco_rounded);
    expect(WasteCategoryIcon.iconFor('recyclable'), Icons.recycling_rounded);
    expect(WasteCategoryIcon.iconFor('other'), Icons.delete_outline_rounded);
  });

  test('falls back to the other-waste icon for an unknown category', () {
    expect(WasteCategoryIcon.iconFor('unknown'), Icons.delete_outline_rounded);
  });
}
