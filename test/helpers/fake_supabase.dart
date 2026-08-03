import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nhs_tracker/data/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A real [SupabaseClient] wired to a fake HTTP transport.
///
/// We build a genuine client rather than mocking the `PostgrestFilterBuilder`
/// chain: `.from().select().eq().single()` is awkward to mock faithfully, and
/// mocking it would test our mock instead of the query the app actually builds.
/// With a fake transport the URL building, header negotiation and JSON decoding
/// are all the library's real code, and [requests] lets a test assert on the
/// PostgREST query string that came out the other end.
class FakeSupabase {
  FakeSupabase._(this.client);

  final SupabaseClient client;

  /// Every request the app made, in order. Assert against these.
  final List<http.Request> requests = [];

  /// Requests against `/rest/v1/<table>`, keyed by table name.
  Iterable<http.Request> requestsFor(String table) =>
      requests.where((r) => r.url.path == '/rest/v1/$table');

  /// The most recent request for [table], or null.
  http.Request? lastRequestFor(String table) {
    final matches = requestsFor(table).toList();
    return matches.isEmpty ? null : matches.last;
  }
}

/// Describes one canned response.
class FakeResponse {
  /// [body] is a Dart value that gets JSON-encoded. A String body therefore
  /// becomes a JSON string (`"full"`), which is what an RPC returning `text`
  /// actually sends -- use [FakeResponse.raw] to supply pre-encoded JSON.
  const FakeResponse(this.body, {this.statusCode = 200}) : isRaw = false;

  /// Body used verbatim, already JSON.
  const FakeResponse.raw(String this.body, {this.statusCode = 200})
      : isRaw = true;

  /// A PostgREST error payload, e.g. an RLS refusal.
  const FakeResponse.error(String this.body, {this.statusCode = 400})
      : isRaw = true;

  final Object? body;
  final int statusCode;
  final bool isRaw;

  String encode() => isRaw ? body as String : jsonEncode(body);
}

/// Builds a [FakeSupabase] whose responses come from [tables] / [rpcs].
///
/// [tables] maps a table name to the rows a `select` on it returns. [rpcs] maps
/// an RPC function name to its return value. [handler] overrides both when a
/// test needs per-request control (status codes, sequencing, assertions).
///
/// When [userId] is non-null the client is given a signed-in session, so
/// `supabase.auth.currentUser?.id` resolves. This installs the client as the
/// app-wide override and registers teardown for both the override and the
/// client's isolate, so callers do not have to.
Future<FakeSupabase> createFakeSupabase({
  Map<String, List<Map<String, dynamic>>> tables = const {},
  Map<String, Object?> rpcs = const {},
  FakeResponse Function(http.Request request)? handler,
  String? userId = 'test-user-id',
  String email = 'member@example.com',
}) async {
  late final FakeSupabase fake;

  final mockClient = MockClient((request) async {
    fake.requests.add(request);

    final result = handler?.call(request) ?? _route(request, tables, rpcs);

    return http.Response(
      result.encode(),
      result.statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  });

  final client = SupabaseClient(
    'http://localhost:54321',
    'test-anon-key',
    httpClient: mockClient,
    // Without this, gotrue schedules a background refresh timer that outlives
    // the test and makes testWidgets fail with a pending-timer error.
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  fake = FakeSupabase._(client);

  if (userId != null) {
    await seedSession(client, userId: userId, email: email);
  }

  supabaseOverride = client;
  addTearDown(() async {
    supabaseOverride = null;
    // The SupabaseClient constructor spins up a YAJsonIsolate; leaking it
    // across tests eventually exhausts the runner.
    await client.dispose();
  });

  return fake;
}

/// Gives [client] a signed-in session without any network round trip.
///
/// `setInitialSession` just parses the JSON, assigns `_currentSession` and
/// notifies subscribers. Note this deliberately avoids `recoverSession`, which
/// *does* hit the network whenever the session looks expired.
///
/// `Session.fromJson` needs only `access_token`, `token_type` and a `user`
/// object carrying an `id` -- there is no JWT parsing or signature check, so a
/// placeholder token is fine.
Future<void> seedSession(
  SupabaseClient client, {
  required String userId,
  String email = 'member@example.com',
}) {
  return client.auth.setInitialSession(jsonEncode({
    'access_token': 'test-access-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'test-refresh-token',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': email,
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00.000Z',
    },
  }));
}

FakeResponse _route(
  http.Request request,
  Map<String, List<Map<String, dynamic>>> tables,
  Map<String, Object?> rpcs,
) {
  final segments = request.url.pathSegments;

  // /rest/v1/rpc/<function>
  if (segments.length >= 4 && segments[2] == 'rpc') {
    final name = segments[3];
    if (rpcs.containsKey(name)) return FakeResponse(rpcs[name]);
    return const FakeResponse(null);
  }

  // /rest/v1/<table>
  if (segments.length >= 3 && segments[0] == 'rest') {
    final rows = tables[segments[2]] ?? const <Map<String, dynamic>>[];

    // `.single()` / `.maybeSingle()` ask for a bare object via this Accept
    // header; returning a list there makes postgrest throw.
    final accept = request.headers['Accept'] ?? request.headers['accept'] ?? '';
    if (accept.contains('vnd.pgrst.object+json')) {
      if (rows.isEmpty) {
        return const FakeResponse.error(
          '{"code":"PGRST116","message":"0 rows"}',
          statusCode: 406,
        );
      }
      return FakeResponse(rows.first);
    }

    // Writes echo the payload back, matching PostgREST's return=representation.
    if (request.method != 'GET' && rows.isEmpty) {
      return FakeResponse.raw(request.body.isEmpty ? '[]' : request.body);
    }

    return FakeResponse(rows);
  }

  return const FakeResponse(<Map<String, dynamic>>[]);
}
