import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/common/app_validators.dart';

void main() {
  group('required', () {
    test('accepts text', () => expect(AppValidators.required('x'), isNull));
    test(
        'rejects null', () => expect(AppValidators.required(null), 'Required'));
    test('rejects empty', () => expect(AppValidators.required(''), 'Required'));
    test('rejects whitespace',
        () => expect(AppValidators.required('   '), 'Required'));
    test('honours a custom message',
        () => expect(AppValidators.required('', message: 'Name?'), 'Name?'));
  });

  group('hours', () {
    test('accepts a whole number',
        () => expect(AppValidators.hours('4'), isNull));
    test('accepts a decimal', () => expect(AppValidators.hours('2.5'), isNull));
    test('trims', () => expect(AppValidators.hours(' 2.5 '), isNull));

    test('rejects blank', () => expect(AppValidators.hours(''), 'Required'));
    test('rejects text',
        () => expect(AppValidators.hours('lots'), 'Enter a number'));

    // This is the member-facing submission rule, so a claim of no hours -- or
    // of negative hours -- is rejected. The admin hour-entry fields are
    // deliberately not on this validator; see the note on AppValidators.
    test('rejects zero',
        () => expect(AppValidators.hours('0'), 'Must be greater than 0'));
    test('rejects a negative',
        () => expect(AppValidators.hours('-3'), 'Must be greater than 0'));

    test('rejects an absurd value',
        () => expect(AppValidators.hours('1000'), 'Too large'));
    test('accepts the maximum',
        () => expect(AppValidators.hours('999'), isNull));
    test('honours a custom maximum',
        () => expect(AppValidators.hours('50', max: 24), 'Too large'));
  });

  group('nonNegativeInt', () {
    test('accepts zero',
        () => expect(AppValidators.nonNegativeInt('0'), isNull));
    test('accepts a positive',
        () => expect(AppValidators.nonNegativeInt('24'), isNull));
    test(
        'rejects a negative',
        () =>
            expect(AppValidators.nonNegativeInt('-1'), 'Enter a valid number'));
    test(
        'rejects a decimal',
        () => expect(
            AppValidators.nonNegativeInt('1.5'), 'Enter a valid number'));
    test('rejects blank',
        () => expect(AppValidators.nonNegativeInt(''), 'Enter a number'));
  });

  group('integer', () {
    test('accepts a whole number',
        () => expect(AppValidators.integer('7'), isNull));
    test('accepts a negative',
        () => expect(AppValidators.integer('-7'), isNull));
    test('rejects a decimal',
        () => expect(AppValidators.integer('7.5'), 'Enter a number'));
  });

  group('url', () {
    test('accepts https', () {
      expect(AppValidators.url('https://example.com/form'), isNull);
    });
    test(
        'accepts http', () => expect(AppValidators.url('http://x.io'), isNull));

    test('rejects blank', () => expect(AppValidators.url(''), 'Required'));
    test('rejects a bare domain with no scheme',
        () => expect(AppValidators.url('example.com'), isNotNull));

    // The hasScheme-only check accepted these as valid link targets.
    test('rejects a scheme with no authority', () {
      expect(AppValidators.url('mailto:someone@example.com'), isNotNull);
      expect(AppValidators.url('foo:'), isNotNull);
    });
  });

  group('optionalUrl', () {
    test('accepts blank', () => expect(AppValidators.optionalUrl(''), isNull));
    test('validates a supplied value',
        () => expect(AppValidators.optionalUrl('not a url'), isNotNull));
  });

  group('email', () {
    test('accepts an ordinary address',
        () => expect(AppValidators.email('member@example.com'), isNull));
    test('accepts a subdomain',
        () => expect(AppValidators.email('a@mail.example.co.uk'), isNull));
    test('accepts plus addressing',
        () => expect(AppValidators.email('a+tag@example.com'), isNull));
    test('trims', () => expect(AppValidators.email(' a@example.com '), isNull));

    test('rejects blank', () {
      expect(AppValidators.email(''), 'Please enter your email address');
      expect(AppValidators.email(null), 'Please enter your email address');
    });

    // Regression: the old check was `contains('@') && contains('.')`, so every
    // one of these was accepted and saved as a deliverable address.
    test('rejects addresses the old contains-based check let through', () {
      for (final bad in ['.@', '@.', 'a@b.', '.@.', '@example.com', 'a@.com']) {
        expect(AppValidators.email(bad), 'Please enter a valid email address',
            reason: 'should reject "$bad"');
      }
    });

    test('rejects a missing TLD',
        () => expect(AppValidators.email('a@b'), isNotNull));
    test('rejects a single-letter TLD',
        () => expect(AppValidators.email('a@b.c'), isNotNull));
    test('rejects whitespace inside',
        () => expect(AppValidators.email('a b@example.com'), isNotNull));
    test('rejects two @ signs',
        () => expect(AppValidators.email('a@b@example.com'), isNotNull));
  });

  group('password', () {
    test('accepts 8 characters',
        () => expect(AppValidators.password('12345678'), isNull));
    test('rejects 7', () {
      expect(AppValidators.password('1234567'),
          'Password must be at least 8 characters');
    });
    test(
        'rejects empty',
        () =>
            expect(AppValidators.password(''), 'Please enter a new password'));
    test('does not trim -- spaces are legitimate password characters', () {
      expect(AppValidators.password('        '), isNull);
    });
  });

  group('confirmPassword', () {
    test('accepts a match',
        () => expect(AppValidators.confirmPassword('abc', 'abc'), isNull));
    test('rejects a mismatch', () {
      expect(AppValidators.confirmPassword('abc', 'abd'),
          'Passwords do not match');
    });
    test('rejects empty', () {
      expect(AppValidators.confirmPassword('', 'abc'),
          'Please confirm your new password');
    });
  });
}
