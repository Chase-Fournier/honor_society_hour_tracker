import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/logic/signup_result.dart';

void main() {
  group('signupOutcomeFrom', () {
    // The three values the migration documents.
    test('maps the documented contract', () {
      expect(signupOutcomeFrom('ok'), SignupOutcome.ok);
      expect(signupOutcomeFrom('full'), SignupOutcome.full);
      expect(signupOutcomeFrom('already'), SignupOutcome.already);
    });

    test('anything else is unknown', () {
      expect(signupOutcomeFrom(null), SignupOutcome.unknown);
      expect(signupOutcomeFrom(''), SignupOutcome.unknown);
      expect(signupOutcomeFrom('OK'), SignupOutcome.unknown);
      expect(signupOutcomeFrom('waitlisted'), SignupOutcome.unknown);
      expect(signupOutcomeFrom(42), SignupOutcome.unknown);
      expect(signupOutcomeFrom(true), SignupOutcome.unknown);
      expect(signupOutcomeFrom(<String>[]), SignupOutcome.unknown);
    });
  });

  group('signupMessageFor', () {
    test('success says nothing; the UI refreshes instead', () {
      expect(signupMessageFor(SignupOutcome.ok), isNull);
    });

    test('a full slot explains why', () {
      expect(
          signupMessageFor(SignupOutcome.full), 'This time slot is now full.');
    });

    test('a duplicate signup explains why', () {
      expect(signupMessageFor(SignupOutcome.already),
          "You're already signed up for this slot.");
    });

    // Regression: the previous if/else chain matched only the three known
    // values, so a null return or a status added server-side left the user
    // tapping with no feedback and no signup.
    test('an unrecognised outcome still tells the user something', () {
      final message = signupMessageFor(SignupOutcome.unknown);
      expect(message, isNotNull);
      expect(message, isNotEmpty);
    });

    test('every outcome except ok produces a message', () {
      for (final outcome in SignupOutcome.values) {
        if (outcome == SignupOutcome.ok) continue;
        expect(signupMessageFor(outcome), isNotNull, reason: '$outcome');
      }
    });
  });

  test('a null RPC result is reported rather than silently ignored', () {
    // The end-to-end property that matters: the RPC returning nothing must not
    // look like success.
    final outcome = signupOutcomeFrom(null);
    expect(outcome, isNot(SignupOutcome.ok));
    expect(signupMessageFor(outcome), isNotNull);
  });
}
