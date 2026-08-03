// Write-path coverage for SocietyProvider.
//
// The read half is covered in societyprovider_test.dart. These are the calls
// that change server state -- including two RPCs whose names and parameter keys
// are plain strings that no compiler checks, so a typo ships silently.
//
// !! Two findings from dumping the live schema (2026-08-03):
//
// 1. `request_society_membership` and `create_society` DO NOT EXIST in the
//    production database. A dump of the public schema lists ten functions and
//    neither is among them, while `signup_for_timeslot` is. Calling them would
//    404, be swallowed by the catch, and return false.
//
// 2. Neither `requestJoinSociety` nor `createSociety` is called from anywhere
//    in lib/. They are dead code. The real join flow inserts straight into
//    `society_join_requests` (see societyjoinrequestpage.dart).
//
// So these tests pin the behaviour of unreachable methods. They are kept
// because the methods are public API on the central provider and someone will
// eventually wire them up -- at which point the tests document the contract
// they expect, and whoever does it must create the two functions first.
// Deleting the methods instead would be equally defensible.
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/providers/societyprovider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(const {}));

  Future<SocietyProvider> loadedProvider() async {
    final provider = SocietyProvider();
    await provider.loadUserSocieties();
    await Future<void>.delayed(Duration.zero);
    return provider;
  }

  group('requestJoinSociety', () {
    test('calls the RPC with the documented name and param key', () async {
      final fake = await createFakeSupabase(
        tables: {
          'user_society_memberships': [membershipRow()]
        },
        rpcs: {'request_society_membership': true},
      );

      final provider = await loadedProvider();
      final ok = await provider.requestJoinSociety(honorSociety(id: 42));

      expect(ok, isTrue);
      expect(fake.rpcCalls('request_society_membership'), hasLength(1));
      expect(fake.rpcParams('request_society_membership'),
          {'society_id_param': 42});
    });

    test('reloads societies after a successful request', () async {
      final fake = await createFakeSupabase(
        tables: {
          'user_society_memberships': [membershipRow()]
        },
        rpcs: {'request_society_membership': true},
      );

      final provider = await loadedProvider();
      final before = fake.requestsFor('user_society_memberships').length;
      await provider.requestJoinSociety(honorSociety(id: 42));

      expect(fake.requestsFor('user_society_memberships').length,
          greaterThan(before));
    });

    test('returns false when the RPC declines', () async {
      await createFakeSupabase(
        tables: {
          'user_society_memberships': [membershipRow()]
        },
        rpcs: {'request_society_membership': false},
      );

      final provider = await loadedProvider();
      expect(await provider.requestJoinSociety(honorSociety(id: 42)), isFalse);
    });

    test('returns false when RLS refuses, rather than reporting success',
        () async {
      await createFakeSupabase(
        tables: {
          'user_society_memberships': [membershipRow()]
        },
        handler: (request) => request.url.path.contains('/rpc/')
            ? const FakeResponse.rlsDenied()
            : FakeResponse([membershipRow()]),
      );

      final provider = await loadedProvider();
      expect(await provider.requestJoinSociety(honorSociety(id: 42)), isFalse);
    });
  });

  group('createSociety', () {
    test('sends every documented param, including the creator id', () async {
      final fake = await createFakeSupabase(
        userId: 'user-7',
        tables: {
          'user_society_memberships': [membershipRow()]
        },
        rpcs: {'create_society': 99},
      );

      final provider = await loadedProvider();
      final ok = await provider.createSociety('Beta Club', 'A club', 6);

      expect(ok, isTrue);
      expect(fake.rpcParams('create_society'), {
        'name_param': 'Beta Club',
        'description_param': 'A club',
        'meeting_requirement_param': 6,
        'creator_user_id': 'user-7',
      });
    });

    test('refuses to call the RPC when signed out', () async {
      final fake = await createFakeSupabase(userId: null);

      final provider = await loadedProvider();
      final ok = await provider.createSociety('Beta Club', 'A club', 6);

      expect(ok, isFalse);
      expect(fake.rpcCalls('create_society'), isEmpty);
    });

    test('returns false when the RPC yields no id', () async {
      await createFakeSupabase(
        tables: {
          'user_society_memberships': [membershipRow()]
        },
        rpcs: {'create_society': null},
      );

      final provider = await loadedProvider();
      expect(await provider.createSociety('Beta Club', 'A club', 6), isFalse);
    });

    test('returns false when RLS refuses', () async {
      await createFakeSupabase(
        tables: {
          'user_society_memberships': [membershipRow()]
        },
        handler: (request) => request.url.path.contains('/rpc/')
            ? const FakeResponse.rlsDenied()
            : FakeResponse([membershipRow()]),
      );

      final provider = await loadedProvider();
      expect(await provider.createSociety('Beta Club', 'A club', 6), isFalse);
    });
  });

  group('createHourRequirement', () {
    test('inserts the expected columns against the current society', () async {
      final fake = await createFakeSupabase(
        tables: {
          'user_society_memberships': [
            membershipRow(society: honorSocietyRow(id: 5)),
          ],
          'hour_requirements': [
            hourRequirementRow(id: 77, type: 'Tutoring', hoursNeeded: 10),
          ],
        },
      );

      final provider = await loadedProvider();
      final ok = await provider.createHourRequirement(
          'Tutoring', 'Tutor peers', 10, 'school');

      expect(ok, isTrue);
      expect(fake.methodsFor('hour_requirements'), contains('POST'));
      expect(fake.soleWriteTo('hour_requirements'), {
        'society_id': 5,
        'type': 'Tutoring',
        'description': 'Tutor peers',
        'hours_needed': 10.0,
        'is_active': true,
        'icon_name': 'school',
      });
    });

    test('adds the new requirement to the in-memory society', () async {
      await createFakeSupabase(
        tables: {
          'user_society_memberships': [membershipRow()],
          'hour_requirements': [
            hourRequirementRow(id: 77, type: 'Tutoring', hoursNeeded: 10),
          ],
        },
      );

      final provider = await loadedProvider();
      final before = provider.currentSociety!.hourRequirements.length;
      await provider.createHourRequirement(
          'Tutoring', 'Tutor peers', 10, 'school');

      expect(provider.currentSociety!.hourRequirements, hasLength(before + 1));
      expect(provider.currentSociety!.hourRequirements.last.type, 'Tutoring');
    });

    test('does nothing without a current society', () async {
      final fake =
          await createFakeSupabase(tables: {'user_society_memberships': []});

      final provider = await loadedProvider();
      final ok = await provider.createHourRequirement('T', 'd', 1, 'school');

      expect(ok, isFalse);
      expect(fake.requestsFor('hour_requirements'), isEmpty);
    });

    // This call chains .select().single() after the insert, so an RLS refusal
    // surfaces as an error rather than a silent no-op.
    test('returns false when RLS refuses the insert', () async {
      await createFakeSupabase(
        tables: {
          'user_society_memberships': [membershipRow()]
        },
        handler: (request) => request.url.path.endsWith('hour_requirements') &&
                request.method != 'GET'
            ? const FakeResponse.rlsDenied()
            : FakeResponse([membershipRow()]),
      );

      final provider = await loadedProvider();
      final ok = await provider.createHourRequirement(
          'Tutoring', 'Tutor peers', 10, 'school');

      expect(ok, isFalse);
    });
  });

  group('updateHourRequirement', () {
    test('patches the requirement by id', () async {
      final fake = await createFakeSupabase(
        tables: {
          'user_society_memberships': [membershipRow()]
        },
      );

      final provider = await loadedProvider();
      await provider.updateHourRequirement(
          100, 'Service', 'Updated', 25, true, 'recycling');

      final request = fake.lastRequestFor('hour_requirements')!;
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['id'], 'eq.100');
      expect(fake.soleWriteTo('hour_requirements'), {
        'type': 'Service',
        'description': 'Updated',
        'hours_needed': 25.0,
        'is_active': true,
        'icon_name': 'recycling',
      });
    });

    test('does nothing without a current society', () async {
      final fake =
          await createFakeSupabase(tables: {'user_society_memberships': []});

      final provider = await loadedProvider();
      final ok = await provider.updateHourRequirement(
          100, 'Service', 'd', 25, true, 'recycling');

      expect(ok, isFalse);
      expect(fake.requestsFor('hour_requirements'), isEmpty);
    });

    // Documents a real weakness rather than asserting correctness.
    //
    // Unlike createHourRequirement, this update does NOT chain .select(), so
    // PostgREST returns 204 and the client cannot tell an applied write from
    // one RLS silently dropped. CLAUDE.md calls this out explicitly. Until the
    // call chains .select() and compares the returned rows, an admin whose
    // policy forbids the update still sees the change apply locally.
    test('a refused update is currently indistinguishable from success',
        () async {
      await createFakeSupabase(
        tables: {
          'user_society_memberships': [membershipRow()]
        },
        handler: (request) => request.method == 'PATCH'
            ? const FakeResponse.rlsDenied()
            : FakeResponse([membershipRow()]),
      );

      final provider = await loadedProvider();
      final ok = await provider.updateHourRequirement(
          100, 'Service', 'Updated', 25, true, 'recycling');

      // A 403 does raise here, so the method reports false -- but only because
      // PostgREST answered with an error body. A policy that filters the row
      // out instead returns 204 and would report success.
      expect(ok, isFalse);
    });
  });

  group('refreshCurrentSociety', () {
    test('re-reads the society and updates the cached copy', () async {
      var meetingRequirement = 8;
      await createFakeSupabase(
        handler: (request) {
          if (request.url.path.endsWith('user_society_memberships')) {
            return FakeResponse([membershipRow()]);
          }
          if (request.url.path.endsWith('honor_societies')) {
            // refreshCurrentSociety uses .single(), which asks for a bare
            // object via the pgrst.object+json Accept header -- returning a
            // list here makes postgrest throw.
            return FakeResponse(
                honorSocietyRow(meetingRequirement: meetingRequirement));
          }
          return const FakeResponse(<Map<String, dynamic>>[]);
        },
      );

      final provider = await loadedProvider();
      expect(provider.currentSociety!.meetingRequirement, 8);

      meetingRequirement = 12;
      await provider.refreshCurrentSociety();

      expect(provider.currentSociety!.meetingRequirement, 12);
      expect(provider.userSocieties.first.meetingRequirement, 12,
          reason: 'the cached list must be patched too, not just the current');
    });

    test('leaves state intact when the refresh fails', () async {
      var failing = false;
      await createFakeSupabase(
        handler: (request) {
          if (request.url.path.endsWith('user_society_memberships')) {
            return FakeResponse([membershipRow()]);
          }
          if (failing) return const FakeResponse.rlsDenied();
          return FakeResponse(honorSocietyRow());
        },
      );

      final provider = await loadedProvider();
      final before = provider.currentSociety;

      failing = true;
      await provider.refreshCurrentSociety();

      expect(provider.currentSociety, isNotNull);
      expect(provider.currentSociety!.id, before!.id);
    });
  });
}
