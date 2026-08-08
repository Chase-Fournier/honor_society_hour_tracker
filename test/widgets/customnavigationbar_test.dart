import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/common/customnavigationbar.dart';

import '../helpers/pump.dart';

void main() {
  // NavigationTabData has no const constructor, so these are built per call.
  final tabs = [
    NavigationTabData(title: 'Home', icon: Icons.home),
    NavigationTabData(
        title: 'Completed Hours', icon: Icons.checklist, shortText: 'Hours'),
    NavigationTabData(title: 'Settings', icon: Icons.settings),
  ];

  Future<List<int>> pumpBar(
    WidgetTester tester, {
    int selectedIndex = 0,
    bool isAdmin = false,
  }) async {
    final taps = <int>[];
    await pumpWithProviders(
      tester,
      CustomNavigationBar(
        selectedIndex: selectedIndex,
        onTabChanged: taps.add,
        tabs: tabs,
        isAdmin: isAdmin,
        body: const SizedBox.shrink(),
      ),
    );
    return taps;
  }

  group('rendering', () {
    testWidgets('shows an icon for every tab', (tester) async {
      await pumpBar(tester);

      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.checklist), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('labels only the selected tab', (tester) async {
      await pumpBar(tester, selectedIndex: 0);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('prefers shortText for the label when given', (tester) async {
      await pumpBar(tester, selectedIndex: 1);

      expect(find.text('Hours'), findsOneWidget);
      expect(find.text('Completed Hours'), findsNothing);
    });

    testWidgets('moves the label when the selection moves', (tester) async {
      await pumpBar(tester, selectedIndex: 2);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    });
  });

  group('tapping', () {
    testWidgets('reports the tapped index', (tester) async {
      final taps = await pumpBar(tester, selectedIndex: 0);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(taps, [2]);
    });

    // The widget returns early when the tapped index equals the current one.
    // Without that guard every tap on the active tab would rebuild the page and
    // reset its scroll position.
    testWidgets('tapping the already-selected tab is a no-op', (tester) async {
      final taps = await pumpBar(tester, selectedIndex: 0);

      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      expect(taps, isEmpty);
    });

    testWidgets('still reports other tabs after a no-op tap', (tester) async {
      final taps = await pumpBar(tester, selectedIndex: 0);

      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(taps, [2]);
    });
  });

  group('admin sizing', () {
    testWidgets('admin icons are smaller, to fit five tabs', (tester) async {
      await pumpBar(tester, isAdmin: false);
      final memberSize = tester.widget<Icon>(find.byIcon(Icons.settings)).size;

      await pumpBar(tester, isAdmin: true);
      final adminSize = tester.widget<Icon>(find.byIcon(Icons.settings)).size;

      expect(adminSize, lessThan(memberSize!));
    });

    testWidgets('renders without overflow in admin mode', (tester) async {
      await pumpBar(tester, isAdmin: true);
      expect(tester.takeException(), isNull);
    });
  });

  group('NavigationTabData', () {
    test('shortText is optional', () {
      final tab = NavigationTabData(title: 'Home', icon: Icons.home);
      expect(tab.shortText, isNull);
      expect(tab.title, 'Home');
    });
  });
}
