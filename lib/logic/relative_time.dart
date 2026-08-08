import 'package:clock/clock.dart';
import 'package:intl/intl.dart';

/// Relative "time ago" formatting.
///
/// Two styles exist because the app genuinely renders two. They were previously
/// two private `_getTimeAgo` methods that looked like copies but were not:
/// the meeting-notes sheet says "3 weeks ago" while the admin dashboard says
/// "3d ago". Both are preserved verbatim rather than merged, so extracting them
/// changes no pixels.
///
/// Both read [clock] rather than `DateTime.now()`, so tests can pin the
/// reference instant with `withClock`.

/// Verbose style, used by the meeting-notes sheet.
///
/// Falls back to an absolute date ("Jun 18, 2026") past 30 days.
///
/// Note the boundaries are strict `>`, so exactly 7 days reads "7 days ago"
/// rather than "1 week ago"; the first "1 week ago" appears at 8 days. Future
/// timestamps yield a negative difference and read "Just now".
String timeAgo(DateTime dateTime, {DateTime? now}) {
  final difference = (now ?? clock.now()).difference(dateTime);

  if (difference.inDays > 30) {
    return DateFormat('MMM d, y').format(dateTime);
  } else if (difference.inDays > 7) {
    final weeks = (difference.inDays / 7).floor();
    return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
  } else {
    return 'Just now';
  }
}

/// Compact style, used by the admin dashboard's activity feed.
///
/// Falls back to an absolute date ("Jun 18") past 7 days — a shorter window and
/// a shorter format than [timeAgo].
String timeAgoShort(DateTime dateTime, {DateTime? now}) {
  final difference = (now ?? clock.now()).difference(dateTime);

  if (difference.inDays > 7) {
    return DateFormat('MMM d').format(dateTime);
  } else if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  } else {
    return 'Just now';
  }
}
