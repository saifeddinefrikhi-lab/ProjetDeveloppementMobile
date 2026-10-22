import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:waste_classification/data/local/collection_request_repository.dart';
import 'package:waste_classification/data/models/collection_request.dart';
import 'package:waste_classification/features/auth/auth_provider.dart';
import 'package:waste_classification/features/collection/collection_request_screen.dart';
import 'package:waste_classification/services/geocoding/geocoding_service.dart';

class MyRequestsScreen extends ConsumerStatefulWidget {
  final void Function(LatLng location, String title, {String? subtitle})?
      onNavigateToMap;

  const MyRequestsScreen({
    super.key,
    this.onNavigateToMap,
  });

  @override
  ConsumerState<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<CollectionRequest> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await CollectionRequestRepository.instance.getAll();
    if (mounted) {
      setState(() {
        _all = all;
        _loading = false;
      });
    }
  }

  List<CollectionRequest> _filtered(int tabIndex, int? currentUserId) {
    switch (tabIndex) {
      case 0: // All
        return _all;
      case 1: // Pending
        return _all.where((r) => r.status == RequestStatus.pending).toList();
      case 2: // Accepted
        return _all.where((r) => r.status == RequestStatus.accepted).toList();
      case 3: // Accepted by current user
        if (currentUserId == null) return [];
        return _all.where((r) => r.acceptedByUserId == currentUserId).toList();
      case 4: // Completed
        return _all.where((r) => r.status == RequestStatus.completed).toList();
      default:
        return _all;
    }
  }

  Future<void> _accept(CollectionRequest req) async {
    final user = ref.read(authProvider).user;
    if (user == null || user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('collection.must_login_to_accept'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await CollectionRequestRepository.instance.acceptRequest(
      id: req.id,
      userId: user.id!,
      userName: user.name,
    );
    await _load();
  }

  Future<void> _complete(CollectionRequest req) async {
    await CollectionRequestRepository.instance.completeRequest(req.id);
    await _load();
  }

  Future<void> _cancel(CollectionRequest req) async {
    await CollectionRequestRepository.instance.cancelRequest(req.id);
    await _load();
  }

  Future<void> _delete(CollectionRequest req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('collection.delete_confirm_title'.tr()),
        content: Text('collection.delete_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.back'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('collection.delete_button'.tr()),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await CollectionRequestRepository.instance.delete(req.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('collection.my_requests_title'.tr()),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'collection.tab_all'.tr()),
            Tab(text: 'collection.status_pending'.tr()),
            Tab(text: 'collection.status_accepted'.tr()),
            Tab(text: 'collection.accepted_by_you'.tr()),
            Tab(text: 'collection.status_completed'.tr()),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'common.try_again'.tr(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const CollectionRequestScreen(),
            ),
          );
          if (result == true) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text('collection.new_request'.tr()),
        backgroundColor: const Color(0xFF2ECC71),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _RequestsList(
                  requests: _filtered(0, currentUser?.id),
                  currentUserId: currentUser?.id,
                  onAccept: _accept,
                  onComplete: _complete,
                  onCancel: _cancel,
                  onDelete: _delete,
                  onNavigateToMap: widget.onNavigateToMap,
                ),
                _RequestsList(
                  requests: _filtered(1, currentUser?.id),
                  currentUserId: currentUser?.id,
                  onAccept: _accept,
                  onComplete: _complete,
                  onCancel: _cancel,
                  onDelete: _delete,
                  onNavigateToMap: widget.onNavigateToMap,
                ),
                _RequestsList(
                  requests: _filtered(2, currentUser?.id),
                  currentUserId: currentUser?.id,
                  onAccept: _accept,
                  onComplete: _complete,
                  onCancel: _cancel,
                  onDelete: _delete,
                  onNavigateToMap: widget.onNavigateToMap,
                ),
                _RequestsList(
                  requests: _filtered(3, currentUser?.id),
                  currentUserId: currentUser?.id,
                  onAccept: _accept,
                  onComplete: _complete,
                  onCancel: _cancel,
                  onDelete: _delete,
                  onNavigateToMap: widget.onNavigateToMap,
                ),
                _RequestsList(
                  requests: _filtered(4, currentUser?.id),
                  currentUserId: currentUser?.id,
                  onAccept: _accept,
                  onComplete: _complete,
                  onCancel: _cancel,
                  onDelete: _delete,
                  onNavigateToMap: widget.onNavigateToMap,
                ),
              ],
            ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// List tab
// ──────────────────────────────────────────────────────────────────────────────
class _RequestsList extends StatelessWidget {
  const _RequestsList({
    required this.requests,
    required this.currentUserId,
    required this.onAccept,
    required this.onComplete,
    required this.onCancel,
    required this.onDelete,
    this.onNavigateToMap,
  });

  final List<CollectionRequest> requests;
  final int? currentUserId;
  final Future<void> Function(CollectionRequest) onAccept;
  final Future<void> Function(CollectionRequest) onComplete;
  final Future<void> Function(CollectionRequest) onCancel;
  final Future<void> Function(CollectionRequest) onDelete;
  final void Function(LatLng location, String title, {String? subtitle})?
      onNavigateToMap;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'collection.empty_requests'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _RequestCard(
        req: requests[i],
        currentUserId: currentUserId,
        onAccept: () => onAccept(requests[i]),
        onComplete: () => onComplete(requests[i]),
        onCancel: () => onCancel(requests[i]),
        onDelete: () => onDelete(requests[i]),
        onNavigateToMap: onNavigateToMap,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Card
// ──────────────────────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.req,
    required this.currentUserId,
    required this.onAccept,
    required this.onComplete,
    required this.onCancel,
    required this.onDelete,
    this.onNavigateToMap,
  });

  final CollectionRequest req;
  final int? currentUserId;
  final VoidCallback onAccept;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final void Function(LatLng location, String title, {String? subtitle})?
      onNavigateToMap;

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
    final statusColor = _statusColors[req.status] ?? colorScheme.primary;
    final statusIcon = _statusIcons[req.status] ?? Icons.info_outline;
    final date = DateTime.tryParse(req.requestedDate);
    final formatted = date != null
        ? DateFormat.yMMMd(context.locale.toString()).format(date)
        : req.requestedDate;

    final isAcceptedByMe =
        req.acceptedByUserId != null && req.acceptedByUserId == currentUserId;
    final isCreatedByMe =
        req.creatorId != null && req.creatorId == currentUserId;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAcceptedByMe
              ? const Color(0xFF3498DB).withValues(alpha: 0.6)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isAcceptedByMe ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: status + creator info + actions
            Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
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

                // Creator name tag
                if (req.creatorName != null)
                  Expanded(
                    child: Text(
                      isCreatedByMe
                          ? '(${'collection.created_by'.tr(namedArgs: {'name': 'Vous'})})'
                          : 'collection.created_by'.tr(namedArgs: {'name': req.creatorName!}),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                const Spacer(),

                // Action Menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case 'accept':
                        onAccept();
                      case 'complete':
                        onComplete();
                      case 'cancel':
                        onCancel();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    if (req.status == RequestStatus.pending)
                      PopupMenuItem(
                        value: 'accept',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.thumb_up_outlined,
                              size: 18,
                              color: Color(0xFF3498DB),
                            ),
                            const SizedBox(width: 8),
                            Text('collection.action_accept'.tr()),
                          ],
                        ),
                      ),
                    if (req.status == RequestStatus.accepted &&
                        (isAcceptedByMe || isCreatedByMe))
                      PopupMenuItem(
                        value: 'complete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.task_alt_rounded,
                              size: 18,
                              color: Color(0xFF2ECC71),
                            ),
                            const SizedBox(width: 8),
                            Text('collection.action_complete'.tr()),
                          ],
                        ),
                      ),
                    if (req.status == RequestStatus.pending ||
                        (req.status == RequestStatus.accepted &&
                            (isAcceptedByMe || isCreatedByMe)))
                      PopupMenuItem(
                        value: 'cancel',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color: Color(0xFFE74C3C),
                            ),
                            const SizedBox(width: 8),
                            Text('collection.action_cancel'.tr()),
                          ],
                        ),
                      ),
                    if (req.status == RequestStatus.completed || isCreatedByMe)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text('collection.delete_button'.tr()),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Accepted by badge (Shows which user this request is linked to)
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
                      size: 14,
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

            const SizedBox(height: 10),

            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.address,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Date
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  formatted,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            if (req.wasteTypeList.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: req.wasteTypeList.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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

            if (req.notes != null && req.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                req.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // ── Action Buttons Row ──────────────────────────────────────────
            Row(
              children: [
                // View on map button
                OutlinedButton.icon(
                  onPressed: () async {
                    if (req.latitude != null && req.longitude != null) {
                      onNavigateToMap?.call(
                        LatLng(req.latitude!, req.longitude!),
                        'collection.request_marker_title'.tr(),
                        subtitle: req.address,
                      );
                    } else {
                      final coords = await GeocodingService.instance
                          .forwardGeocode(req.address);
                      if (coords != null) {
                        onNavigateToMap?.call(
                          coords,
                          'collection.request_marker_title'.tr(),
                          subtitle: req.address,
                        );
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('collection.address_not_found'.tr()),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.map_rounded, size: 16),
                  label: Text('collection.view_on_map'.tr()),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: const Color(0xFF2ECC71),
                    side: const BorderSide(color: Color(0xFF2ECC71)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const Spacer(),

                // Fast action: Accept (if pending)
                if (req.status == RequestStatus.pending)
                  FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.thumb_up_outlined, size: 14),
                    label: Text('collection.action_accept'.tr()),
                    style: FilledButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: const Color(0xFF3498DB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                // Fast action: Complete / Confirm (if accepted by me)
                if (req.status == RequestStatus.accepted && isAcceptedByMe)
                  FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.task_alt_rounded, size: 14),
                    label: Text('collection.action_complete'.tr()),
                    style: FilledButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
    );
  }
}
