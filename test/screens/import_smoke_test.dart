// Guards the seam in lib/data/supabase_client.dart.
//
// Before that seam existed, 23 files declared `final supabase =
// Supabase.instance.client;` at top level. Dart evaluates a top-level `final`
// the first time its library is touched, and `Supabase.instance` throws when
// `Supabase.initialize()` has not run -- so merely *importing* any of these
// files from a test threw before a single assertion could execute.
//
// These imports are the assertion. If someone reintroduces an eager
// `Supabase.instance.client` at top level, this file stops loading and the
// suite fails loudly rather than mysteriously.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nhs_tracker/data/supabase_client.dart';
import 'package:nhs_tracker/models/logactivity.dart';
import 'package:nhs_tracker/providers/societyprovider.dart';
import 'package:nhs_tracker/screens/accountsettingspage.dart';
import 'package:nhs_tracker/screens/adminattendencepage.dart';
import 'package:nhs_tracker/screens/admineventspage.dart';
import 'package:nhs_tracker/screens/adminlistspage.dart';
import 'package:nhs_tracker/screens/attendencecheckpage.dart';
import 'package:nhs_tracker/screens/completedhourspage.dart';
import 'package:nhs_tracker/screens/homescreenpage.dart';
import 'package:nhs_tracker/screens/loginpage.dart';
import 'package:nhs_tracker/screens/mainscreen.dart';
import 'package:nhs_tracker/screens/societyselectionpage.dart';
import 'package:nhs_tracker/screens/waitingpage.dart';

void main() {
  test('screens can be imported without an initialized Supabase client', () {
    // Reaching this line at all is the real assertion -- the imports above
    // would have thrown at library load otherwise.
    expect(const WaitingPage(), isA<WaitingPage>());
    expect(const MainScreen(), isA<MainScreen>());
  });

  test('supabase resolves without an override installed', () {
    // test/flutter_test_config.dart initializes an inert Supabase instance for
    // the third-party auth widgets, so the real client is reachable here. The
    // property that matters is that the imports above did not blow up -- a
    // top-level `final` would have thrown at library load, before any of this
    // ran, no matter what the config did.
    expect(supabaseOverride, isNull);
    expect(supabase, isA<SupabaseClient>());
  });

  test('supabaseOverride redirects the getter and restores cleanly', () {
    addTearDown(() => supabaseOverride = null);
    final real = supabase;

    final fake = SupabaseClient('http://localhost:1', 'k',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(fake.dispose);

    supabaseOverride = fake;
    expect(supabase, same(fake));
    expect(supabase, isNot(same(real)));

    supabaseOverride = null;
    expect(supabase, same(real));
  });

  test('unused-symbol guard keeps the imports above alive', () {
    // Referencing one symbol per imported library stops a future "organize
    // imports" from silently deleting the coverage this file provides.
    for (final type in <Type>[
      SocietyProvider,
      LoginPage,
      HomePage,
      ColoringRule,
      CompletedHoursPage,
      AccountSettingsPage,
      SocietySelectionPage,
      AdminEventsPage,
      AdminAttendancePage,
      AttendanceCheckPage,
    ]) {
      expect(type, isNotNull);
    }
    expect(logactivity, isA<Function>());
  });
}
