import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Runs once before every test file in this directory tree.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // AppTheme builds its text theme with GoogleFonts.workSans. Left enabled,
  // that reaches out to fonts.googleapis.com during a widget test, making the
  // suite slow, flaky and network-dependent. Disabling runtime fetching falls
  // back to the bundled default font instead.
  GoogleFonts.config.allowRuntimeFetching = false;

  // HapticsProvider gates its gaimon calls on
  // `defaultTargetPlatform == iOS || android` -- and under flutter_test that
  // platform defaults to **android**, so the gate is open and every haptic call
  // hits a MethodChannel with no implementation, throwing
  // MissingPluginException. Since nearly every interactive widget in the app
  // calls HapticsProvider, stubbing the channel here keeps haptics a silent
  // no-op for the whole suite rather than making each test remember.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('gaimon'), (call) async {
    // `canSupportsHaptic` is the capability probe; everything else just fires.
    if (call.method == 'canSupportsHaptic') return false;
    return null;
  });

  return testMain();
}
