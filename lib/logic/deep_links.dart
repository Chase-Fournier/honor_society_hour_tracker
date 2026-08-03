// Deep-link parsing, separated from the navigation it drives.
//
// The URL parsing used to be fused into `_MyAppState._handleDeepLink` alongside
// `setState` and navigator pushes, so none of it could be tested.
// `parseDeepLink` is the pure half; `main.dart` keeps the side effects.

/// The app's custom URL scheme. Registered in `AndroidManifest.xml` and
/// `Info.plist`; changing it here alone is not enough.
const String kAppUrlScheme = 'com.wheelermun.nhs';

/// What a deep link is asking the app to do.
enum DeepLinkAction {
  /// A valid password-recovery link carrying an access token.
  passwordRecovery,

  /// A recovery link that is malformed — right scheme and host, but no usable
  /// token. The recovery flow must be abandoned rather than left half-armed.
  invalidPasswordRecovery,

  /// An auth callback, e.g. email verification. The Supabase client picks the
  /// session up on its own; the auth listener handles navigation.
  authCallback,

  /// Nothing this app routes.
  unrelated,
}

/// The parsed meaning of a deep link.
class DeepLinkIntent {
  const DeepLinkIntent(this.action, {this.accessToken});

  final DeepLinkAction action;

  /// Only set for [DeepLinkAction.passwordRecovery].
  final String? accessToken;

  /// Whether this link should arm the password-recovery guard, which suppresses
  /// the normal sign-in navigation so `ResetPasswordPage` can take over.
  ///
  /// True for a malformed recovery link too: the guard is armed the moment a
  /// recovery link is recognised, and the caller must disarm it.
  bool get isRecoveryAttempt =>
      action == DeepLinkAction.passwordRecovery ||
      action == DeepLinkAction.invalidPasswordRecovery;

  @override
  String toString() =>
      'DeepLinkIntent($action, hasToken: ${accessToken != null})';
}

/// Classifies [uri] without performing any navigation.
DeepLinkIntent parseDeepLink(Uri uri) {
  if (uri.scheme != kAppUrlScheme) {
    return const DeepLinkIntent(DeepLinkAction.unrelated);
  }

  switch (uri.host) {
    case 'reset-password':
      return _parseRecovery(uri);
    case 'callback':
      return const DeepLinkIntent(DeepLinkAction.authCallback);
    default:
      return const DeepLinkIntent(DeepLinkAction.unrelated);
  }
}

DeepLinkIntent _parseRecovery(Uri uri) {
  if (!uri.hasFragment) {
    return const DeepLinkIntent(DeepLinkAction.invalidPasswordRecovery);
  }

  // Supabase puts the token in the fragment as a "?-less" query string:
  //   access_token=...&type=recovery&...
  // Uri.splitQueryString parses that directly.
  final Map<String, String> params;
  try {
    params = Uri.splitQueryString(uri.fragment);
  } on FormatException {
    return const DeepLinkIntent(DeepLinkAction.invalidPasswordRecovery);
  }

  final accessToken = params['access_token'];
  final type = params['type'];

  if (accessToken != null && accessToken.isNotEmpty && type == 'recovery') {
    return DeepLinkIntent(
      DeepLinkAction.passwordRecovery,
      accessToken: accessToken,
    );
  }

  return const DeepLinkIntent(DeepLinkAction.invalidPasswordRecovery);
}
