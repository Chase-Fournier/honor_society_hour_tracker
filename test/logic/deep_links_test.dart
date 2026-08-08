import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/logic/deep_links.dart';

void main() {
  DeepLinkIntent parse(String uri) => parseDeepLink(Uri.parse(uri));

  group('password recovery', () {
    test('recognises a valid recovery link and extracts the token', () {
      final intent = parse(
        '$kAppUrlScheme://reset-password#access_token=abc123&type=recovery',
      );

      expect(intent.action, DeepLinkAction.passwordRecovery);
      expect(intent.accessToken, 'abc123');
      expect(intent.isRecoveryAttempt, isTrue);
    });

    test('reads the token regardless of parameter order', () {
      final intent = parse(
        '$kAppUrlScheme://reset-password#type=recovery&expires_in=3600&access_token=xyz',
      );
      expect(intent.accessToken, 'xyz');
    });

    test('a URL-encoded token is decoded', () {
      final intent = parse(
        '$kAppUrlScheme://reset-password#access_token=a%2Bb%3Dc&type=recovery',
      );
      expect(intent.accessToken, 'a+b=c');
    });

    test('a recovery link with no fragment is invalid', () {
      final intent = parse('$kAppUrlScheme://reset-password');

      expect(intent.action, DeepLinkAction.invalidPasswordRecovery);
      expect(intent.accessToken, isNull);
      // Still counts as a recovery attempt: the guard is armed the moment the
      // link is recognised, and the caller has to disarm it.
      expect(intent.isRecoveryAttempt, isTrue);
    });

    test('a fragment without an access token is invalid', () {
      final intent = parse('$kAppUrlScheme://reset-password#type=recovery');
      expect(intent.action, DeepLinkAction.invalidPasswordRecovery);
    });

    test('an empty access token is invalid', () {
      final intent =
          parse('$kAppUrlScheme://reset-password#access_token=&type=recovery');
      expect(intent.action, DeepLinkAction.invalidPasswordRecovery);
    });

    test('the wrong type is invalid even with a token', () {
      final intent = parse(
        '$kAppUrlScheme://reset-password#access_token=abc&type=signup',
      );
      expect(intent.action, DeepLinkAction.invalidPasswordRecovery);
      expect(intent.accessToken, isNull);
    });

    test('a missing type is invalid', () {
      final intent = parse('$kAppUrlScheme://reset-password#access_token=abc');
      expect(intent.action, DeepLinkAction.invalidPasswordRecovery);
    });
  });

  group('auth callback', () {
    test('is recognised', () {
      final intent = parse('$kAppUrlScheme://callback#access_token=abc');

      expect(intent.action, DeepLinkAction.authCallback);
      // Must not arm the recovery guard -- doing so would suppress the normal
      // sign-in navigation after email verification.
      expect(intent.isRecoveryAttempt, isFalse);
    });

    test('is recognised with no fragment', () {
      expect(parse('$kAppUrlScheme://callback').action,
          DeepLinkAction.authCallback);
    });
  });

  group('unrelated links', () {
    test('a different scheme is ignored, even on a matching host', () {
      final intent = parse(
        'https://example.com/reset-password#access_token=abc&type=recovery',
      );

      expect(intent.action, DeepLinkAction.unrelated);
      expect(intent.accessToken, isNull);
      expect(intent.isRecoveryAttempt, isFalse);
    });

    test('an unknown host on our scheme is ignored', () {
      expect(parse('$kAppUrlScheme://something-else').action,
          DeepLinkAction.unrelated);
    });

    test('a bare app-scheme link with no host is ignored', () {
      expect(parse('$kAppUrlScheme://').action, DeepLinkAction.unrelated);
    });

    test('an http link is ignored', () {
      expect(parse('http://wheelermun.com').action, DeepLinkAction.unrelated);
    });
  });

  test('the scheme constant matches the one registered on the platforms', () {
    // Changing this alone is not enough -- AndroidManifest.xml and Info.plist
    // carry the same value.
    expect(kAppUrlScheme, 'com.wheelermun.nhs');
  });

  test('never throws on hostile input', () {
    for (final uri in [
      '$kAppUrlScheme://reset-password#%%%',
      '$kAppUrlScheme://reset-password#=noKey',
      '$kAppUrlScheme://reset-password#access_token',
      '$kAppUrlScheme://reset-password#&&&',
      '$kAppUrlScheme://RESET-PASSWORD#access_token=a&type=recovery',
    ]) {
      expect(() => parse(uri), returnsNormally, reason: uri);
    }
  });
}
