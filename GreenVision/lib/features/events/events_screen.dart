import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:waste_classification/core/config/app_config.dart';
import 'package:waste_classification/core/theme/app_colors.dart';
import 'package:waste_classification/data/local/auth_preferences.dart';
import 'package:waste_classification/data/models/ecological_event.dart';
import 'package:waste_classification/features/auth/auth_provider.dart';
import 'package:waste_classification/services/events/backend_event_service.dart';
import 'package:waste_classification/services/geocoding/geocoding_service.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});
  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final _service = BackendEventService(baseUrl: AppConfig.apiBaseUrl);
  late Future<List<EcologicalEvent>> _events;

  @override
  void initState() {
    super.initState();
    _events = _load();
  }

  Future<List<EcologicalEvent>> _load() async {
    final token = await authPreferences.getAccessToken();
    if (token == null || token.isEmpty) throw Exception('not_logged_in');
    return _service.list(accessToken: token);
  }

  Future<void> _refresh() async {
    final future = _load();
    if (!mounted) return;
    setState(() => _events = future);
    await future;
  }

  Future<void> _create() async {
    final created = await showDialog<EcologicalEvent>(
      context: context,
      builder: (_) => _CreateEventDialog(service: _service),
    );
    if (created != null && mounted) {
      setState(() {
        _events = _events.then((events) => [...events, created]);
      });
    }
  }

  Future<void> _edit(EcologicalEvent event) async {
    final updated = await showDialog<EcologicalEvent>(
      context: context,
      builder: (_) => _CreateEventDialog(service: _service, event: event),
    );
    if (updated != null && mounted) {
      setState(() {
        _events = _events.then(
          (events) => events
              .map((item) => item.id == updated.id ? updated : item)
              .toList(),
        );
      });
    }
  }

  Future<void> _delete(EcologicalEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('events.delete_title'.tr()),
        content: Text('events.delete_confirmation'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('events.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final token = await authPreferences.getAccessToken();
    if (token == null || token.isEmpty) return;
    try {
      await _service.delete(accessToken: token, eventId: event.id);
      if (mounted) {
        setState(() {
          _events = _events.then(
            (events) => events.where((item) => item.id != event.id).toList(),
          );
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _toggle(EcologicalEvent event) async {
    final token = await authPreferences.getAccessToken();
    if (token == null || token.isEmpty) return;
    try {
      final updated = await _service.register(
        accessToken: token,
        eventId: event.id,
        registered: !event.isRegistered,
      );
      if (mounted) {
        setState(() {
          _events = _events.then(
            (events) => events
                .map((item) => item.id == updated.id ? updated : item)
                .toList(),
          );
        });
      }

    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _showParticipants(EcologicalEvent event) async {
    final token = await authPreferences.getAccessToken();
    if (token == null || token.isEmpty) return;
    var participants = await _service.participants(
      accessToken: token,
      eventId: event.id,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('events.participants_title'.tr()),
          content: SizedBox(
            width: 420,
            child: participants.isEmpty
                ? Text('events.no_participants'.tr())
                : ListView(
                    shrinkWrap: true,
                    children: participants.map((participant) {
                      return ListTile(
                        title: Text(participant.name),
                        subtitle: Text(
                          participant.attended == null
                              ? 'events.attendance_not_marked'.tr()
                              : participant.attended!
                              ? 'events.present'.tr()
                              : 'events.absent'.tr(),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'events.present'.tr(),
                              color: Colors.green,
                              icon: const Icon(Icons.check_circle_outline),
                              onPressed: () async {
                                final updated = await _service.updateAttendance(
                                  accessToken: token,
                                  eventId: event.id,
                                  userId: participant.userId,
                                  attended: true,
                                );
                                setDialogState(() => participants = updated);
                              },
                            ),
                            IconButton(
                              tooltip: 'events.absent'.tr(),
                              color: Colors.red,
                              icon: const Icon(Icons.cancel_outlined),
                              onPressed: () async {
                                final updated = await _service.updateAttendance(
                                  accessToken: token,
                                  eventId: event.id,
                                  userId: participant.userId,
                                  attended: false,
                                );
                                setDialogState(() => participants = updated);
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('common.back'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _closeEvent(EcologicalEvent event) async {
    final token = await authPreferences.getAccessToken();
    if (token == null || token.isEmpty || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('events.close_title'.tr()),
        content: Text('events.close_confirmation'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('events.close'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = await _service.close(
      accessToken: token,
      eventId: event.id,
    );
    if (!mounted) return;
    setState(() {
      _events = _events.then(
        (events) => events
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('events.title'.tr()),
      actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        IconButton(
          onPressed: _create,
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'events.add'.tr(),
        ),
      ],
    ),
    body: FutureBuilder<List<EcologicalEvent>>(
      future: _events,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton(
              onPressed: _refresh,
              child: Text('common.try_again'.tr()),
            ),
          );
        }
        final currentUserId = ref.read(authProvider).user?.id;
        final events = snapshot.data ?? const <EcologicalEvent>[];
        if (events.isEmpty) {
          return Center(
            child: Text('events.empty'.tr()),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _EventCard(
              event: events[index],
              onView: () => _showEventDetails(events[index]),
              isOwner: events[index].organizerId == currentUserId,
              onEdit: () => _edit(events[index]),
              onDelete: () => _delete(events[index]),
              onParticipants: () => _showParticipants(events[index]),
              onClose: () => _closeEvent(events[index]),
              onRegister:
                  events[index].status == EventStatus.planned &&
                      (events[index].isRegistered || !events[index].isFull)
                  ? () => _toggle(events[index])
                  : null,
            ),
          ),
        );
      },
    ),
  );

  Future<void> _showEventDetails(EcologicalEvent event) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(event.description),
              const SizedBox(height: 16),
              Text('${'events.type'.tr()}: ${_eventTypeLabel(event.type)}'),
              Text('${'events.place'.tr()}: ${event.location}'),
              Text(
                '${'events.start'.tr()}: ${_formatEventDate(event.startsAt)}',
              ),
              Text(
                '${'events.end'.tr()}: ${_formatEventDate(event.endsAt)}',
              ),
              Text(
                '${'events.participants'.tr()}: '
                '${event.participantCount}/${event.capacity}',
              ),
              if (event.organizerName != null)
                Text(
                  '${'events.organizer'.tr()}: ${event.organizerName}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.back'.tr()),
          ),
        ],
      ),
    );
  }

  String _eventTypeLabel(EventType type) {
    return switch (type) {
      EventType.cleanup => 'events.cleanup'.tr(),
      EventType.treePlanting => 'events.tree_planting'.tr(),
      EventType.recyclingWorkshop => 'events.recycling_workshop'.tr(),
      EventType.other => 'events.other'.tr(),
    };
  }

  String _formatEventDate(DateTime date) =>
      DateFormat.yMMMd(context.locale.toString()).add_jm().format(date);
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog({required this.service, this.event});
  final BackendEventService service;
  final EcologicalEvent? event;
  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _capacity = TextEditingController(text: '20');
  String _type = 'cleanup';
  DateTime? _start;
  DateTime? _end;
  LatLng? _coordinates;
  bool _locating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _title.text = event.title;
      _description.text = event.description;
      _location.text = event.location;
      _capacity.text = event.capacity.toString();
      _type = switch (event.type) {
        EventType.cleanup => 'cleanup',
        EventType.treePlanting => 'tree_planting',
        EventType.recyclingWorkshop => 'recycling_workshop',
        EventType.other => 'other',
      };
      _start = event.startsAt;
      _end = event.endsAt;
      _coordinates = LatLng(event.latitude, event.longitude);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final base = start
        ? (_start ?? DateTime.now())
        : (_end ?? _start ?? DateTime.now());
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: base,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => start ? _start = value : _end = value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _start == null ||
        _end == null ||
        !_end!.isAfter(_start!) ||
        _coordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('events.invalid_dates'.tr())),
      );
      return;
    }
    final token = await authPreferences.getAccessToken();
    if (token == null || token.isEmpty) return;
    setState(() => _saving = true);
    try {
      final event = widget.event == null
          ? await widget.service.create(
              accessToken: token,
              title: _title.text.trim(),
              description: _description.text.trim(),
              eventType: _type,
              location: _location.text.trim(),
              latitude: _coordinates!.latitude,
              longitude: _coordinates!.longitude,
              startsAt: _start!,
              endsAt: _end!,
              capacity: int.parse(_capacity.text),
            )
          : await widget.service.update(
              accessToken: token,
              eventId: widget.event!.id,
              title: _title.text.trim(),
              description: _description.text.trim(),
              eventType: _type,
              location: _location.text.trim(),
              latitude: _coordinates!.latitude,
              longitude: _coordinates!.longitude,
              startsAt: _start!,
              endsAt: _end!,
              capacity: int.parse(_capacity.text),
            );
      if (mounted) Navigator.pop(context, event);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _useGps() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('events.gps_denied'.tr());
      }
      final position = await Geolocator.getCurrentPosition();
      final coordinates = LatLng(position.latitude, position.longitude);
      final address = await GeocodingService.instance.reverseGeocode(
        coordinates.latitude,
        coordinates.longitude,
      );
      if (!mounted) return;
      setState(() {
        _coordinates = coordinates;
        if (address != null) _location.text = address;
      });
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _geocodeAddress() async {
    setState(() => _locating = true);
    final coordinates = await GeocodingService.instance.forwardGeocode(
      _location.text,
    );
    if (!mounted) return;
    setState(() {
      _coordinates = coordinates;
      _locating = false;
    });
    if (coordinates == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('events.address_not_found'.tr())));
    }
  }

  String _date(DateTime? value) => value == null
      ? 'events.choose_datetime'.tr()
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.event == null ? 'events.dialog_title'.tr() : 'events.edit_title'.tr(),
    ),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_title, 'events.title_field'.tr(), min: 3),
              _field(_description, 'events.description_field'.tr(), min: 3, lines: 3),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: InputDecoration(labelText: 'events.type'.tr()),
                items: [
                  DropdownMenuItem(value: 'cleanup', child: Text('events.cleanup'.tr())),
                  DropdownMenuItem(
                    value: 'tree_planting',
                    child: Text('events.tree_planting'.tr()),
                  ),
                  DropdownMenuItem(
                    value: 'recycling_workshop',
                    child: Text('events.recycling_workshop'.tr()),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('events.other'.tr())),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _type = value!),
              ),
              _field(_location, 'events.location'.tr(), min: 3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _locating ? null : _useGps,
                      icon: const Icon(Icons.my_location),
                      label: Text('events.use_gps'.tr()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _locating ? null : _geocodeAddress,
                      icon: const Icon(Icons.search),
                      label: Text('events.locate_address'.tr()),
                    ),
                  ),
                ],
              ),
              if (_coordinates != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${'events.position'.tr()}: ${_coordinates!.latitude.toStringAsFixed(5)}, '
                    '${_coordinates!.longitude.toStringAsFixed(5)}',
                  ),
                ),
              TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'events.capacity'.tr(),
                ),
                validator: (value) {
                  final count = int.tryParse(value ?? '');
                  return count != null && count > 0
                      ? null
                      : 'events.invalid_capacity'.tr();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${'events.start'.tr()}: ${_date(_start)}'),
                onTap: _saving ? null : () => _pick(true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${'events.end'.tr()}: ${_date(_end)}'),
                onTap: _saving ? null : () => _pick(false),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: Text('common.cancel'.tr()),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(
          widget.event == null ? 'events.create'.tr() : 'events.save_changes'.tr(),
        ),
      ),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    required int min,
    int lines = 1,
  }) => TextFormField(
    controller: controller,
    maxLines: lines,
    decoration: InputDecoration(labelText: label),
    validator: (value) => value == null || value.trim().length < min
    ? '$label ${'events.required'.tr()}'
        : null,
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onView,
    required this.isOwner,
    required this.onEdit,
    required this.onDelete,
    required this.onParticipants,
    required this.onClose,
    required this.onRegister,
  });
  final EcologicalEvent event;
  final VoidCallback onView;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onParticipants;
  final VoidCallback onClose;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_rounded, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(
                label: Text(event.status.name),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(event.description),
          const SizedBox(height: 8),
          Text('${'events.place'.tr()}: ${event.location}'),
          Text('${'events.participants'.tr()}: ${event.participantCount}/${event.capacity}'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined, size: 22),
                  tooltip: 'events.view_details'.tr(),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                    backgroundColor: const Color(0xFFE3F2FD),
                    fixedSize: const Size(44, 44),
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onParticipants,
                    icon: const Icon(Icons.groups_outlined, size: 22),
                    tooltip: 'events.manage_participants'.tr(),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      backgroundColor: const Color(0xFFE8F5E9),
                      fixedSize: const Size(44, 44),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (event.status == EventStatus.planned)
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.lock_outline, size: 22),
                      tooltip: 'events.close'.tr(),
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF6A1B9A),
                        backgroundColor: const Color(0xFFF3E5F5),
                        fixedSize: const Size(44, 44),
                      ),
                    ),
                  if (event.status == EventStatus.planned)
                    const SizedBox(width: 8),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 21),
                    tooltip: 'events.edit'.tr(),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF9A6700),
                      backgroundColor: const Color(0xFFFFF3CD),
                      fixedSize: const Size(44, 44),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 22),
                    tooltip: 'events.delete'.tr(),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      backgroundColor: const Color(0xFFFFE5E5),
                      fixedSize: const Size(44, 44),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (event.status == EventStatus.planned)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRegister,
                child: Text(
                  event.isRegistered
                      ? 'events.unregister'.tr()
                      : event.isFull
                      ? 'events.full'.tr()
                      : 'events.register'.tr(),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
