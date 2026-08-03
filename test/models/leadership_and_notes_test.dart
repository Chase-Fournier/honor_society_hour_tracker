import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/models/leadershiprole.dart';
import 'package:nhs_tracker/models/meetingnote.dart';

void main() {
  group('LeadershipRole', () {
    Map<String, dynamic> row() => {
          'id': 1,
          'title': 'President',
          'description': 'Runs meetings',
          'holder_name': 'Alex Rivera',
          'email': 'alex@example.com',
          'phone': '555-0100',
          'society_id': 3,
          'created_at': '2026-08-01T12:00:00.000Z',
          'is_active': true,
          'display_order': 2,
        };

    test('maps snake_case columns onto camelCase fields', () {
      final parsed = LeadershipRole.fromJson(row());

      expect(parsed.id, 1);
      expect(parsed.title, 'President');
      expect(parsed.holderName, 'Alex Rivera');
      expect(parsed.societyId, 3);
      expect(parsed.displayOrder, 2);
    });

    test('keeps optional contact details null when absent', () {
      final r = row()
        ..remove('email')
        ..remove('phone');
      final parsed = LeadershipRole.fromJson(r);

      expect(parsed.email, isNull);
      expect(parsed.phone, isNull);
    });

    test('defaults is_active and display_order', () {
      final r = row()
        ..remove('is_active')
        ..remove('display_order');
      final parsed = LeadershipRole.fromJson(r);

      expect(parsed.isActive, isTrue);
      expect(parsed.displayOrder, 0);
    });

    test('round-trips through toJson', () {
      final restored =
          LeadershipRole.fromJson(LeadershipRole.fromJson(row()).toJson());

      expect(restored.title, 'President');
      expect(restored.holderName, 'Alex Rivera');
      expect(restored.societyId, 3);
      expect(restored.email, 'alex@example.com');
      expect(restored.displayOrder, 2);
    });

    test('copyWith overrides only what it is given', () {
      final original = LeadershipRole.fromJson(row());
      final copy = original.copyWith(title: 'Vice President');

      expect(copy.title, 'Vice President');
      expect(copy.holderName, original.holderName);
      expect(copy.id, original.id);
    });

    test('copyWith with nothing returns an equivalent role', () {
      final original = LeadershipRole.fromJson(row());
      final copy = original.copyWith();

      expect(copy.title, original.title);
      expect(copy.displayOrder, original.displayOrder);
    });

    test('throws when a required column is null', () {
      final r = row()..['created_at'] = null;
      expect(() => LeadershipRole.fromJson(r), throwsA(anything));
    });
  });

  group('MeetingNote', () {
    Map<String, dynamic> row() => {
          'id': 1,
          'title': 'September Meeting',
          'text': 'Plain text body',
          'content': '{"ops":[{"insert":"rich"}]}',
          'created_at': '2026-09-01T18:00:00.000Z',
        };

    test('maps its columns', () {
      final parsed = MeetingNote.fromJson(row());

      expect(parsed.id, 1);
      expect(parsed.title, 'September Meeting');
      expect(parsed.text, 'Plain text body');
      expect(parsed.createdAt.toUtc(), DateTime.utc(2026, 9, 1, 18));
    });

    // `content` holds the Quill delta; older notes predate it and have only
    // the plain-text `text` column.
    test('keeps content null for a legacy note', () {
      final r = row()..remove('content');
      expect(MeetingNote.fromJson(r).content, isNull);
    });

    test('defaults title and text to empty rather than throwing', () {
      final r = row()
        ..remove('title')
        ..remove('text');
      final parsed = MeetingNote.fromJson(r);

      expect(parsed.title, '');
      expect(parsed.text, '');
    });

    test('throws when created_at is missing', () {
      final r = row()..remove('created_at');
      expect(() => MeetingNote.fromJson(r), throwsA(anything));
    });
  });
}
