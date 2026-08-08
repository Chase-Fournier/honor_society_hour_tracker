import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/common/progress_bars.dart';

import 'package:nhs_tracker/providers/societyprovider.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/pump.dart';

void main() {
  // The bars resolve their icon through getIconForType, which reads
  // SocietyProvider, so one has to be in the tree. Build it over the fake
  // client so no real network is hit.
  //
  // It must be built inside tester.runAsync: a testWidgets body runs in a
  // fake-async zone where a real Future (the provider's own load) never
  // completes, and the test just hangs until the runner times out.
  Future<SocietyProvider> society(WidgetTester tester) async {
    late SocietyProvider provider;
    await tester.runAsync(() async {
      await createFakeSupabase(tables: {'user_society_memberships': []});
      provider = SocietyProvider();
      await provider.loadUserSocieties();
    });
    return provider;
  }

  Future<void> pumpDouble(
    WidgetTester tester, {
    required double completed,
    required double potential,
    required int needed,
    String title = 'Service',
  }) async {
    return pumpInScaffold(
      tester,
      Builder(
        builder: (context) => buildDoubleProgressBar(
          context,
          title,
          completed,
          potential,
          needed,
        ),
      ),
      societyProvider: await society(tester),
    );
  }

  group('buildDoubleProgressBar', () {
    testWidgets('shows completed over required', (tester) async {
      await pumpDouble(tester, completed: 5, potential: 5, needed: 20);
      expect(find.text('5.0 / 20'), findsOneWidget);
      expect(find.text('Service'), findsOneWidget);
    });

    // The "Complete" badge lives *inside* the `potentialHours > completedHours`
    // block, so it only ever appears next to the "Potential:" row. A member who
    // has finished a requirement and has nothing else signed up sees no badge
    // at all. That is the shipped behaviour, pinned here rather than changed.
    testWidgets('marks the requirement complete when potential hours remain',
        (tester) async {
      await pumpDouble(tester, completed: 20, potential: 24, needed: 20);
      expect(find.text('Complete'), findsOneWidget);
    });

    testWidgets('shows no badge when complete with nothing upcoming',
        (tester) async {
      await pumpDouble(tester, completed: 20, potential: 20, needed: 20);
      expect(find.text('Complete'), findsNothing);
    });

    testWidgets('is not complete just below the requirement', (tester) async {
      await pumpDouble(tester, completed: 19.5, potential: 24, needed: 20);
      expect(find.text('Complete'), findsNothing);
    });

    testWidgets('shows potential hours when they exceed completed',
        (tester) async {
      await pumpDouble(tester, completed: 5, potential: 9, needed: 20);
      expect(find.text('Potential: 9.0'), findsOneWidget);
    });

    testWidgets('hides the potential row when it adds nothing', (tester) async {
      await pumpDouble(tester, completed: 5, potential: 5, needed: 20);
      expect(find.textContaining('Potential:'), findsNothing);
    });

    // A 0-hour requirement is admin-configurable, so this reaches every
    // member's home screen. The bars used to divide unguarded and lean on
    // clamp's NaN handling; progressFraction makes it explicit.
    testWidgets('renders a zero-hour requirement without a NaN width factor',
        (tester) async {
      await pumpDouble(tester, completed: 0, potential: 0, needed: 0);

      expect(tester.takeException(), isNull);
      for (final box in tester.widgetList<FractionallySizedBox>(
          find.byType(FractionallySizedBox))) {
        expect(box.widthFactor?.isNaN, isNot(isTrue));
        expect(box.widthFactor, inInclusiveRange(0.0, 1.0));
      }
    });

    testWidgets('a zero-hour requirement counts as complete', (tester) async {
      // Needs potential > completed for the badge to be rendered at all.
      await pumpDouble(tester, completed: 0, potential: 2, needed: 0);
      expect(find.text('Complete'), findsOneWidget);
    });

    testWidgets('clamps the bar when the member overshoots', (tester) async {
      await pumpDouble(tester, completed: 60, potential: 60, needed: 20);

      expect(tester.takeException(), isNull);
      for (final box in tester.widgetList<FractionallySizedBox>(
          find.byType(FractionallySizedBox))) {
        expect(box.widthFactor, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('buildMeetingProgressBar', () {
    Future<void> pumpMeeting(
      WidgetTester tester, {
      required double completed,
      required int needed,
      int meetingsLeft = 0,
    }) async {
      return pumpInScaffold(
        tester,
        Builder(
          builder: (context) => buildMeetingProgressBar(
            context,
            completed,
            needed,
            meetingsLeft: meetingsLeft,
          ),
        ),
        societyProvider: await society(tester),
      );
    }

    testWidgets('counts whole meetings attended', (tester) async {
      await pumpMeeting(tester, completed: 3.0, needed: 8);
      expect(find.text('3 / 8'), findsOneWidget);
    });

    testWidgets('floors a fractional count', (tester) async {
      await pumpMeeting(tester, completed: 3.9, needed: 8);
      expect(find.text('3 / 8'), findsOneWidget);
    });

    testWidgets('shows upcoming meetings when there are any', (tester) async {
      await pumpMeeting(tester, completed: 3, needed: 8, meetingsLeft: 2);
      expect(find.textContaining('2'), findsWidgets);
    });

    testWidgets('renders a zero meeting requirement safely', (tester) async {
      await pumpMeeting(tester, completed: 0, needed: 0);

      expect(tester.takeException(), isNull);
      for (final box in tester.widgetList<FractionallySizedBox>(
          find.byType(FractionallySizedBox))) {
        expect(box.widthFactor?.isNaN, isNot(isTrue));
      }
    });
  });
}
