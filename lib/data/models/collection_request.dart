/// Status of a home-collection request.
enum RequestStatus { pending, accepted, completed, cancelled }

extension RequestStatusLabel on RequestStatus {
  String get translationKey => switch (this) {
        RequestStatus.pending => 'collection.status_pending',
        RequestStatus.accepted => 'collection.status_accepted',
        RequestStatus.completed => 'collection.status_completed',
        RequestStatus.cancelled => 'collection.status_cancelled',
      };

  static RequestStatus fromString(String value) =>
      RequestStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => RequestStatus.pending,
      );
}

class CollectionRequest {
  final String id;
  final String address;
  final double? latitude;
  final double? longitude;
  final String wasteTypes; // comma-separated
  final String? notes;
  final String requestedDate; // ISO-8601
  final RequestStatus status;
  final String createdAt;
  final int? creatorId;
  final String? creatorName;
  final int? acceptedByUserId;
  final String? acceptedByUserName;

  const CollectionRequest({
    required this.id,
    required this.address,
    this.latitude,
    this.longitude,
    required this.wasteTypes,
    this.notes,
    required this.requestedDate,
    required this.status,
    required this.createdAt,
    this.creatorId,
    this.creatorName,
    this.acceptedByUserId,
    this.acceptedByUserName,
  });

  List<String> get wasteTypeList =>
      wasteTypes.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Map<String, dynamic> toMap() => {
        'id': id,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'waste_types': wasteTypes,
        'notes': notes,
        'requested_date': requestedDate,
        'status': status.name,
        'created_at': createdAt,
        'creator_id': creatorId,
        'creator_name': creatorName,
        'accepted_by_user_id': acceptedByUserId,
        'accepted_by_user_name': acceptedByUserName,
      };

  factory CollectionRequest.fromMap(Map<String, dynamic> map) =>
      CollectionRequest(
        id: map['id'] as String,
        address: map['address'] as String,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        wasteTypes: map['waste_types'] as String,
        notes: map['notes'] as String?,
        requestedDate: map['requested_date'] as String,
        status: RequestStatusLabel.fromString(map['status'] as String),
        createdAt: map['created_at'] as String,
        creatorId: map['creator_id'] as int?,
        creatorName: map['creator_name'] as String?,
        acceptedByUserId: map['accepted_by_user_id'] as int?,
        acceptedByUserName: map['accepted_by_user_name'] as String?,
      );

  CollectionRequest copyWith({
    String? address,
    double? latitude,
    double? longitude,
    String? wasteTypes,
    String? notes,
    String? requestedDate,
    RequestStatus? status,
    int? creatorId,
    String? creatorName,
    int? acceptedByUserId,
    String? acceptedByUserName,
  }) =>
      CollectionRequest(
        id: id,
        address: address ?? this.address,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        wasteTypes: wasteTypes ?? this.wasteTypes,
        notes: notes ?? this.notes,
        requestedDate: requestedDate ?? this.requestedDate,
        status: status ?? this.status,
        createdAt: createdAt,
        creatorId: creatorId ?? this.creatorId,
        creatorName: creatorName ?? this.creatorName,
        acceptedByUserId: acceptedByUserId ?? this.acceptedByUserId,
        acceptedByUserName: acceptedByUserName ?? this.acceptedByUserName,
      );
}
