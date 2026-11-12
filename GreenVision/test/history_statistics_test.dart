import 'package:flutter_test/flutter_test.dart';
import 'package:waste_classification/data/models/scan_result.dart';
import 'package:waste_classification/features/history/history_statistics.dart';

void main() {
  ScanResult scan(String id, DateTime scannedAt, String categoryId) =>
      ScanResult(
        id: id,
        imagePath: '$id.png',
        scannedAt: scannedAt,
        categoryId: categoryId,
        modelLabel: 'Glass',
        confidence: 0.8,
      );

  test('day range includes today and excludes the next day', () {
    final range = HistoryPeriodRange.current(
      HistoryPeriod.day,
      DateTime(2026, 7, 14, 18, 30),
    );

    expect(range.start, DateTime(2026, 7, 14));
    expect(range.end, DateTime(2026, 7, 15));
    expect(range.contains(DateTime(2026, 7, 14, 23, 59)), isTrue);
    expect(range.contains(DateTime(2026, 7, 15)), isFalse);
  });

  test('week range starts on Monday', () {
    final range = HistoryPeriodRange.current(
      HistoryPeriod.week,
      DateTime(2026, 7, 16),
    );

    expect(range.start, DateTime(2026, 7, 13));
    expect(range.end, DateTime(2026, 7, 20));
  });

  test('month range handles the year boundary', () {
    final range = HistoryPeriodRange.current(
      HistoryPeriod.month,
      DateTime(2026, 12, 30),
    );

    expect(range.start, DateTime(2026, 12));
    expect(range.end, DateTime(2027));
  });

  test('statistics count categories only inside the selected range', () {
    final range = HistoryPeriodRange.current(
      HistoryPeriod.week,
      DateTime(2026, 7, 14),
    );
    final statistics = ScanStatistics.fromScans([
      scan('1', DateTime(2026, 7, 13, 9), 'recyclable'),
      scan('2', DateTime(2026, 7, 14, 10), 'recyclable'),
      scan('3', DateTime(2026, 7, 15, 11), 'organic'),
      scan('4', DateTime(2026, 7, 20), 'other'),
    ], range);

    expect(statistics.total, 3);
    expect(statistics.countFor('recyclable'), 2);
    expect(statistics.countFor('organic'), 1);
    expect(statistics.countFor('other'), 0);
    expect(statistics.ratioFor('recyclable'), closeTo(2 / 3, 0.0001));
  });
}
