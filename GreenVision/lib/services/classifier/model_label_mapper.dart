abstract final class ModelLabelMapper {
  static const labels = <String>[
    'Cardboard',
    'Food Organics',
    'Glass',
    'Metal',
    'Miscellaneous Trash',
    'Paper',
    'Plastic',
    'Textile Trash',
    'Vegetation',
  ];

  static String categoryIdFor(String label) {
    switch (_normalize(label)) {
      case 'food organics':
      case 'vegetation':
        return 'organic';
      case 'cardboard':
      case 'glass':
      case 'metal':
      case 'paper':
      case 'plastic':
        return 'recyclable';
      case 'miscellaneous trash':
      case 'textile trash':
      default:
        return 'other';
    }
  }

  static String translationKeyFor(String label) {
    switch (_normalize(label)) {
      case 'cardboard':
        return 'labels.cardboard';
      case 'food organics':
        return 'labels.food_organics';
      case 'glass':
        return 'labels.glass';
      case 'metal':
        return 'labels.metal';
      case 'paper':
        return 'labels.paper';
      case 'plastic':
        return 'labels.plastic';
      case 'textile trash':
        return 'labels.textile_trash';
      case 'vegetation':
        return 'labels.vegetation';
      case 'miscellaneous trash':
      default:
        return 'labels.miscellaneous_trash';
    }
  }

  static String _normalize(String value) => value.trim().toLowerCase();
}
