/// Shared rules for the graduation year field.
///
/// The accepted range is a rolling window anchored on the current year, so it
/// never needs to be bumped by hand — in 2026 it spans 1970 to 2050.
class GraduationYearUtils {
  static const int _yearsBehind = 56;
  static const int _yearsAhead = 24;

  static int get minYear => DateTime.now().year - _yearsBehind;
  static int get maxYear => DateTime.now().year + _yearsAhead;

  /// `TextFormField` validator: requires a 4-digit year inside the window.
  static String? validate(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Please enter your graduation year';
    }

    final year = int.tryParse(text);
    if (year == null || text.length != 4) {
      return 'Enter a 4-digit year';
    }

    if (year < minYear || year > maxYear) {
      return 'Enter a year between $minYear and $maxYear';
    }

    return null;
  }
}
