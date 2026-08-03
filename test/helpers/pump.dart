import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhs_tracker/providers/hapticsprovider.dart';
import 'package:nhs_tracker/providers/notificationsprovider.dart';
import 'package:nhs_tracker/providers/societyprovider.dart';
import 'package:nhs_tracker/providers/themenotifier.dart';
import 'package:nhs_tracker/providers/themeprovider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps [child] inside the app's provider stack and a `MaterialApp`.
///
/// Nearly every interactive widget in this app reaches for
/// `Provider.of<HapticsProvider>(context, listen: false)` -- including
/// `CustomNavigationBar`, `AppPickerField` and `AppSwitchRow` -- so a bare
/// `pumpWidget` throws a ProviderNotFoundException. This supplies the whole
/// stack so individual tests do not have to remember which one they need.
///
/// Pass [surfaceSize] to exercise the responsive breakpoints: list screens
/// switch to a table layout above 900px, and `showAppForm` switches from a
/// bottom sheet to a dialog above 720px.
Future<void> pumpWithProviders(
  WidgetTester tester,
  Widget child, {
  SocietyProvider? societyProvider,
  HapticsProvider? hapticsProvider,
  NotificationsProvider? notificationsProvider,
  ThemeProvider? themeProvider,
  ThemeNotifier? themeNotifier,
  Size? surfaceSize,
  ThemeData? theme,
  NavigatorObserver? navigatorObserver,
}) async {
  // Every one of these providers reads SharedPreferences in its constructor.
  SharedPreferences.setMockInitialValues(const {});

  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeNotifier>.value(
          value: themeNotifier ?? ThemeNotifier(),
        ),
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider ?? ThemeProvider(),
        ),
        ChangeNotifierProvider<HapticsProvider>.value(
          value: hapticsProvider ?? HapticsProvider(),
        ),
        ChangeNotifierProvider<NotificationsProvider>.value(
          value: notificationsProvider ?? NotificationsProvider(),
        ),
        if (societyProvider != null)
          ChangeNotifierProvider<SocietyProvider>.value(value: societyProvider),
      ],
      child: MaterialApp(
        theme: theme,
        // flutter_quill crashes without its delegate, and several screens
        // embed a Quill editor.
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        navigatorObservers: [
          if (navigatorObserver != null) navigatorObserver,
        ],
        home: child,
      ),
    ),
  );
}

/// [pumpWithProviders] wrapping [child] in a `Scaffold`.
///
/// Use for widgets that expect Material scaffolding around them -- anything
/// showing a snackbar, bottom sheet, or `ListTile`.
Future<void> pumpInScaffold(
  WidgetTester tester,
  Widget child, {
  Size? surfaceSize,
  ThemeData? theme,
  HapticsProvider? hapticsProvider,
  SocietyProvider? societyProvider,
}) {
  return pumpWithProviders(
    tester,
    Scaffold(body: child),
    surfaceSize: surfaceSize,
    theme: theme,
    hapticsProvider: hapticsProvider,
    societyProvider: societyProvider,
  );
}
