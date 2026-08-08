import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/common/normalizetype.dart';

void main() {
  group('normalizeType', () {
    test('title-cases a single lowercase word', () {
      expect(normalizeType('service'), 'Service');
    });

    test('title-cases every word', () {
      expect(normalizeType('community service'), 'Community Service');
    });

    test('lowercases the tail of a shouted word', () {
      expect(normalizeType('SERVICE'), 'Service');
    });

    test('normalizes mixed case to a single canonical form', () {
      expect(normalizeType('sErViCe'), normalizeType('SERVICE'));
      expect(normalizeType('sErViCe'), 'Service');
    });

    test('trims surrounding whitespace', () {
      expect(normalizeType('  tutoring  '), 'Tutoring');
    });

    test('handles a single character', () {
      expect(normalizeType('a'), 'A');
    });

    test('returns empty for an empty string', () {
      expect(normalizeType(''), '');
    });

    test('returns empty for whitespace only', () {
      expect(normalizeType('   '), '');
    });

    // Interior runs of spaces are preserved as empty tokens rather than
    // collapsed, so the round-trip keeps the original spacing.
    test('preserves interior double spaces', () {
      expect(normalizeType('community  service'), 'Community  Service');
    });

    // Only spaces split words -- tabs and newlines are not separators, and
    // trim() strips them only at the ends.
    test('does not treat a tab as a word separator', () {
      expect(normalizeType('community\tservice'), 'Community\tservice');
    });

    test('is idempotent', () {
      for (final input in [
        'service',
        'COMMUNITY SERVICE',
        '  tutoring ',
        '',
        'a  b',
      ]) {
        final once = normalizeType(input);
        expect(normalizeType(once), once, reason: 'input: "$input"');
      }
    });
  });
}
