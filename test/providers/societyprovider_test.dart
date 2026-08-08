import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/providers/societyprovider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(const {}));

  /// The constructor kicks off its own `loadUserSocieties()` without exposing a
  /// handle on it, so build the provider only after the fake client is
  /// installed, await our own load, then drain the event loop so that in-flight
  /// constructor load has definitely settled.
  ///
  /// Draining matters: the constructor's load ends in `_loadViewMode()`, which
  /// rewrites `_viewAsMember` from SharedPreferences. Without the drain it can
  /// land *after* a test's `setViewAsMember(...)` and silently undo it. That is
  /// a genuine race in the provider, not just a test artefact -- a real user
  /// toggling the view immediately after sign-in can hit it -- but fixing it
  /// means giving the constructor's future a handle, which is beyond the scope
  /// of this suite.
  Future<SocietyProvider> loadedProvider() async {
    final provider = SocietyProvider();
    await provider.loadUserSocieties();
    await Future<void>.delayed(Duration.zero);
    return provider;
  }

  group('loadUserSocieties', () {
    test('populates societies and selects the first one', () async {
      await createFakeSupabase(tables: {
        'user_society_memberships': [
          membershipRow(society: honorSocietyRow(id: 1, name: 'Wheeler NHS')),
          membershipRow(society: honorSocietyRow(id: 2, name: 'Beta Club')),
        ],
      });

      final provider = await loadedProvider();

      expect(provider.userSocieties.map((s) => s.name),
          ['Wheeler NHS', 'Beta Club']);
      expect(provider.currentSociety?.id, 1);
      expect(provider.isLoading, isFalse);
      expect(provider.isInitialized, isTrue);
      expect(provider.loadingError, isNull);
    });

    test('parses the nested hour requirements', () async {
      await createFakeSupabase(tables: {
        'user_society_memberships': [
          membershipRow(
            society: honorSocietyRow(hourRequirements: [
              hourRequirementRow(id: 1, type: 'Service', hoursNeeded: 20),
              hourRequirementRow(id: 2, type: 'Tutoring', hoursNeeded: 10),
            ]),
          ),
        ],
      });

      final provider = await loadedProvider();

      expect(provider.currentSociety!.hourRequirements, hasLength(2));
      expect(provider.currentSociety!.hourRequirements.last.hoursNeeded, 10.0);
    });

    test('reads the admin flag of the selected society', () async {
      await createFakeSupabase(tables: {
        'user_society_memberships': [membershipRow(isAdmin: true)],
      });

      expect((await loadedProvider()).isAdmin, isTrue);
    });

    test('queries only the signed-in user', () async {
      final fake = await createFakeSupabase(
        userId: 'user-42',
        tables: {
          'user_society_memberships': [membershipRow()]
        },
      );

      await loadedProvider();

      final request = fake.lastRequestFor('user_society_memberships')!;
      expect(request.url.queryParameters['user_id'], 'eq.user-42');
    });

    test('clears everything when signed out, without querying', () async {
      final fake = await createFakeSupabase(userId: null);

      final provider = await loadedProvider();

      expect(provider.userSocieties, isEmpty);
      expect(provider.currentSociety, isNull);
      expect(provider.isAdmin, isFalse);
      expect(provider.isInitialized, isTrue);
      expect(fake.requestsFor('user_society_memberships'), isEmpty);
    });

    test('a member of nothing ends up with no current society', () async {
      await createFakeSupabase(tables: {'user_society_memberships': []});

      final provider = await loadedProvider();

      expect(provider.userSocieties, isEmpty);
      expect(provider.currentSociety, isNull);
      expect(provider.isAdmin, isFalse);
    });

    test('records the error and stops loading when the query fails', () async {
      await createFakeSupabase(
        handler: (_) => const FakeResponse.error(
          '{"code":"42501","message":"permission denied"}',
          statusCode: 403,
        ),
      );

      final provider = await loadedProvider();

      expect(provider.loadingError, isNotNull);
      expect(provider.isLoading, isFalse);
      expect(provider.isInitialized, isTrue);
    });

    test('notifies listeners', () async {
      await createFakeSupabase(tables: {
        'user_society_memberships': [membershipRow()],
      });

      final provider = SocietyProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.loadUserSocieties();

      expect(notifications, greaterThan(0));
    });
  });

  group('reloading', () {
    // Regression: the society and the admin flag were only assigned while
    // `_currentSociety == null`, so a reload after the user had picked a
    // society kept the old admin flag and the old (stale) society object.
    test('recomputes the admin flag when it changes server-side', () async {
      var isAdmin = true;
      await createFakeSupabase(
        handler: (request) {
          if (request.url.path.endsWith('user_society_memberships')) {
            return FakeResponse([membershipRow(isAdmin: isAdmin)]);
          }
          return const FakeResponse(<Map<String, dynamic>>[]);
        },
      );

      final provider = await loadedProvider();
      expect(provider.isAdmin, isTrue);

      isAdmin = false;
      await provider.loadUserSocieties();

      expect(provider.isAdmin, isFalse,
          reason: 'a demoted admin must lose the admin shell on reload');
    });

    test('refreshes the current society rather than keeping a stale copy',
        () async {
      var meetingRequirement = 8;
      await createFakeSupabase(
        handler: (request) {
          if (request.url.path.endsWith('user_society_memberships')) {
            return FakeResponse([
              membershipRow(
                society:
                    honorSocietyRow(meetingRequirement: meetingRequirement),
              ),
            ]);
          }
          return const FakeResponse(<Map<String, dynamic>>[]);
        },
      );

      final provider = await loadedProvider();
      expect(provider.currentSociety!.meetingRequirement, 8);

      meetingRequirement = 12;
      await provider.loadUserSocieties();

      expect(provider.currentSociety!.meetingRequirement, 12);
    });

    test('keeps the user on the society they selected', () async {
      await createFakeSupabase(tables: {
        'user_society_memberships': [
          membershipRow(society: honorSocietyRow(id: 1, name: 'Wheeler NHS')),
          membershipRow(
              isAdmin: true,
              society: honorSocietyRow(id: 2, name: 'Beta Club')),
        ],
      });

      final provider = await loadedProvider();
      await provider.setCurrentSociety(2);
      expect(provider.currentSociety?.id, 2);

      await provider.loadUserSocieties();

      expect(provider.currentSociety?.id, 2,
          reason: 'a reload must not snap back to the first society');
      expect(provider.isAdmin, isTrue,
          reason: 'and the admin flag must follow the selected society');
    });

    test('falls back to the first society if the selected one disappears',
        () async {
      var societies = [
        membershipRow(society: honorSocietyRow(id: 1, name: 'Wheeler NHS')),
        membershipRow(society: honorSocietyRow(id: 2, name: 'Beta Club')),
      ];
      await createFakeSupabase(
        handler: (request) {
          if (request.url.path.endsWith('user_society_memberships')) {
            return FakeResponse(societies);
          }
          return const FakeResponse(<Map<String, dynamic>>[]);
        },
      );

      final provider = await loadedProvider();
      await provider.setCurrentSociety(2);

      // The user is removed from Beta Club.
      societies = [
        membershipRow(society: honorSocietyRow(id: 1, name: 'Wheeler NHS')),
      ];
      await provider.loadUserSocieties();

      expect(provider.currentSociety?.id, 1);
      expect(provider.isAdmin, isFalse);
    });
  });

  group('setCurrentSociety', () {
    test('switches to another society already in the list', () async {
      await createFakeSupabase(tables: {
        'user_society_memberships': [
          membershipRow(society: honorSocietyRow(id: 1)),
          membershipRow(isAdmin: true, society: honorSocietyRow(id: 2)),
        ],
      });

      final provider = await loadedProvider();
      await provider.setCurrentSociety(2);

      expect(provider.currentSociety?.id, 2);
    });

    /// `_checkAdminStatus` is the only query in the provider that uses
    /// `.single()`, so the Accept header tells it apart from the roster load.
    bool isAdminCheck(request) =>
        ((request.headers['Accept'] ?? request.headers['accept'] ?? '')
                as String)
            .contains('vnd.pgrst.object');

    // Regression: the admin check kept the last known value on *any* failure.
    // Switching societies re-runs that check, so an admin of society 1 who hit
    // a blip while opening society 2 was handed society 2's admin shell.
    test('fails closed when the admin check fails while switching societies',
        () async {
      var failAdminCheck = false;
      await createFakeSupabase(
        handler: (request) {
          if (isAdminCheck(request)) {
            return failAdminCheck
                ? const FakeResponse.error(
                    '{"code":"42501","message":"permission denied"}',
                    statusCode: 403,
                  )
                : FakeResponse(membershipRow(isAdmin: false));
          }
          return FakeResponse([
            membershipRow(isAdmin: true, society: honorSocietyRow(id: 1)),
            membershipRow(isAdmin: false, society: honorSocietyRow(id: 2)),
          ]);
        },
      );

      final provider = await loadedProvider();
      expect(provider.isAdmin, isTrue, reason: 'admin of society 1');

      failAdminCheck = true;
      await provider.setCurrentSociety(2);

      expect(provider.currentSociety?.id, 2);
      expect(provider.isAdmin, isFalse,
          reason: "society 1's admin flag must not carry into society 2");
      expect(provider.showAdminView, isFalse);
    });

    // The other half of the same rule: within one society, a transient failure
    // must not demote an admin into the member shell until they restart.
    test('keeps the admin flag when the check fails for the same society',
        () async {
      var failAdminCheck = false;
      await createFakeSupabase(
        handler: (request) {
          if (isAdminCheck(request)) {
            return failAdminCheck
                ? const FakeResponse.error(
                    '{"code":"503","message":"service unavailable"}',
                    statusCode: 503,
                  )
                : FakeResponse(membershipRow(isAdmin: true));
          }
          return FakeResponse([
            membershipRow(isAdmin: true, society: honorSocietyRow(id: 1)),
          ]);
        },
      );

      final provider = await loadedProvider();
      expect(provider.isAdmin, isTrue);

      failAdminCheck = true;
      await provider.setCurrentSociety(1);

      expect(provider.isAdmin, isTrue,
          reason: 'a blip re-checking the current society must not demote');
    });
  });

  group('view mode', () {
    test('showAdminView is true for an admin by default', () async {
      await createFakeSupabase(tables: {
        'user_society_memberships': [membershipRow(isAdmin: true)],
      });

      final provider = await loadedProvider();

      expect(provider.isAdmin, isTrue);
      expect(provider.viewAsMember, isFalse);
      expect(provider.showAdminView, isTrue);
    });

    test('an admin previewing the member view keeps isAdmin', () async {
      await createFakeSupabase(tables: {
        'user_society_memberships': [membershipRow(isAdmin: true)],
      });

      final provider = await loadedProvider();
      await provider.setViewAsMember(true);

      expect(provider.isAdmin, isTrue);
      expect(provider.showAdminView, isFalse);
    });

    test('a member can never reach the admin view', () async {
      await createFakeSupabase(tables: {
        'user_society_memberships': [membershipRow()],
      });

      final provider = await loadedProvider();
      await provider.setViewAsMember(false);

      expect(provider.showAdminView, isFalse);
    });

    test('the preference is stored per society', () async {
      await createFakeSupabase(tables: {
        'user_society_memberships': [
          membershipRow(isAdmin: true, society: honorSocietyRow(id: 7)),
        ],
      });

      final provider = await loadedProvider();
      await provider.setViewAsMember(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('view_as_member_7'), isTrue);
    });
  });

  group('handleLogout', () {
    test('clears all tenancy state', () async {
      await createFakeSupabase(tables: {
        'user_society_memberships': [membershipRow(isAdmin: true)],
      });

      final provider = await loadedProvider();
      provider.handleLogout();

      expect(provider.currentSociety, isNull);
      expect(provider.userSocieties, isEmpty);
      expect(provider.isAdmin, isFalse);
    });
  });

  group('cancelLoading', () {
    test('stops the loading state', () async {
      await createFakeSupabase(tables: {
        'user_society_memberships': [membershipRow()],
      });

      final provider = await loadedProvider();
      provider.cancelLoading();

      expect(provider.isLoading, isFalse);
    });
  });
}
