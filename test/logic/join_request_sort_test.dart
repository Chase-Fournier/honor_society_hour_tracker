import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/logic/join_request_sort.dart';
import 'package:nhs_tracker/models/joinrequest.dart';

JoinRequest request({
  int id = 1,
  String status = 'pending',
  String userName = 'Alex Rivera',
  String graduationYear = '2027',
  DateTime? requestedAt,
  DateTime? processedAt,
}) =>
    JoinRequest(
      id: id,
      status: status,
      userId: 'u$id',
      userName: userName,
      userEmail: '$userName@example.com',
      graduationYear: graduationYear,
      requestedAt: requestedAt ?? DateTime(2026, 8, 1),
      processedAt: processedAt,
    );

List<String> names(List<JoinRequest> requests) =>
    requests.map((r) => r.userName).toList();

void main() {
  group('gradYearValue', () {
    test('parses a year', () {
      expect(gradYearValue(request(graduationYear: '2026')), 2026);
    });
    test('trims', () {
      expect(gradYearValue(request(graduationYear: ' 2026 ')), 2026);
    });
    test('missing sorts last', () {
      expect(gradYearValue(request(graduationYear: '')), 9999);
    });
    test('unparseable sorts last', () {
      expect(gradYearValue(request(graduationYear: 'n/a')), 9999);
    });
  });

  group('statusRank', () {
    test('puts pending first, so the queue is on top', () {
      expect(statusRank('pending'), 0);
    });

    test('orders the processed statuses', () {
      expect(statusRank('approved'), 1);
      expect(statusRank('rejected'), 2);
      expect(statusRank('revoked'), 3);
    });

    test('an unknown status sorts after everything known', () {
      expect(statusRank('withdrawn'), 4);
      expect(statusRank(''), 4);
    });
  });

  group('sortJoinRequests', () {
    test('by name, case-insensitively', () {
      final result = sortJoinRequests(
        [
          request(id: 1, userName: 'charlie'),
          request(id: 2, userName: 'Alice'),
          request(id: 3, userName: 'Bob'),
        ],
        field: RequestSortField.name,
      );
      expect(names(result), ['Alice', 'Bob', 'charlie']);
    });

    test('descending reverses the order', () {
      final result = sortJoinRequests(
        [
          request(id: 1, userName: 'Alice'),
          request(id: 2, userName: 'Bob'),
        ],
        field: RequestSortField.name,
        order: RequestSortOrder.descending,
      );
      expect(names(result), ['Bob', 'Alice']);
    });

    test('by graduation year, numerically', () {
      final result = sortJoinRequests(
        [
          request(id: 1, userName: 'Later', graduationYear: '2028'),
          request(id: 2, userName: 'Earlier', graduationYear: '999'),
        ],
        field: RequestSortField.graduationYear,
      );
      expect(names(result), ['Earlier', 'Later']);
    });

    test('members with no graduation year sort last', () {
      final result = sortJoinRequests(
        [
          request(id: 1, userName: 'Unknown', graduationYear: ''),
          request(id: 2, userName: 'Known', graduationYear: '2027'),
        ],
        field: RequestSortField.graduationYear,
      );
      expect(names(result), ['Known', 'Unknown']);
    });

    test('by status, pending first', () {
      final result = sortJoinRequests(
        [
          request(id: 1, userName: 'Revoked', status: 'revoked'),
          request(id: 2, userName: 'Pending', status: 'pending'),
          request(id: 3, userName: 'Approved', status: 'approved'),
        ],
        field: RequestSortField.status,
      );
      expect(names(result), ['Pending', 'Approved', 'Revoked']);
    });

    test('by requested date', () {
      final result = sortJoinRequests(
        [
          request(id: 1, userName: 'Second', requestedAt: DateTime(2026, 8, 2)),
          request(id: 2, userName: 'First', requestedAt: DateTime(2026, 8, 1)),
        ],
        field: RequestSortField.requestedAt,
      );
      expect(names(result), ['First', 'Second']);
    });

    test('unprocessed requests fall back to the epoch and group first', () {
      final result = sortJoinRequests(
        [
          request(
              id: 1, userName: 'Processed', processedAt: DateTime(2026, 8, 5)),
          request(id: 2, userName: 'Unprocessed'),
        ],
        field: RequestSortField.processedAt,
      );
      expect(names(result), ['Unprocessed', 'Processed']);
    });

    test('equal keys fall back to name then id, so order is stable', () {
      final tied = [
        request(id: 3, userName: 'Same', status: 'pending'),
        request(id: 1, userName: 'Same', status: 'pending'),
        request(id: 2, userName: 'Same', status: 'pending'),
      ];

      final first = sortJoinRequests(tied, field: RequestSortField.status);
      final second =
          sortJoinRequests(tied.reversed, field: RequestSortField.status);

      expect(first.map((r) => r.id).toList(), [1, 2, 3]);
      expect(second.map((r) => r.id).toList(), [1, 2, 3]);
    });

    test('does not mutate the caller\'s list', () {
      final original = [
        request(id: 2, userName: 'Bob'),
        request(id: 1, userName: 'Alice'),
      ];
      final ids = original.map((r) => r.id).toList();

      sortJoinRequests(original, field: RequestSortField.name);

      expect(original.map((r) => r.id).toList(), ids);
    });

    test('handles an empty list', () {
      expect(sortJoinRequests(const <JoinRequest>[]), isEmpty);
    });
  });

  group('JoinRequest.fromJson', () {
    Map<String, dynamic> row() => {
          'id': 1,
          'status': 'pending',
          'user_id': 'u1',
          'userName': 'Alex',
          'userEmail': 'alex@example.com',
          'graduation_year': 2027,
          'requested_at': '2026-08-01T12:00:00.000Z',
        };

    test('maps the mixed camelCase and snake_case keys', () {
      final parsed = JoinRequest.fromJson(row());
      expect(parsed.userName, 'Alex');
      expect(parsed.userId, 'u1');
      expect(parsed.graduationYear, '2027');
    });

    test('coerces an int graduation_year to a string', () {
      expect(JoinRequest.fromJson(row()).graduationYear, isA<String>());
    });

    test('accepts a string graduation_year too', () {
      final parsed = JoinRequest.fromJson(row()..['graduation_year'] = '2028');
      expect(parsed.graduationYear, '2028');
    });

    test('falls back for a missing name and email', () {
      final r = row()
        ..remove('userName')
        ..remove('userEmail');
      final parsed = JoinRequest.fromJson(r);
      expect(parsed.userName, 'Unknown User');
      expect(parsed.userEmail, 'No email');
    });

    test('leaves processedAt null while pending', () {
      expect(JoinRequest.fromJson(row()).processedAt, isNull);
    });

    test('parses processed_at when present', () {
      final r = row()..['processed_at'] = '2026-08-05T09:00:00.000Z';
      expect(JoinRequest.fromJson(r).processedAt, isNotNull);
    });
  });

  group('JoinRequest.copyWith', () {
    test('updates status and processing metadata', () {
      final copy = request().copyWith(
        status: 'approved',
        processedAt: () => DateTime(2026, 8, 5),
        processorName: () => 'You',
      );

      expect(copy.status, 'approved');
      expect(copy.processedAt, DateTime(2026, 8, 5));
      expect(copy.processorName, 'You');
      expect(copy.id, 1);
      expect(copy.userName, 'Alex Rivera');
    });

    // Reverting an approval back to pending needs the timestamps cleared;
    // `?? this.processedAt` made that impossible.
    test('can clear the processing metadata', () {
      final processed = request(processedAt: DateTime(2026, 8, 5))
          .copyWith(status: 'approved', processorName: () => 'You');

      final reverted = processed.copyWith(
        status: 'pending',
        processedAt: () => null,
        processorName: () => null,
      );

      expect(reverted.status, 'pending');
      expect(reverted.processedAt, isNull);
      expect(reverted.processorName, isNull);
    });

    test('leaves untouched fields alone', () {
      final copy = request(processedAt: DateTime(2026, 8, 5))
          .copyWith(status: 'revoked');
      expect(copy.processedAt, DateTime(2026, 8, 5));
    });
  });
}
