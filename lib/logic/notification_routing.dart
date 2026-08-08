// Where a tapped notification should land the user.
//
// Extracted from `_MainScreenState._tabForPayload`, which was already pure but
// unreachable from a test.

/// Maps a notification `type` to a top-level tab index for the current role.
///
/// Returns null when there is no sensible destination, meaning "stay put".
///
/// The two shells have different tab sets, which is why the role matters:
/// admin is Dashboard / Events / Attendance / Lists / Settings, member is
/// Home / Completed Hours / Settings.
int? tabForNotificationType(String? type, {required bool isAdmin}) {
  switch (type) {
    case 'event':
      return isAdmin ? 1 : 0; // Events / Home
    case 'meeting_notes':
      return 0; // Dashboard / Home
    case 'hours':
      return isAdmin ? 2 : 1; // Attendance / Completed Hours
    case 'swap':
      return isAdmin ? 2 : 0; // Attendance / Home
    case 'continuous_submission':
      return isAdmin ? 0 : 1; // Dashboard / Completed Hours
    default:
      return null;
  }
}

/// Number of tabs in each shell, used to keep [tabForNotificationType] honest.
const int kAdminTabCount = 5;
const int kMemberTabCount = 3;
