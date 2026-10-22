import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waste_classification/core/theme/app_colors.dart';
import 'package:waste_classification/core/widgets/waste_category_icon.dart';
import 'package:waste_classification/data/local/scan_repository.dart';
import 'package:waste_classification/data/models/scan_result.dart';
import 'package:waste_classification/data/seed/waste_categories.dart';
import 'package:waste_classification/features/auth/auth_provider.dart';
import 'package:waste_classification/features/history/history_statistics.dart';
import 'package:waste_classification/features/scan/scan_screen.dart';
import 'package:waste_classification/services/classifier/model_label_mapper.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<ScanResult>? _scans;
  Object? _loadError;
  HistoryPeriod _period = HistoryPeriod.week;

  @override
  void initState() {
    super.initState();
    scanRepository.revision.addListener(_loadScans);
    _loadScans();
  }

  @override
  void dispose() {
    scanRepository.revision.removeListener(_loadScans);
    super.dispose();
  }

  Future<void> _loadScans() async {
    try {
      final user = ref.read(authProvider).user;
      final scans = await scanRepository.getByUser(user?.id);
      if (!mounted) return;
      setState(() {
        _scans = scans;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  void _openScan() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ScanScreen()));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, _) => _loadScans());

    return Scaffold(
      appBar: AppBar(title: Text('history.title'.tr())),
      body: _loadError != null
          ? _HistoryError(onRetry: _loadScans)
          : _scans == null
          ? const Center(child: CircularProgressIndicator())
          : _HistoryContent(
              scans: _scans!,
              period: _period,
              onPeriodChanged: (period) => setState(() => _period = period),
              onRefresh: _loadScans,
              onStartScan: _openScan,
            ),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.scans,
    required this.period,
    required this.onPeriodChanged,
    required this.onRefresh,
    required this.onStartScan,
  });

  final List<ScanResult> scans;
  final HistoryPeriod period;
  final ValueChanged<HistoryPeriod> onPeriodChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onStartScan;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final range = HistoryPeriodRange.current(period, now);
    final statistics = ScanStatistics.fromScans(scans, range);
    final children = <Widget>[
      Text(
        'history.statistics_title'.tr(),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      Text(
        _formatRange(context, range, period),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 14),
      _PeriodSelector(selected: period, onChanged: onPeriodChanged),
      const SizedBox(height: 16),
      _StatisticsCard(statistics: statistics),
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(
            child: Text(
              'history.scan_history_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Text(
            'history.scan_count'.tr(
              namedArgs: {'count': scans.length.toString()},
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      const SizedBox(height: 14),
    ];

    if (scans.isEmpty) {
      children.add(_EmptyHistory(onStartScan: onStartScan));
    } else {
      for (var index = 0; index < scans.length; index++) {
        final scan = scans[index];
        final startsNewDay =
            index == 0 ||
            !DateUtils.isSameDay(scans[index - 1].scannedAt, scan.scannedAt);
        if (startsNewDay) {
          if (index > 0) children.add(const SizedBox(height: 10));
          children.add(_DateHeading(date: scan.scannedAt));
          children.add(const SizedBox(height: 8));
        }
        children.add(_HistoryTile(scan: scan));
        children.add(const SizedBox(height: 10));
      }
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: children,
      ),
    );
  }

  String _formatRange(
    BuildContext context,
    HistoryPeriodRange range,
    HistoryPeriod period,
  ) {
    final localizations = MaterialLocalizations.of(context);
    return switch (period) {
      HistoryPeriod.day => localizations.formatMediumDate(range.start),
      HistoryPeriod.week =>
        '${localizations.formatShortDate(range.start)} – '
            '${localizations.formatShortDate(range.end.subtract(const Duration(days: 1)))}',
      HistoryPeriod.month => localizations.formatMonthYear(range.start),
    };
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});

  final HistoryPeriod selected;
  final ValueChanged<HistoryPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<HistoryPeriod>(
        segments: [
          ButtonSegment(
            value: HistoryPeriod.day,
            label: Text('history.period_day'.tr()),
            icon: const Icon(Icons.today_outlined),
          ),
          ButtonSegment(
            value: HistoryPeriod.week,
            label: Text('history.period_week'.tr()),
            icon: const Icon(Icons.date_range_outlined),
          ),
          ButtonSegment(
            value: HistoryPeriod.month,
            label: Text('history.period_month'.tr()),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onChanged(selection.first),
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(
            Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({required this.statistics});

  final ScanStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final categories = WasteCategories.all;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 118,
                height: 118,
                child: CustomPaint(
                  painter: _DistributionPainter(
                    counts: categories
                        .map((item) => statistics.countFor(item.id))
                        .toList(growable: false),
                    colors: categories
                        .map((item) => item.color)
                        .toList(growable: false),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          statistics.total.toString(),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          'history.total_scans'.tr(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    for (final category in categories)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: _LegendRow(
                          color: category.color,
                          label: category.name(context.locale),
                          count: statistics.countFor(category.id),
                          ratio: statistics.ratioFor(category.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (statistics.total == 0) ...[
            const SizedBox(height: 14),
            Text(
              'history.no_period_data'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.count,
    required this.ratio,
  });

  final Color color;
  final String label;
  final int count;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count · ${(ratio * 100).round()}%',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DistributionPainter extends CustomPainter {
  const _DistributionPainter({required this.counts, required this.colors});

  final List<int> counts;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2 - 9;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, paint..color = AppColors.primaryLight);

    final total = counts.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return;
    var start = -math.pi / 2;
    for (var index = 0; index < counts.length; index++) {
      if (counts[index] == 0) continue;
      final sweep = math.pi * 2 * counts[index] / total;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint..color = colors[index],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DistributionPainter oldDelegate) =>
      !_listEquals(oldDelegate.counts, counts) ||
      !_listEquals(oldDelegate.colors, colors);

  bool _listEquals<T>(List<T> first, List<T> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}

class _DateHeading extends StatelessWidget {
  const _DateHeading({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final label = DateUtils.isSameDay(date, today)
        ? 'history.today'.tr()
        : DateUtils.isSameDay(date, yesterday)
        ? 'history.yesterday'.tr()
        : MaterialLocalizations.of(context).formatMediumDate(date);
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.scan});

  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    final category = WasteCategories.byId(scan.categoryId);
    final confidence = (scan.confidence.clamp(0, 1) * 100).round();
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(scan.scannedAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final modelLabel = ModelLabelMapper.translationKeyFor(scan.modelLabel).tr();

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HistoryDetailScreen(scan: scan),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Image.file(
                    File(scan.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: category.color.withValues(alpha: 0.65),
                      child: WasteCategoryIcon(
                        categoryId: category.id,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modelLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category.name(context.locale),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$confidence%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({required this.scan, super.key});

  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    final category = WasteCategories.byId(scan.categoryId);
    final confidence = scan.confidence.clamp(0, 1).toDouble();
    final modelLabel = ModelLabelMapper.translationKeyFor(scan.modelLabel).tr();
    final localizations = MaterialLocalizations.of(context);
    final scannedAt =
        '${localizations.formatFullDate(scan.scannedAt)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(scan.scannedAt), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';

    return Scaffold(
      appBar: AppBar(title: Text('history.detail_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(
                File(scan.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: category.color.withValues(alpha: 0.65),
                  child: WasteCategoryIcon(categoryId: category.id, size: 52),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: WasteCategoryIcon(categoryId: category.id, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name(context.locale),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(modelLabel),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DetailRow(
            icon: Icons.schedule_rounded,
            title: 'history.scanned_at'.tr(),
            value: scannedAt,
          ),
          const SizedBox(height: 18),
          _DetailRow(
            icon: Icons.analytics_outlined,
            title: 'result.confidence_title'.tr(),
            value: 'result.confidence_value'.tr(
              namedArgs: {'value': (confidence * 100).round().toString()},
            ),
            progress: confidence,
          ),
          const SizedBox(height: 18),
          _DetailRow(
            icon: Icons.recycling_rounded,
            title: 'result.disposal_title'.tr(),
            value: category.disposalInstruction(context.locale),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
    this.progress,
  });

  final IconData icon;
  final String title;
  final String value;
  final double? progress;

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
        const SizedBox(height: 9),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
        if (progress != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: progress, minHeight: 9),
          ),
        ],
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onStartScan});

  final VoidCallback onStartScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            size: 48,
            color: AppColors.primaryDark,
          ),
          const SizedBox(height: 12),
          Text(
            'history.empty_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'history.empty_description'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onStartScan,
            icon: const Icon(Icons.camera_alt_rounded),
            label: Text('home.scan_action'.tr()),
          ),
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_toggle_off_rounded,
              size: 52,
              color: AppColors.errorText,
            ),
            const SizedBox(height: 14),
            Text(
              'history.load_error'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              child: Text('common.try_again'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
