import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waste_classification/data/models/user_model.dart';

class BackendAuthResult {
  const BackendAuthResult({required this.user, required this.accessToken});

  final UserModel user;
  final String accessToken;
}

class BackendAuthService {
  BackendAuthService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<BackendAuthResult> login({
    required String email,
    required String password,
  }) {
    return _authenticate('/auth/login', {
      'email': email.trim(),
      'password': password,
    }, requiresToken: true);
  }

  Future<BackendAuthResult> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _authenticate('/auth/register', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
    }, requiresToken: false);
  }

  Future<UserModel> currentUser({required String accessToken}) async {
    final response = await _client
        .get(
          _endpoint('/auth/me'),
          headers: {'authorization': 'Bearer $accessToken'},
        )
        .timeout(const Duration(seconds: 15));
    final payload = _decodeResponse(response);
    final data = payload['data'];
    final user = data is Map ? data['user'] : null;
    if (user is! Map) throw Exception('invalid_response');
    return _userFromPayload(user);
  }

  Future<void> requestPasswordReset({required String email}) async {
    final response = await _client
        .post(
          _endpoint('/auth/forgot-password'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 15));
    _decodeResponse(response);
  }

  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    final response = await _client
        .post(
          _endpoint('/auth/verify-reset-code'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
        )
        .timeout(const Duration(seconds: 15));
    final payload = _decodeResponse(response);
    final data = payload['data'];
    if (data is! Map || data['token'] is! String) {
      throw Exception('invalid_response');
    }
    return data['token'] as String;
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final response = await _client
        .post(
          _endpoint('/auth/reset-password'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'token': token.trim(), 'newPassword': newPassword}),
        )
        .timeout(const Duration(seconds: 15));
    _decodeResponse(response);
  }

  Future<BackendAuthResult> _authenticate(
    String path,
    Map<String, String> body,
    {required bool requiresToken}
  ) async {
    final response = await _client
        .post(
          _endpoint(path),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    final payload = _decodeResponse(response);
    final data = payload['data'];
    if (data is! Map ||
        data['user'] is! Map ||
        (requiresToken && data['token'] is! String)) {
      throw Exception('invalid_response');
    }
    return BackendAuthResult(
      accessToken: data['token'] as String? ?? '',
      user: _userFromPayload(data['user'] as Map),
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } on Object {
      throw Exception('invalid_response');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      if (error is Map) {
        final message = error['message'] ?? 'request_failed';
        final details = error['details'];
        if (details is List && details.isNotEmpty) {
          throw Exception('$message: ${details.join(', ')}');
        }
        throw Exception(message);
      }
      throw Exception('request_failed');
    }
    return payload;
  }

  UserModel _userFromPayload(Map user) {
    final id = user['id'];
    if (id is! int || user['name'] is! String || user['email'] is! String) {
      throw Exception('invalid_response');
    }
    return UserModel(
      id: id,
      name: user['name'] as String,
      email: user['email'] as String,
      passwordHash: '',
      avatarInitials: user['avatarInitials'] as String?,
      role: user['role'] as String? ?? 'user',
      createdAt: user['createdAt']?.toString() ?? '',
    );
  }

  Uri _endpoint(String path) {
    return Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/'
      '${path.replaceAll(RegExp(r'^/+'), '')}',
    );
  }
}
