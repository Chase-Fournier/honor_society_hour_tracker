import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/common/app_design.dart';
import 'package:nhs_tracker/common/app_widgets.dart';

import '../helpers/pump.dart';

void main() {
  group('AppCard', () {
    testWidgets('renders its child', (tester) async {
      await pumpInScaffold(tester, const AppCard(child: Text('hello')));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('is not tappable when onTap is null', (tester) async {
      await pumpInScaffold(tester, const AppCard(child: Text('hello')));
      expect(
        find.descendant(
            of: find.byType(AppCard), matching: find.byType(InkWell)),
        findsNothing,
      );
    });

    testWidgets('wraps in an InkWell and fires when onTap is given',
        (tester) async {
      var taps = 0;
      await pumpInScaffold(
        tester,
        AppCard(onTap: () => taps++, child: const Text('hello')),
      );

      expect(
        find.descendant(
            of: find.byType(AppCard), matching: find.byType(InkWell)),
        findsOneWidget,
      );

      await tester.tap(find.text('hello'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('defaults to the small elevation token', (tester) async {
      await pumpInScaffold(tester, const AppCard(child: Text('hello')));
      final card = tester.widget<Card>(
        find.descendant(of: find.byType(AppCard), matching: find.byType(Card)),
      );
      expect(card.elevation, AppDesign.elevationSmall);
    });
  });

  group('AppSurfaceCard', () {
    testWidgets('renders flat, delegating to AppCard', (tester) async {
      await pumpInScaffold(
          tester, const AppSurfaceCard(child: Text('surface')));

      expect(find.text('surface'), findsOneWidget);
      final card = tester.widget<Card>(
        find.descendant(
          of: find.byType(AppSurfaceCard),
          matching: find.byType(Card),
        ),
      );
      expect(card.elevation, 0);
    });
  });

  group('AppSectionHeader', () {
    testWidgets('shows the title alone', (tester) async {
      await pumpInScaffold(
          tester, const AppSectionHeader(title: 'Requirements'));

      expect(find.text('Requirements'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('shows the icon when given one', (tester) async {
      await pumpInScaffold(
        tester,
        const AppSectionHeader(title: 'Requirements', icon: Icons.checklist),
      );
      expect(find.byIcon(Icons.checklist), findsOneWidget);
    });

    testWidgets('shows the subtitle when given one', (tester) async {
      await pumpInScaffold(
        tester,
        const AppSectionHeader(title: 'Requirements', subtitle: '3 remaining'),
      );
      expect(find.text('3 remaining'), findsOneWidget);
    });

    testWidgets('shows icon and subtitle together', (tester) async {
      await pumpInScaffold(
        tester,
        const AppSectionHeader(
          title: 'Requirements',
          subtitle: '3 remaining',
          icon: Icons.checklist,
        ),
      );
      expect(find.text('Requirements'), findsOneWidget);
      expect(find.text('3 remaining'), findsOneWidget);
      expect(find.byIcon(Icons.checklist), findsOneWidget);
    });
  });

  group('AppTextField', () {
    testWidgets('surfaces the label and runs its validator', (tester) async {
      final formKey = GlobalKey<FormState>();
      await pumpInScaffold(
        tester,
        Form(
          key: formKey,
          child: const AppTextField(
            label: 'Graduation Year',
            validator: _alwaysFails,
          ),
        ),
      );

      expect(find.text('Graduation Year'), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('nope'), findsOneWidget);
    });

    testWidgets('passes text through to its controller', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpInScaffold(
        tester,
        AppTextField(label: 'Name', controller: controller),
      );

      await tester.enterText(find.byType(TextFormField), 'Alex');
      expect(controller.text, 'Alex');
    });

    testWidgets('obscures text when asked', (tester) async {
      await pumpInScaffold(
        tester,
        const AppTextField(label: 'Password', obscureText: true),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
    });
  });

  group('AppContentCard / AppGroupingCard', () {
    testWidgets('both render their child', (tester) async {
      await pumpInScaffold(
        tester,
        const Column(
          children: [
            AppContentCard(child: Text('content')),
            AppGroupingCard(child: Text('grouping')),
          ],
        ),
      );

      expect(find.text('content'), findsOneWidget);
      expect(find.text('grouping'), findsOneWidget);
    });

    testWidgets('AppGroupingCard stays flat', (tester) async {
      await pumpInScaffold(tester, const AppGroupingCard(child: Text('g')));
      final card = tester.widget<Card>(
        find.descendant(
          of: find.byType(AppGroupingCard),
          matching: find.byType(Card),
        ),
      );
      expect(card.elevation, 0);
    });
  });
}

String? _alwaysFails(String? _) => 'nope';
