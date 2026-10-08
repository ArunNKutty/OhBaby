import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

class FirebaseWebConfig {
  const FirebaseWebConfig({
    required this.apiKey,
    required this.authDomain,
    required this.projectId,
    required this.appId,
    required this.messagingSenderId,
    this.storageBucket = '',
  });

  final String apiKey;
  final String authDomain;
  final String projectId;
  final String appId;
  final String messagingSenderId;
  final String storageBucket;

  factory FirebaseWebConfig.fromJson(Map<String, dynamic> json) {
    return FirebaseWebConfig(
      apiKey: json['apiKey'] as String? ?? '',
      authDomain: json['authDomain'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      appId: json['appId'] as String? ?? '',
      messagingSenderId: json['messagingSenderId'] as String? ?? '',
      storageBucket: json['storageBucket'] as String? ?? '',
    );
  }
}

class FirebaseAuthStatus {
  const FirebaseAuthStatus({
    required this.configured,
    required this.missing,
    required this.setup,
    this.web,
  });

  final bool configured;
  final List<String> missing;
  final List<String> setup;
  final FirebaseWebConfig? web;

  factory FirebaseAuthStatus.fromJson(Map<String, dynamic> json) {
    final missing = (json['missing'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final setup = (json['setup'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final webJson = json['web'];
    return FirebaseAuthStatus(
      configured: json['configured'] == true,
      missing: missing,
      setup: setup,
      web: webJson is Map<String, dynamic> ? FirebaseWebConfig.fromJson(webJson) : null,
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

  Future<FirebaseAuthStatus> firebaseStatus() async {
    final res = await _send(http.Request('GET', uri('/v1/auth/firebase/status')));
    return FirebaseAuthStatus.fromJson(_json(res));
  }

  Future<SessionTokens> exchangeFirebase(String idToken) async {
    final res = await _send(
      _jsonRequest('POST', uri('/v1/auth/firebase/exchange'), {'id_token': idToken}),
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
