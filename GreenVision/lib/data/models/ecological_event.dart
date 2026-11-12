enum EventStatus { planned, completed, cancelled }

enum EventType { cleanup, treePlanting, recyclingWorkshop, other }

class EventParticipant {
  const EventParticipant({
    required this.userId,
    required this.name,
    this.email,
    this.attended,
  });

  final int userId;
  final String name;
  final String? email;
  final bool? attended;
}

class EcologicalEvent {
  const EcologicalEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.participantCount,
    required this.status,
    required this.isRegistered,
    required this.organizerId,
    this.organizerName,
  });

  final String id;
  final String title;
  final String description;
  final EventType type;
  final String location;
  final double latitude;
  final double longitude;
  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;
  final int participantCount;
  final EventStatus status;
  final bool isRegistered;
  final int organizerId;
  final String? organizerName;

  bool get isFull => participantCount >= capacity;
  int get remainingPlaces => capacity - participantCount;

  static EcologicalEvent fromJson(Map<String, dynamic> json) {
    return EcologicalEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: EventType.values.firstWhere(
        (value) => value.name == _typeName(json['eventType']?.toString()),
        orElse: () => EventType.other,
      ),
      location: json['location'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      startsAt: DateTime.parse(json['startsAt'].toString()).toLocal(),
      endsAt: DateTime.parse(json['endsAt'].toString()).toLocal(),
      capacity: (json['capacity'] as num).toInt(),
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      status: EventStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => EventStatus.planned,
      ),
      isRegistered: json['isRegistered'] == true,
      organizerId: (json['organizerId'] as num).toInt(),
      organizerName: json['organizerName'] as String?,
    );
  }

  static String _typeName(String? value) {
    return switch (value) {
      'tree_planting' => 'treePlanting',
      'recycling_workshop' => 'recyclingWorkshop',
      'cleanup' => 'cleanup',
      _ => 'other',
    };
  }
}
