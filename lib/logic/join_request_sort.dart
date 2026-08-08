import '../models/joinrequest.dart';

/// Sorting for the join-requests admin screen.
///
/// Extracted from `_JoinRequestsAdminPageState` unchanged. This is the
/// best-behaved sort in the app — it already has a stable tiebreak and treats a
/// missing graduation year as "sorts last" — so it is the reference the roster
/// sort in `user_filtering.dart` was aligned to.

enum RequestSortField {
  name,
  graduationYear,
  status,
  requestedAt,
  processedAt,
}

enum RequestSortOrder { ascending, descending }

/// Graduation year as a sortable int. Members with no year on file get 9999 so
/// they sort last in ascending order rather than first.
int gradYearValue(JoinRequest request) =>
    int.tryParse(request.graduationYear.trim()) ?? 9999;

/// Display order for statuses: pending first, so the admin's queue is on top.
/// An unrecognised status sorts after all the known ones.
int statusRank(String status) {
  switch (status) {
    case 'pending':
      return 0;
    case 'approved':
      return 1;
    case 'rejected':
      return 2;
    case 'revoked':
      return 3;
    default:
      return 4;
  }
}

/// Sorts [requests] without mutating the caller's collection.
List<JoinRequest> sortJoinRequests(
  Iterable<JoinRequest> requests, {
  RequestSortField field = RequestSortField.requestedAt,
  RequestSortOrder order = RequestSortOrder.ascending,
}) {
  final list = requests.toList();

  list.sort((a, b) {
    int comparison;
    switch (field) {
      case RequestSortField.name:
        comparison =
            a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
        break;
      case RequestSortField.graduationYear:
        comparison = gradYearValue(a).compareTo(gradYearValue(b));
        break;
      case RequestSortField.status:
        comparison = statusRank(a.status).compareTo(statusRank(b.status));
        break;
      case RequestSortField.requestedAt:
        comparison = a.requestedAt.compareTo(b.requestedAt);
        break;
      case RequestSortField.processedAt:
        // Unprocessed requests fall back to the epoch, so they group together
        // at one end instead of ordering arbitrarily.
        final aProcessed =
            a.processedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bProcessed =
            b.processedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        comparison = aProcessed.compareTo(bProcessed);
        break;
    }

    // Stable, predictable tiebreak so equal keys don't shuffle between builds.
    if (comparison == 0) {
      comparison = a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
    }
    if (comparison == 0) comparison = a.id.compareTo(b.id);

    return order == RequestSortOrder.ascending ? comparison : -comparison;
  });

  return list;
}
