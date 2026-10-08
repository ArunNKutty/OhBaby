import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

class GoogleAuthStatus {
  const GoogleAuthStatus({
    required this.configured,
    required this.redirectUri,
    required this.missing,
  });

  final bool configured;
  final String redirectUri;
  final List<String> missing;

  factory GoogleAuthStatus.fromJson(Map<String, dynamic> json) {
    final missing = (json['missing'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    return GoogleAuthStatus(
      configured: json['configured'] == true,
      redirectUri: json['redirect_uri'] as String? ?? '',
      missing: missing,
    );
  }
}

class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;
}

class ApiClient {
  ApiClient({http.Client? httpClient, String? base})
      : _http = httpClient ?? http.Client(),
        base = base ??
            const String.fromEnvironment(
              'API_BASE',
              defaultValue: 'http://127.0.0.1:47220',
            );

  final http.Client _http;
  final String base;

  Uri uri(String path, [Map<String, String>? query]) {
    final root = base.isEmpty ? Uri.base.origin : base;
    return Uri.parse('$root$path').replace(queryParameters: query);
  }

  Uri googleStartUri(String returnTo) =>
      uri('/v1/auth/google/start', {'return_to': returnTo});

  Future<GoogleAuthStatus> googleStatus() async {
    final res = await _send(http.Request('GET', uri('/v1/auth/google/status')));
    return GoogleAuthStatus.fromJson(_json(res));
  }

  Future<SessionTokens> exchangeCode(String code) async {
    final res = await _send(
      _jsonRequest('POST', uri('/v1/auth/google/exchange'), {'code': code}),
    );
    return _session(_json(res));
  }

  Future<SessionTokens> refresh(String refreshToken) async {
    final res = await _send(
      _jsonRequest('POST', uri('/v1/auth/refresh'), {'refresh_token': refreshToken}),
    );
    return _session(_json(res));
  }

  Future<void> deleteAccount(String accessToken) async {
    final req = http.Request('DELETE', uri('/v1/me'));
    req.headers['Authorization'] = 'Bearer $accessToken';
    await _send(req, ok: const {200, 204});
  }

  Future<http.Response> send(http.Request request, {Set<int> ok = const {200}}) {
    return _send(request, ok: ok);
  }

  SessionTokens _session(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return SessionTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      userId: user['id'] as String? ?? '',
      email: user['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> _json(http.Response res) =>
      jsonDecode(res.body) as Map<String, dynamic>;

  http.Request _jsonRequest(String method, Uri url, Map<String, dynamic> body) {
    final req = http.Request(method, url);
    req.headers['Content-Type'] = 'application/json';
    req.body = jsonEncode(body);
    return req;
  }

  Future<http.Response> _send(http.Request request, {Set<int> ok = const {200}}) async {
    http.StreamedResponse streamed;
    try {
      streamed = await _http.send(request).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('The backup server is not reachable.');
    }
    final res = await http.Response.fromStream(streamed);
    if (!ok.contains(res.statusCode)) {
      throw ApiException('The server returned ${res.statusCode}.', status: res.statusCode);
    }
    return res;
  }
}
