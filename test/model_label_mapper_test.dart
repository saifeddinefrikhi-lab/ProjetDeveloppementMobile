import 'package:flutter_test/flutter_test.dart';
import 'package:waste_classification/services/classifier/model_label_mapper.dart';

void main() {
  group('ModelLabelMapper', () {
    test('maps the nine RealWaste labels into three app categories', () {
      expect(ModelLabelMapper.categoryIdFor('Food Organics'), 'organic');
      expect(ModelLabelMapper.categoryIdFor('Vegetation'), 'organic');

      for (final label in ['Cardboard', 'Glass', 'Metal', 'Paper', 'Plastic']) {
        expect(ModelLabelMapper.categoryIdFor(label), 'recyclable');
      }

      expect(ModelLabelMapper.categoryIdFor('Miscellaneous Trash'), 'other');
      expect(ModelLabelMapper.categoryIdFor('Textile Trash'), 'other');
    });

    test('normalizes case and safely falls back for an unknown label', () {
      expect(ModelLabelMapper.categoryIdFor('  pLaStIc  '), 'recyclable');
      expect(ModelLabelMapper.categoryIdFor('unknown'), 'other');
      expect(
        ModelLabelMapper.translationKeyFor('unknown'),
        'labels.miscellaneous_trash',
      );
    });
  });
}
