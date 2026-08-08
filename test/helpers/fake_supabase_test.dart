// Tests the test helper. If this file fails, every suite built on the fake
// client is suspect, so it is worth its own coverage.
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/data/supabase_client.dart';

import 'fake_supabase.dart';

void main() {
  test('installs itself as the app-wide supabase override', () async {
    final fake = await createFakeSupabase();
    expect(supabaseOverride, same(fake.client));
    // Production code reads the bare `supabase` getter; it must see the fake.
    expect(supabase, same(fake.client));
  });

  test('seeds a signed-in user without touching the network', () async {
    final fake = await createFakeSupabase(userId: 'user-42');
    expect(fake.client.auth.currentUser?.id, 'user-42');
    expect(fake.requests, isEmpty, reason: 'seeding must be offline');
  });

  test('userId: null leaves the client signed out', () async {
    final fake = await createFakeSupabase(userId: null);
    expect(fake.client.auth.currentUser, isNull);
  });

  test('serves rows from the tables map', () async {
    final fake = await createFakeSupabase(tables: {
      'honor_societies': [
        {'id': 1, 'name': 'Wheeler NHS'},
        {'id': 2, 'name': 'Beta Club'},
      ],
    });

    final rows = await fake.client.from('honor_societies').select();

    expect(rows, hasLength(2));
    expect(rows.first['name'], 'Wheeler NHS');
  });

  test('unknown tables come back empty rather than throwing', () async {
    final fake = await createFakeSupabase();
    expect(await fake.client.from('nope').select(), isEmpty);
  });

  test('.single() gets a bare object, not a list', () async {
    final fake = await createFakeSupabase(tables: {
      'user_society_memberships': [
        {'is_admin': true},
      ],
    });

    final row = await fake.client
        .from('user_society_memberships')
        .select('is_admin')
        .eq('user_id', 'test-user-id')
        .single();

    expect(row['is_admin'], isTrue);
  });

  test('.single() on no rows raises PostgrestException, like the real API',
      () async {
    final fake = await createFakeSupabase();
    expect(
      () => fake.client.from('user_society_memberships').select().single(),
      throwsA(isA<Object>()),
    );
  });

  test('records the real PostgREST query string', () async {
    final fake = await createFakeSupabase(tables: {'Events': []});

    await fake.client
        .from('Events')
        .select('id,name')
        .eq('society_id', 7)
        .order('date');

    final request = fake.lastRequestFor('Events')!;
    expect(request.method, 'GET');
    expect(request.url.queryParameters['select'], 'id,name');
    expect(request.url.queryParameters['society_id'], 'eq.7');
    // postgrest-dart's .order() defaults to *descending* -- worth pinning,
    // since reading it as ascending is an easy mistake at the call sites.
    expect(request.url.queryParameters['order'], 'date.desc.nullslast');
  });

  test('.order(ascending: true) sends asc', () async {
    final fake = await createFakeSupabase(tables: {'Events': []});
    await fake.client.from('Events').select().order('date', ascending: true);
    expect(
      fake.lastRequestFor('Events')!.url.queryParameters['order'],
      'date.asc.nullslast',
    );
  });

  test('routes rpc calls and returns their value', () async {
    final fake =
        await createFakeSupabase(rpcs: {'signup_for_timeslot': 'full'});

    final status = await fake.client.rpc('signup_for_timeslot', params: {
      'p_timeslot_id': 1,
      'p_user_id': 'test-user-id',
    });

    expect(status, 'full');
  });

  test('a handler overrides the table map and can force an error', () async {
    final fake = await createFakeSupabase(
      tables: {'Events': []},
      handler: (_) => const FakeResponse.error(
        '{"code":"42501","message":"permission denied"}',
        statusCode: 403,
      ),
    );

    expect(
      () => fake.client.from('Events').select(),
      throwsA(isA<Object>()),
    );
  });

  test('teardown restores the override between tests', () {
    // The previous test installed a fake; teardown must have cleared it.
    expect(supabaseOverride, isNull);
  });
}
