import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The canonical Supabase client for the whole app.
///
/// This is deliberately a **getter**, not a top-level `final`. Dart evaluates a
/// top-level `final` the first time its library is touched, and
/// `Supabase.instance` throws when `Supabase.initialize()` has not run yet — so
/// the old per-file `final supabase = Supabase.instance.client;` declarations
/// made a file impossible to even *import* from a test. Resolving lazily on each
/// access keeps importing a screen free of side effects.
///
/// Tests swap in a fake via [supabaseOverride]; see
/// `test/helpers/fake_supabase.dart`.
SupabaseClient get supabase => _override ?? Supabase.instance.client;

SupabaseClient? _override;

/// Replaces the client returned by [supabase]. Pass `null` to restore the real
/// one — tests must do this in teardown or they leak into each other.
@visibleForTesting
set supabaseOverride(SupabaseClient? client) => _override = client;

/// The currently installed override, or `null` when [supabase] resolves to the
/// real client.
@visibleForTesting
SupabaseClient? get supabaseOverride => _override;
