// The contract of the `signup_for_timeslot` RPC.
//
// See supabase/migrations/20260613000001_signup_for_timeslot.sql. The function
// locks the slot row, enforces capacity and duplicate checks, inserts the
// attendee and decrements capacity in one transaction, returning a status
// string. It exists because the previous client flow did check-then-act on
// stale in-memory capacity and could oversell a slot.
//
// Extracted so the three documented outcomes -- and the undocumented fourth --
// can be tested without driving the whole home screen.

/// The documented return values, plus a catch-all.
enum SignupOutcome {
  /// Signed up.
  ok,

  /// No capacity left.
  full,

  /// Already signed up; the RPC is idempotent.
  already,

  /// Anything else: a null return, a transport hiccup, or a status added
  /// server-side that this build predates.
  unknown,
}

/// Maps the RPC's raw return value onto [SignupOutcome].
SignupOutcome signupOutcomeFrom(Object? rpcResult) {
  switch (rpcResult) {
    case 'ok':
      return SignupOutcome.ok;
    case 'full':
      return SignupOutcome.full;
    case 'already':
      return SignupOutcome.already;
    default:
      return SignupOutcome.unknown;
  }
}

/// User-facing message for an outcome, or null when there is nothing to say.
///
/// [SignupOutcome.ok] returns null because the UI reacts by refreshing rather
/// than by showing a message.
///
/// [SignupOutcome.unknown] deliberately returns a message. The previous
/// if/else chain matched only the three known values, so any other result left
/// the user tapping "sign up" with no feedback and no signup.
String? signupMessageFor(SignupOutcome outcome) {
  switch (outcome) {
    case SignupOutcome.ok:
      return null;
    case SignupOutcome.full:
      return 'This time slot is now full.';
    case SignupOutcome.already:
      return "You're already signed up for this slot.";
    case SignupOutcome.unknown:
      return 'Could not sign you up. Please try again.';
  }
}
