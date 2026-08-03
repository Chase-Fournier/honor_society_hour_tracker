/// Shared `TextFormField` validators.
///
/// These existed inline at ~15 call sites and disagreed with each other:
/// "hours" was validated five different ways (`!= 0`, `> 0 && <= 999`, and
/// plain any-parseable) and URLs two ways (`hasScheme` alone versus
/// `hasScheme && hasAuthority`). Centralising them makes the rules testable and
/// consistent.
///
/// Each returns `null` when the value is acceptable, matching the
/// `FormFieldValidator<String>` contract.
class AppValidators {
  const AppValidators._();

  /// Requires any non-blank value.
  static String? required(String? value, {String message = 'Required'}) {
    return (value == null || value.trim().isEmpty) ? message : null;
  }

  /// A number of hours: required, numeric, greater than zero, at most [max].
  ///
  /// The strictest of the previous variants is used as the single rule. The
  /// looser ones accepted 0 (a no-op entry) or a negative value, and one
  /// accepted a value of any magnitude.
  static String? hours(String? value, {double max = 999}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';

    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter a number';
    if (parsed <= 0) return 'Must be greater than 0';
    if (parsed > max) return 'Too large';

    return null;
  }

  /// [hours], but blank is allowed — used by bulk edit, where an empty field
  /// means "leave the existing value alone".
  static String? optionalHours(String? value, {double max = 999}) {
    return (value == null || value.trim().isEmpty)
        ? null
        : hours(value, max: max);
  }

  /// A whole number of zero or more.
  static String? nonNegativeInt(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter a number';

    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) return 'Enter a valid number';

    return null;
  }

  /// A required whole number.
  static String? integer(String? value, {String message = 'Enter a number'}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return message;
    return int.tryParse(text) == null ? message : null;
  }

  /// An absolute URL.
  ///
  /// Requires both a scheme and an authority. Checking only `hasScheme` — as
  /// one call site did — accepts `mailto:x` and even a bare `foo:` as a valid
  /// link target.
  static String? url(String? value, {String message = 'Enter a valid URL'}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';

    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return message;

    return null;
  }

  /// [url], but blank is allowed.
  static String? optionalUrl(String? value,
      {String message = 'Enter a valid URL'}) {
    return (value == null || value.trim().isEmpty)
        ? null
        : url(value, message: message);
  }

  /// An email address.
  ///
  /// The previous check was `contains('@') && contains('.')`, which accepts
  /// ".@", "a@b." and "@.": a user could save an address that can never receive
  /// mail. This requires a non-empty local part, a domain, and a dot-separated
  /// TLD of at least two letters.
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your email address';

    final pattern = RegExp(r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)*\.[A-Za-z]{2,}$');
    if (!pattern.hasMatch(text)) return 'Please enter a valid email address';

    return null;
  }

  /// A new password: at least [minLength] characters.
  static String? password(String? value, {int minLength = 8}) {
    if (value == null || value.isEmpty) return 'Please enter a new password';
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  /// A password confirmation that has to equal [original].
  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your new password';
    }
    if (value != original) return 'Passwords do not match';
    return null;
  }
}
