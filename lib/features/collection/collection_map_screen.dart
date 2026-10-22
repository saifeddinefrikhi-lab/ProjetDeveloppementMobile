import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:waste_classification/data/local/collection_request_repository.dart';
import 'package:waste_classification/data/models/collection_request.dart';
import 'package:waste_classification/features/auth/auth_provider.dart';
import 'package:waste_classification/services/geocoding/geocoding_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────────────────────────────────────
class CollectionMapScreen extends ConsumerStatefulWidget {
  final LatLng? focusLocation;
  final String? focusTitle;
  final String? focusSubtitle;
  final VoidCallback? onClearFocus;

  const CollectionMapScreen({
    super.key,
    this.focusLocation,
    this.focusTitle,
    this.focusSubtitle,
    this.onClearFocus,
  });

  @override
  ConsumerState<CollectionMapScreen> createState() =>
      _CollectionMapScreenState();
}

class _CollectionMapScreenState extends ConsumerState<CollectionMapScreen> {
  // Default fallback center (Tunis / North Africa region)
  static const _defaultCenter = LatLng(36.8065, 10.1815);
  static const _defaultZoom = 13.0;

  final MapController _mapController = MapController();
  LatLng? _userLocation;
  bool _locating = false;
  bool _loading = true;

  List<CollectionRequest> _requests = [];
  String _statusFilter = 'all'; // 'all', 'pending', 'accepted', 'completed'
  String _wasteFilter = 'all';

  CollectionRequest? _selectedRequest;

  static const _statusColors = {
    RequestStatus.pending: Color(0xFFF39C12),
    RequestStatus.accepted: Color(0xFF3498DB),
    RequestStatus.completed: Color(0xFF2ECC71),
    RequestStatus.cancelled: Color(0xFFE74C3C),
  };

  static const _statusIcons = {
    RequestStatus.pending: Icons.hourglass_top_rounded,
    RequestStatus.accepted: Icons.check_circle_outline_rounded,
    RequestStatus.completed: Icons.task_alt_rounded,
    RequestStatus.cancelled: Icons.cancel_outlined,
  };

