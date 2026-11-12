import 'package:waste_classification/data/models/scan_result.dart';

enum HistoryPeriod { day, week, month }

class HistoryPeriodRange {
  const HistoryPeriodRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) =>
      !value.isBefore(start) && value.isBefore(end);

  factory HistoryPeriodRange.current(HistoryPeriod period, DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return switch (period) {
      HistoryPeriod.day => HistoryPeriodRange(
        start: day,
        end: day.add(const Duration(days: 1)),
      ),
      HistoryPeriod.week => () {
        final start = day.subtract(Duration(days: day.weekday - 1));
        return HistoryPeriodRange(
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      }(),
      HistoryPeriod.month => HistoryPeriodRange(
        start: DateTime(now.year, now.month),
        end: DateTime(now.year, now.month + 1),
      ),
    };
  }
}

class ScanStatistics {
  const ScanStatistics({required this.total, required this.categoryCounts});

  final int total;
  final Map<String, int> categoryCounts;

  int countFor(String categoryId) => categoryCounts[categoryId] ?? 0;

  double ratioFor(String categoryId) =>
      total == 0 ? 0 : countFor(categoryId) / total;

  factory ScanStatistics.fromScans(
    Iterable<ScanResult> scans,
    HistoryPeriodRange range,
  ) {
    final counts = <String, int>{};
    var total = 0;
    for (final scan in scans) {
      if (!range.contains(scan.scannedAt)) continue;
      total++;
      counts.update(scan.categoryId, (value) => value + 1, ifAbsent: () => 1);
    }
    return ScanStatistics(total: total, categoryCounts: counts);
  }
}
