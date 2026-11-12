import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waste_classification/data/models/ecological_event.dart';

class BackendEventService {
  BackendEventService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<List<EcologicalEvent>> list({required String accessToken}) async {
    final response = await _client
        .get(_endpoint('/events'), headers: _headers(accessToken))
        .timeout(const Duration(seconds: 15));
    final payload = _payload(response);
    final events = payload['events'];
    if (events is! List) throw Exception('invalid_response');
    return events
        .whereType<Map>()
        .map(
          (item) => EcologicalEvent.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<EcologicalEvent> register({
    required String accessToken,
    required String eventId,
    required bool registered,
  }) async {
    final response = registered
        ? await _client.post(
            _endpoint('/events/$eventId/register'),
            headers: _headers(accessToken),
          )
        : await _client.delete(
            _endpoint('/events/$eventId/register'),
            headers: _headers(accessToken),
          );
    final payload = _payload(response);
    final event = payload['event'];
    if (event is! Map) throw Exception('invalid_response');
    return EcologicalEvent.fromJson(Map<String, dynamic>.from(event));
  }

  Future<EcologicalEvent> create({
    required String accessToken,
    required String title,
    required String description,
    required String eventType,
    required String location,
    required double latitude,
    required double longitude,
    required DateTime startsAt,
    required DateTime endsAt,
    required int capacity,
  }) async {
    final response = await _client
        .post(
          _endpoint('/events'),
          headers: _headers(accessToken),
          body: jsonEncode({
            'title': title,
            'description': description,
            'eventType': eventType,
            'location': location,
            'latitude': latitude,
            'longitude': longitude,
            'startsAt': startsAt.toUtc().toIso8601String(),
            'endsAt': endsAt.toUtc().toIso8601String(),
            'capacity': capacity,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final payload = _payload(response);
    final event = payload['event'];
    if (event is! Map) throw Exception('invalid_response');
    return EcologicalEvent.fromJson(Map<String, dynamic>.from(event));
  }

  Future<EcologicalEvent> update({
    required String accessToken,
    required String eventId,
    required String title,
    required String description,
    required String eventType,
    required String location,
    required double latitude,
    required double longitude,
    required DateTime startsAt,
    required DateTime endsAt,
    required int capacity,
  }) async {
    final response = await _client
        .put(
          _endpoint('/events/$eventId'),
          headers: _headers(accessToken),
          body: jsonEncode({
            'title': title,
            'description': description,
            'eventType': eventType,
            'location': location,
            'latitude': latitude,
            'longitude': longitude,
            'startsAt': startsAt.toUtc().toIso8601String(),
            'endsAt': endsAt.toUtc().toIso8601String(),
            'capacity': capacity,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final payload = _payload(response);
    final event = payload['event'];
    if (event is! Map) throw Exception('invalid_response');
    return EcologicalEvent.fromJson(Map<String, dynamic>.from(event));
  }

  Future<void> delete({
    required String accessToken,
    required String eventId,
  }) async {
    final response = await _client
        .delete(
          _endpoint('/events/$eventId'),
          headers: _headers(accessToken),
        )
        .timeout(const Duration(seconds: 15));
    _payload(response);
  }

  Future<List<EventParticipant>> participants({
    required String accessToken,
    required String eventId,
  }) async {
    final response = await _client.get(
      _endpoint('/events/$eventId/participants'),
      headers: _headers(accessToken),
    );
    final data = _payload(response)['participants'];
    if (data is! List) throw Exception('invalid_response');
    return _participants(data);
  }

  Future<List<EventParticipant>> updateAttendance({
    required String accessToken,
    required String eventId,
    required int userId,
    required bool attended,
  }) async {
    final response = await _client.patch(
      _endpoint('/events/$eventId/participants/$userId/attendance'),
      headers: _headers(accessToken),
      body: jsonEncode({'attended': attended}),
    );
    final data = _payload(response)['participants'];
    if (data is! List) throw Exception('invalid_response');
    return _participants(data);
  }

  Future<EcologicalEvent> close({
    required String accessToken,
    required String eventId,
  }) async {
    final response = await _client.patch(
      _endpoint('/events/$eventId/status'),
      headers: _headers(accessToken),
      body: jsonEncode({'status': 'completed'}),
    );
    final event = _payload(response)['event'];
    if (event is! Map) throw Exception('invalid_response');
    return EcologicalEvent.fromJson(Map<String, dynamic>.from(event));
  }

  List<EventParticipant> _participants(List<dynamic> data) {
    return data.whereType<Map>().map((item) {
      final value = Map<String, dynamic>.from(item);
      return EventParticipant(
        userId: (value['userId'] as num).toInt(),
        name: value['name'] as String,
        email: value['email'] as String?,
        attended: value['attended'] as bool?,
      );
    }).toList();
  }

  Map<String, String> _headers(String token) => {
    'content-type': 'application/json',
    'authorization': 'Bearer $token',
  };

  Map<String, dynamic> _payload(http.Response response) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } on Object {
      throw Exception('invalid_response');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      final message = error is Map ? error['message'] : null;
      throw Exception(message?.toString() ?? 'event_request_failed');
    }
    final data = payload['data'];
    if (data is! Map) throw Exception('invalid_response');
    return Map<String, dynamic>.from(data);
  }

  Uri _endpoint(String path) => Uri.parse(
    '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/'
    '${path.replaceAll(RegExp(r'^/+'), '')}',
  );
}
