import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waste_classification/data/models/collection_request.dart';

class BackendCollectionService {
  BackendCollectionService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<CollectionRequest> create({
    required String accessToken,
    required CollectionRequest request,
  }) async {
    final location = request.latitude != null && request.longitude != null
        ? {
            'type': 'Point',
            'coordinates': [request.longitude, request.latitude],
          }
        : null;
    final body = <String, dynamic>{
      'address': request.address,
      'wasteTypes': request.wasteTypeList,
      'requestedDate': request.requestedDate,
      if (request.notes != null) 'notes': request.notes,
      if (request.latitude != null) 'latitude': request.latitude,
      if (request.longitude != null) 'longitude': request.longitude,
    };
    if (location != null) body['location'] = location;

    final response = await _client
        .post(
          _endpoint('/collections'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } on Object {
      throw Exception('invalid_response');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      final message = error is Map ? error['message'] : null;
      throw Exception(message?.toString() ?? 'collection_request_failed');
    }

    final data = payload['data'];
    final result = data is Map ? data['request'] : null;
    if (result is! Map) throw Exception('invalid_response');
    return _fromBackend(result);
  }

  CollectionRequest _fromBackend(Map result) {
    final wasteTypes = result['wasteTypes'];
    final requestedDate = result['requestedDate'];
    final createdAt = result['createdAt'];
    if (result['id'] is! String ||
        result['address'] is! String ||
        wasteTypes is! List ||
        requestedDate == null ||
        createdAt == null) {
      throw Exception('invalid_response');
    }
    return CollectionRequest(
      id: result['id'] as String,
      address: result['address'] as String,
      latitude: (result['latitude'] as num?)?.toDouble(),
      longitude: (result['longitude'] as num?)?.toDouble(),
      wasteTypes: wasteTypes.map((item) => item.toString()).join(','),
      notes: result['notes'] as String?,
      requestedDate: requestedDate.toString(),
      status: RequestStatusLabel.fromString(
        result['status']?.toString() ?? RequestStatus.pending.name,
      ),
      createdAt: createdAt.toString(),
      creatorId: result['creatorId'] as int?,
      creatorName: result['creatorName'] as String?,
      acceptedByUserId: result['acceptedByUserId'] as int?,
      acceptedByUserName: result['acceptedByUserName'] as String?,
    );
  }

  Uri _endpoint(String path) {
    return Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/'
      '${path.replaceAll(RegExp(r'^/+'), '')}',
    );
  }
}
