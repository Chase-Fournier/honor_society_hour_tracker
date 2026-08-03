import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/common/app_form.dart';

import '../helpers/pump.dart';

void main() {
  /// Opens a form from a button, so the surrounding MediaQuery is the one
  /// showAppForm actually reads.
  Future<void> openForm(WidgetTester tester,
      {required Size surfaceSize}) async {
    await pumpWithProviders(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAppForm<void>(
                context: context,
                title: 'Edit Requirement',
                body: (_) => const Text('form body'),
                footer: (_) => [const Text('footer')],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      surfaceSize: surfaceSize,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showAppForm responsive branch', () {
    testWidgets('uses a bottom sheet below the breakpoint', (tester) async {
      await openForm(tester, surfaceSize: const Size(400, 900));

      // showModalBottomSheet builds a private widget, so the absence of a
      // Dialog is what distinguishes the sheet branch.
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Edit Requirement'), findsOneWidget);
      expect(find.text('form body'), findsOneWidget);
    });

    testWidgets('uses a dialog at or above the breakpoint', (tester) async {
      await openForm(tester, surfaceSize: const Size(1000, 900));

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Edit Requirement'), findsOneWidget);
    });

    testWidgets('the breakpoint itself counts as wide', (tester) async {
      await openForm(tester, surfaceSize: Size(kAppFormWideBreakpoint, 900));
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('one pixel below the breakpoint is narrow', (tester) async {
      await openForm(tester,
          surfaceSize: Size(kAppFormWideBreakpoint - 1, 900));
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('form body'), findsOneWidget);
    });

    testWidgets('renders the footer in the dialog layout', (tester) async {
      await openForm(tester, surfaceSize: const Size(1000, 900));
      expect(find.text('footer'), findsOneWidget);
    });
  });

  group('AppPickerField', () {
    testWidgets('shows the value when there is one', (tester) async {
      await pumpInScaffold(
        tester,
        AppPickerField(
          label: 'Icon',
          value: 'school',
          icon: Icons.image,
          onTap: () {},
        ),
      );

      expect(find.text('school'), findsOneWidget);
    });

    testWidgets('falls back to the hint when empty', (tester) async {
      await pumpInScaffold(
        tester,
        AppPickerField(
          label: 'Icon',
          hint: 'Pick an icon',
          icon: Icons.image,
          onTap: () {},
        ),
      );

      expect(find.text('Pick an icon'), findsOneWidget);
    });

    testWidgets('falls back to "Select" with no value and no hint',
        (tester) async {
      await pumpInScaffold(
        tester,
        AppPickerField(label: 'Icon', icon: Icons.image, onTap: () {}),
      );

      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await pumpInScaffold(
        tester,
        AppPickerField(
          label: 'Icon',
          value: 'school',
          icon: Icons.image,
          onTap: () => taps++,
        ),
      );

      await tester.tap(find.text('school'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('AppSwitchRow', () {
    testWidgets('reflects and toggles its value', (tester) async {
      bool? changedTo;
      await pumpInScaffold(
        tester,
        AppSwitchRow(
          title: 'Requires forms',
          value: false,
          onChanged: (v) => changedTo = v,
        ),
      );

      expect(find.text('Requires forms'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(changedTo, isTrue);
    });
  });

  group('AppFormSection', () {
    testWidgets('renders title and child', (tester) async {
      await pumpInScaffold(
        tester,
        const AppFormSection(title: 'Details', child: Text('inner')),
      );

      expect(find.text('Details'), findsOneWidget);
      expect(find.text('inner'), findsOneWidget);
    });
  });
}
