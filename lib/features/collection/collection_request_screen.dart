import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:waste_classification/data/local/collection_request_repository.dart';
import 'package:waste_classification/data/models/collection_request.dart';
import 'package:waste_classification/features/auth/auth_provider.dart';
import 'package:waste_classification/services/geocoding/geocoding_service.dart';

class CollectionRequestScreen extends ConsumerStatefulWidget {
  const CollectionRequestScreen({super.key});

  @override
  ConsumerState<CollectionRequestScreen> createState() =>
      _CollectionRequestScreenState();
}

class _CollectionRequestScreenState
    extends ConsumerState<CollectionRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  final Set<String> _selectedWasteTypes = {};
  bool _submitting = false;
  bool _locatingAddress = false;
  double? _gpsLatitude;
  double? _gpsLongitude;

  static const _wasteOptions = [
    ('plastic', '♻️', 'collection.waste_plastic'),
    ('glass', '🍶', 'collection.waste_glass'),
    ('paper', '📄', 'collection.waste_paper'),
    ('batteries', '🔋', 'collection.waste_batteries'),
    ('metal', '🔩', 'collection.waste_metal'),
    ('organic', '🌿', 'collection.waste_organic'),
    ('textile', '👕', 'collection.waste_textile'),
    ('electronics', '📱', 'collection.waste_electronics'),
  ];

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fillAddressFromGps() async {
    final lang = context.locale.languageCode;
    setState(() => _locatingAddress = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack('map.location_disabled'.tr());
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('map.location_denied'.tr());
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _gpsLatitude = pos.latitude;
      _gpsLongitude = pos.longitude;

      // Reverse geocode to get the full human-readable address
      final fullAddress = await GeocodingService.instance.reverseGeocode(
        pos.latitude,
        pos.longitude,
        languageCode: lang,
      );

      if (mounted) {
        if (fullAddress != null && fullAddress.isNotEmpty) {
          _addressController.text = fullAddress;
        } else {
          _addressController.text =
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        }
      }
    } catch (e) {
      _snack('map.location_error'.tr(namedArgs: {'error': e.toString()}));
    } finally {
      if (mounted) setState(() => _locatingAddress = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2ECC71),
            brightness: Theme.of(ctx).brightness,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWasteTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('collection.select_waste_error'.tr()),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      double? lat = _gpsLatitude;
      double? lon = _gpsLongitude;

      // If user typed address manually, try forward geocoding to attach coordinates
      if (lat == null || lon == null) {
        final resolved = await GeocodingService.instance
            .forwardGeocode(_addressController.text.trim());
        if (resolved != null) {
          lat = resolved.latitude;
          lon = resolved.longitude;
        }
      }

      final currentUser = ref.read(authProvider).user;
      final req = CollectionRequest(
        id: const Uuid().v4(),
        address: _addressController.text.trim(),
        latitude: lat,
        longitude: lon,
        wasteTypes: _selectedWasteTypes.join(','),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        requestedDate: _selectedDate.toIso8601String(),
        status: RequestStatus.pending,
        createdAt: DateTime.now().toIso8601String(),
        creatorId: currentUser?.id,
        creatorName: currentUser?.name,
      );
      await CollectionRequestRepository.instance.insert(req);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('collection.submit_success'.tr()),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateStr = DateFormat.yMMMMd(context.locale.toString()).format(_selectedDate);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('collection.new_request_title'.tr()),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // ── Address ──────────────────────────────────────────────
              _SectionHeader(label: 'collection.address_section'.tr()),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: 'collection.address_hint'.tr(),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                ),
                maxLines: 2,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'collection.address_required'.tr()
                    : null,
              ),
              const SizedBox(height: 6),
              // GPS fill button & coordinate badge
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _locatingAddress ? null : _fillAddressFromGps,
                    icon: _locatingAddress
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 16),
                    label: Text(
                      _locatingAddress
                          ? 'collection.locating_address'.tr()
                          : 'collection.use_gps'.tr(),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2ECC71),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const Spacer(),
                  if (_gpsLatitude != null && _gpsLongitude != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '📍 ${_gpsLatitude!.toStringAsFixed(4)}, ${_gpsLongitude!.toStringAsFixed(4)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF2ECC71),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Waste types ──────────────────────────────────────────
              _SectionHeader(label: 'collection.waste_section'.tr()),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _wasteOptions.map((opt) {
                  final (key, emoji, labelKey) = opt;
                  final selected = _selectedWasteTypes.contains(key);
                  return GestureDetector(
                    onTap: () => setState(() {
                      selected
                          ? _selectedWasteTypes.remove(key)
                          : _selectedWasteTypes.add(key);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            labelKey.tr(),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: selected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // ── Preferred Date ───────────────────────────────────────
              _SectionHeader(label: 'collection.date_section'.tr()),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        dateStr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down_rounded),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Notes ────────────────────────────────────────────────
              _SectionHeader(label: 'collection.notes_section'.tr()),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'collection.notes_hint'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // ── Submit ───────────────────────────────────────────────
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'collection.submit_button'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