  static const _wasteCategories = [
    ('all', '🗺️', 'map.filter_all'),
    ('plastic', '♻️', 'collection.waste_plastic'),
    ('glass', '🍶', 'collection.waste_glass'),
    ('paper', '📄', 'collection.waste_paper'),
    ('batteries', '🔋', 'collection.waste_batteries'),
    ('electronics', '📱', 'collection.waste_electronics'),
    ('metal', '🔩', 'collection.waste_metal'),
  ];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void didUpdateWidget(CollectionMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusLocation != null &&
        widget.focusLocation != oldWidget.focusLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.focusLocation != null) {
          _mapController.move(widget.focusLocation!, 16.0);
        }
      });
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    try {
      final list = await CollectionRequestRepository.instance.getAll();

      // Geocode any request that doesn't have coordinates yet
      for (int i = 0; i < list.length; i++) {
        final req = list[i];
        if (req.latitude == null || req.longitude == null) {
          final coords =
              await GeocodingService.instance.forwardGeocode(req.address);
          if (coords != null) {
            final updated = req.copyWith(
              latitude: coords.latitude,
              longitude: coords.longitude,
            );
            list[i] = updated;
            await CollectionRequestRepository.instance.insert(updated);
          }
        }
      }

      if (mounted) {
        setState(() {
          _requests = list;
          _loading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (widget.focusLocation != null) {
            _mapController.move(widget.focusLocation!, 16.0);
          } else {
            final withCoords =
                _requests.where((r) => r.latitude != null && r.longitude != null);
            if (withCoords.isNotEmpty) {
              final first = withCoords.first;
              _mapController.move(
                LatLng(first.latitude!, first.longitude!),
                14.0,
              );
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CollectionRequest> get _filteredRequests {
    return _requests.where((r) {
      if (r.latitude == null || r.longitude == null) return false;

      if (_statusFilter != 'all' && r.status.name != _statusFilter) {
        return false;
      }

      if (_wasteFilter != 'all' && !r.wasteTypeList.contains(_wasteFilter)) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _acceptRequest(CollectionRequest req) async {
    final user = ref.read(authProvider).user;
    if (user == null || user.id == null) {
      _snack('collection.must_login_to_accept'.tr());
      return;
    }

    await CollectionRequestRepository.instance.acceptRequest(
      id: req.id,
      userId: user.id!,
      userName: user.name,
    );
    await _loadRequests();
    setState(() {
      _selectedRequest = _requests.firstWhere(
        (r) => r.id == req.id,
        orElse: () => req,
      );
    });
  }

  Future<void> _completeRequest(CollectionRequest req) async {
    await CollectionRequestRepository.instance.completeRequest(req.id);
    await _loadRequests();
    setState(() {
      _selectedRequest = _requests.firstWhere(
        (r) => r.id == req.id,
        orElse: () => req,
      );
    });
  }

  // ── GPS ────────────────────────────────────────────────────────────────────
  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack('map.location_disabled'.tr());
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _snack('map.location_denied'.tr());
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _snack('map.location_denied_forever'.tr());
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _userLocation = latLng);
      _mapController.move(latLng, 15.0);
    } catch (e) {
      _snack('map.location_error'.tr(namedArgs: {'error': e.toString()}));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openGoogleMaps(LatLng destination) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${destination.latitude},${destination.longitude}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _snack('Could not open Google Maps');
    }
  }

  void _selectRequest(CollectionRequest req) {
    setState(() {
      _selectedRequest = _selectedRequest?.id == req.id ? null : req;
    });
    if (_selectedRequest != null &&
        req.latitude != null &&
        req.longitude != null) {
      _mapController.move(LatLng(req.latitude!, req.longitude!), 15.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filteredRequests;
    final hasFocus = widget.focusLocation != null;
    final currentUser = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // ── Flutter Map ────────────────────────────────────────────────
              Positioned.fill(
                child: RepaintBoundary(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: widget.focusLocation ?? _defaultCenter,
                      initialZoom: hasFocus ? 16.0 : _defaultZoom,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onTap: (_, _) => setState(() => _selectedRequest = null),
                    ),
                    children: [
                      // OpenStreetMap tiles
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.saiffrikhi.waste_classification',
                        maxZoom: 19,
                      ),

                      // User Collection Request Markers
                      MarkerLayer(
                        markers: filtered.map((req) {
                          final isSelected = _selectedRequest?.id == req.id;
                          final isMine = req.acceptedByUserId != null &&
                              req.acceptedByUserId == currentUser?.id;
                          final statusColor = _statusColors[req.status] ??
                              const Color(0xFF2ECC71);

                          return Marker(
                            point: LatLng(req.latitude!, req.longitude!),
                            width: isSelected ? 56 : 46,
                            height: isSelected ? 56 : 46,
                            child: GestureDetector(
                              onTap: () => _selectRequest(req),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isMine ? Colors.amberAccent : Colors.white,
                                    width: isSelected ? 3.5 : (isMine ? 3.0 : 2.0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withValues(alpha: 0.5),
                                      blurRadius: isSelected ? 16 : 8,
                                      spreadRadius: isSelected ? 4 : 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _statusIcons[req.status] ??
                                      Icons.local_shipping_rounded,
                                  color: Colors.white,
                                  size: isSelected ? 26 : 22,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Focused request marker
                      if (widget.focusLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: widget.focusLocation!,
                              width: 60,
                              height: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE67E22),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE67E22)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 18,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ],
                        ),

                      // User GPS position
                      if (_userLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _userLocation!,
                              width: 44,
                              height: 44,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade600,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withValues(alpha: 0.5),
                                      blurRadius: 14,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.person_pin_circle_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),

                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Top overlay: title + filters ───────────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 0,
                right: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Material(
                        elevation: 4,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                        color: colorScheme.surface.withValues(alpha: 0.95),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.map_rounded,
                                color: colorScheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'collection.my_requests_title'.tr(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: _loading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh_rounded, size: 20),
                                onPressed: _loading ? null : _loadRequests,
                                visualDensity: VisualDensity.compact,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2ECC71)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${filtered.length} pts',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF2ECC71),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Filter chips
                    SizedBox(
                      height: 38,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FilterChip(
                            label: 'collection.tab_all'.tr(),
                            selected: _statusFilter == 'all',
                            onTap: () => setState(() {
                              _statusFilter = 'all';
                              _selectedRequest = null;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: 'collection.status_pending'.tr(),
                            color: const Color(0xFFF39C12),
                            selected: _statusFilter == 'pending',
                            onTap: () => setState(() {
                              _statusFilter = 'pending';
                              _selectedRequest = null;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: 'collection.status_accepted'.tr(),
                            color: const Color(0xFF3498DB),
                            selected: _statusFilter == 'accepted',
                            onTap: () => setState(() {
                              _statusFilter = 'accepted';
                              _selectedRequest = null;
                            }),
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: 'collection.status_completed'.tr(),
                            color: const Color(0xFF2ECC71),
                            selected: _statusFilter == 'completed',
                            onTap: () => setState(() {
                              _statusFilter = 'completed';
                              _selectedRequest = null;
                            }),
                          ),
                          const VerticalDivider(width: 16, thickness: 1),
                          ..._wasteCategories.map((cat) {
                            final (key, emoji, labelKey) = cat;
                            if (key == 'all') return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _FilterChip(
                                label: '$emoji ${labelKey.tr()}',
                                selected: _wasteFilter == key,
                                onTap: () => setState(() {
                                  _wasteFilter = _wasteFilter == key ? 'all' : key;
                                  _selectedRequest = null;
                                }),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Focused request card (when navigated from Collection) ──────
              if (hasFocus)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 16,
                  child: Material(
                    elevation: 10,
                    shadowColor: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                    color: colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFE67E22).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFFE67E22),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.focusTitle ??
                                      'collection.request_marker_title'.tr(),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (widget.focusSubtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.focusSubtitle!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onClearFocus != null)
                                IconButton(
                                  onPressed: widget.onClearFocus,
                                  icon: const Icon(Icons.close_rounded),
                                  color: colorScheme.onSurfaceVariant,
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                ),
                              FilledButton.icon(
                                onPressed: () =>
                                    _openGoogleMaps(widget.focusLocation!),
                                icon: const Icon(Icons.navigation_rounded, size: 16),
                                label: Text('map.navigate'.tr()),
                                style: FilledButton.styleFrom(
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: const Color(0xFFE67E22),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  textStyle: const TextStyle(fontSize: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Selected Request detail card (bottom) ──────────────────────
              if (_selectedRequest != null && !hasFocus)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 16,
                  child: _RequestDetailCard(
                    req: _selectedRequest!,
                    currentUserId: currentUser?.id,
                    onAccept: () => _acceptRequest(_selectedRequest!),
                    onComplete: () => _completeRequest(_selectedRequest!),
                    onNavigate: () => _openGoogleMaps(
                      LatLng(
                        _selectedRequest!.latitude!,
                        _selectedRequest!.longitude!,
                      ),
                    ),
                    onClose: () => setState(() => _selectedRequest = null),
                  ),
                ),

              // ── FAB: My Location & Zoom ────────────────────────────────────
              Positioned(
                right: 16,
                bottom: (_selectedRequest != null || hasFocus) ? 200 : 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'zoom_in',
                      onPressed: () {
                        final zoom = _mapController.camera.zoom;
                        _mapController.move(
                          _mapController.camera.center,
                          (zoom + 1).clamp(1, 19),
                        );
                      },
                      backgroundColor: colorScheme.surface,
                      foregroundColor: colorScheme.onSurface,
                      elevation: 4,
                      child: const Icon(Icons.add_rounded),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'zoom_out',
                      onPressed: () {
                        final zoom = _mapController.camera.zoom;
                        _mapController.move(
                          _mapController.camera.center,
                          (zoom - 1).clamp(1, 19),
                        );
                      },
                      backgroundColor: colorScheme.surface,
                      foregroundColor: colorScheme.onSurface,
                      elevation: 4,
                      child: const Icon(Icons.remove_rounded),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: 'my_location',
                      onPressed: _locating ? null : _goToMyLocation,
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      elevation: 6,
                      child: _locating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.my_location_rounded),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Filter Chip Component
// ──────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeColor = color ?? const Color(0xFF2ECC71);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? activeColor
              : colorScheme.surface.withValues(alpha: 0.92),
          border: Border.all(
            color: selected ? activeColor : colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected ? Colors.white : colorScheme.onSurface,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Selected Request Detail Card
// ──────────────────────────────────────────────────────────────────────────────
class _RequestDetailCard extends StatelessWidget {
  const _RequestDetailCard({
    required this.req,
    required this.currentUserId,
    required this.onAccept,
    required this.onComplete,
    required this.onNavigate,
    required this.onClose,
  });

  final CollectionRequest req;
  final int? currentUserId;
  final VoidCallback onAccept;
  final VoidCallback onComplete;
  final VoidCallback onNavigate;
  final VoidCallback onClose;

  static const _statusColors = {
    RequestStatus.pending: Color(0xFFF39C12),
    RequestStatus.accepted: Color(0xFF3498DB),
    RequestStatus.completed: Color(0xFF2ECC71),
    RequestStatus.cancelled: Color(0xFFE74C3C),
  };

  static const _statusIcons = {
    RequestStatus.pending: Icons.hourglass_top_rounded,
    RequestStatus.accepted: Icons.check_circle_outline_rounded,
    RequestStatus.completed: Icons.task_alt_rounded,
    RequestStatus.cancelled: Icons.cancel_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _statusColors[req.status] ?? const Color(0xFF2ECC71);
    final statusIcon = _statusIcons[req.status] ?? Icons.info_outline;

    final date = DateTime.tryParse(req.requestedDate);
    final formattedDate = date != null
        ? DateFormat.yMMMd(context.locale.toString()).format(date)
        : req.requestedDate;

    final isAcceptedByMe =
        req.acceptedByUserId != null && req.acceptedByUserId == currentUserId;

    return Material(
      elevation: 10,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(20),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: status badge + creator + date + close button
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        req.status.translationKey.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  color: colorScheme.onSurfaceVariant,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            // Accepted by badge (if accepted)
            if (req.acceptedByUserId != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAcceptedByMe
                      ? const Color(0xFF3498DB).withValues(alpha: 0.15)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAcceptedByMe
                          ? Icons.person_pin_rounded
                          : Icons.account_circle_outlined,
                      size: 13,
                      color: isAcceptedByMe
                          ? const Color(0xFF3498DB)
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAcceptedByMe
                          ? 'collection.accepted_by_you'.tr()
                          : 'collection.accepted_by'.tr(
                              namedArgs: {
                                'name': req.acceptedByUserName ?? 'un utilisateur',
                              },
                            ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isAcceptedByMe
                            ? const Color(0xFF3498DB)
                            : colorScheme.onSurfaceVariant,
                        fontWeight:
                            isAcceptedByMe ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Address + Navigate button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.address,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation_rounded, size: 16),
                  label: Text('map.navigate'.tr()),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),

            // Waste types chips
            if (req.wasteTypeList.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: req.wasteTypeList.map((t) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'collection.waste_$t'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Notes if any
            if (req.notes != null && req.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                req.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Link/Action Button ──────────────────────────────────────────
            if (req.status == RequestStatus.pending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.thumb_up_outlined, size: 16),
                  label: Text('collection.action_accept'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],

            if (req.status == RequestStatus.accepted && isAcceptedByMe) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.task_alt_rounded, size: 16),
                  label: Text('collection.action_complete'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
