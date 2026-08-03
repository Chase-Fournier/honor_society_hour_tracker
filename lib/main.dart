import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'providers/societyprovider.dart';
import 'providers/themeprovider.dart' as themeprovider;
import 'providers/themenotifier.dart'; // Add this import
import 'screens/loginpage.dart';
import 'screens/societyselectionpage.dart';
import 'screens/reset_password_page.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/hapticsprovider.dart';
import 'providers/notificationsprovider.dart';
import 'services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'data/supabase_client.dart';

enum SortOrder {
  ascending,
  descending,
}

enum SortField {
  name,
  totalHours,
  serviceHours,
  tutoringHours,
  meetingHours,
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hcuygigxjucxutavjvsc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhjdXlnaWd4anVjeHV0YXZqdnNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTI4NzU1NjgsImV4cCI6MjAyODQ1MTU2OH0.0x6jIeOANj6_Y5s7EQ9tuU3GhZLZblobDAt_W2dOLJA',
  );

  await NotificationService.instance.init();

  final themeNotifier = ThemeNotifier();
  final themeProvider = themeprovider.ThemeProvider();
  final societyProvider = SocietyProvider();
  final hapticsProvider = HapticsProvider();
  final notificationsProvider = NotificationsProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeNotifier),
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => societyProvider),
        ChangeNotifierProvider(create: (_) => hapticsProvider),
        ChangeNotifierProvider(create: (_) => notificationsProvider),
      ],
      child: MyApp(themeNotifier: themeNotifier),
    ),
  );
}

class MyApp extends StatefulWidget {
  final ThemeNotifier themeNotifier;

  const MyApp({super.key, required this.themeNotifier});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<AuthState>? _authSubscription; // To manage auth listener

  bool _isProcessingPasswordRecovery = false; // Flag for password recovery flow

  // Created once, not on every build. Recreating it inside build() made the
  // FutureBuilder revert to its "waiting" MaterialApp on each rebuild/hot
  // reload, swapping the root view and triggering the web engine's
  // "render a disposed EngineFlutterView" assertion.
  late final Future<void> _themeColorFuture =
      _fetchUserThemeColor(widget.themeNotifier);

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks(); // Instantiate AppLinks
    _initApp();
  }

  Future<void> _initApp() async {
    // Listen to Auth State Changes
    // It's important this listener is set up early.
    _authSubscription = supabase.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        final session = data.session;
        debugPrint(
            "Auth Event: $event, Session: ${session != null}, _isProcessingPasswordRecovery: $_isProcessingPasswordRecovery");

        // If we are specifically processing a password recovery,
        // let the deep link handler manage navigation to ResetPasswordPage.
        // The recovery token will create a session, hence AuthChangeEvent.signedIn might fire.
        if (_isProcessingPasswordRecovery &&
            (event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.passwordRecovery)) {
          debugPrint(
              "Auth event ($event) occurred while _isProcessingPasswordRecovery is true. ResetPasswordPage should be shown.");
          // Do NOT navigate to society_selection here.
          // The ResetPasswordPage will be pushed by _handleDeepLink.
          // After password is successfully reset from ResetPasswordPage, user will be sent to LoginPage.
          return;
        }

        // Standard auth flow
        switch (event) {
          case AuthChangeEvent.signedIn:
            debugPrint(
                "General Signed In event. Navigating to society selection.");
            Provider.of<SocietyProvider>(context, listen: false)
                .loadUserSocieties();
            // Only (re-)register this device for push if the user has
            // notifications enabled. Registering unconditionally would
            // re-add a device token that `setEnabled(false)` deliberately
            // removed, silently re-enabling push the user had turned off.
            if (Provider.of<NotificationsProvider>(context, listen: false)
                .enabled) {
              NotificationService.instance.registerForPush();
            }
            _navigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/society_selection', (route) => false);
            break;
          case AuthChangeEvent.signedOut:
            debugPrint("Signed Out event. Navigating to login ('/').");
            NotificationService.instance.unregisterDevice();
            _navigatorKey.currentState
                ?.pushNamedAndRemoveUntil('/', (route) => false);
            break;
          case AuthChangeEvent.passwordRecovery:
            // This event means Supabase has acknowledged the recovery token.
            // _isProcessingPasswordRecovery should already be true if triggered by our deep link.
            // If _isProcessingPasswordRecovery is false, this might be an unexpected state or a recovery
            // link handled outside the app's direct flow (less likely with deep links).
            debugPrint(
                "PasswordRecovery event. _isProcessingPasswordRecovery: $_isProcessingPasswordRecovery");
            // No automatic navigation here; _handleDeepLink takes precedence.
            break;
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
          case AuthChangeEvent.userDeleted:
          case AuthChangeEvent.initialSession:
          case AuthChangeEvent
                .mfaChallengeVerified: // Handle other events if necessary
            debugPrint("Auth event: $event");
            break;
        }
      },
      onError: (error) {
        debugPrint("Auth listener error: $error");
      },
    );

    // Listen to Deep Links
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null) {
          debugPrint('Received deep link stream: $uri');
          _handleDeepLink(uri);
        }
      },
      onError: (err) {
        debugPrint('Error receiving deep link stream: $err');
      },
    );

    // Process Initial Deep Link (if app was opened by one)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('Received initial deep link: $initialUri');
        _handleDeepLink(
            initialUri); // This might set _isProcessingPasswordRecovery
      } else {
        // No initial deep link, check current session for normal app start
        // Add a post frame callback to ensure BuildContext is ready for Provider
        // and Navigator is ready.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isProcessingPasswordRecovery &&
              supabase.auth.currentUser != null &&
              mounted) {
            debugPrint(
                "No initial deep link, user is signed in. Navigating to society selection.");
            Provider.of<SocietyProvider>(context, listen: false)
                .loadUserSocieties();
            _navigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/society_selection', (route) => false);
          } else if (supabase.auth.currentUser == null) {
            debugPrint(
                "No initial deep link, no current user. App should be on LoginPage ('/').");
          }
        });
      }
    } catch (e) {
      debugPrint('Error during initial deep link/auth check: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    debugPrint("Handling deep link: $uri");
    final isCustomSchemeRecovery =
        uri.scheme == 'com.wheelermun.nhs' && uri.host == 'reset-password';

    if (isCustomSchemeRecovery) {
      if (mounted) {
        setState(() {
          _isProcessingPasswordRecovery = true;
        });
      }
      debugPrint(
          "Password reset link identified. Set _isProcessingPasswordRecovery=true.");

      if (!uri.hasFragment) {
        debugPrint('Password reset link fragment is missing.');
        if (mounted) {
          setState(() {
            _isProcessingPasswordRecovery = false;
          });
        }
        return;
      }

      // The fragment is a "?-less" query string of the form
      //   access_token=...&type=recovery&...
      // Uri.splitQueryString parses that directly without the brittle
      // "?" + fragment hack the previous code used.
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      final accessToken = fragmentParams['access_token'];
      final type = fragmentParams['type'];

      if (accessToken != null && type == 'recovery') {
        debugPrint(
            "Access token for recovery found. Navigating to /reset-password.");
        _navigatorKey.currentState?.pushNamed(
          '/reset-password',
          arguments: ResetPasswordPageArguments(accessToken: accessToken),
        );
      } else {
        debugPrint(
            'Access token or recovery type missing/invalid in password reset link. Token: $accessToken, Type: $type');
        if (mounted) {
          setState(() {
            _isProcessingPasswordRecovery = false;
          });
        }
      }
    } else if (uri.scheme == 'com.wheelermun.nhs' && uri.host == 'callback') {
      // Handle other callbacks like email verification.
      // Ensure _isProcessingPasswordRecovery is false if it's not a password reset continuation.
      debugPrint('Received auth callback (e.g., email verification): $uri');
      if (mounted && _isProcessingPasswordRecovery) {
        setState(() {
          _isProcessingPasswordRecovery = false;
        });
      }
      // Supabase client handles the session for email verification.
      // The onAuthStateChange listener will then navigate appropriately (e.g., to login or society_selection).
    } else {
      // Unrelated deep link
      if (mounted && _isProcessingPasswordRecovery) {
        setState(() {
          _isProcessingPasswordRecovery = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel(); // Cancel the auth subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ThemeNotifier and ThemeProvider are already supplied by the MultiProvider
    // in main(). This used to open a *second* MultiProvider here that
    // constructed a fresh ThemeProvider, so the Consumer below resolved a
    // different instance from the one the rest of the app wrote to. Both wrote
    // the same 'themeMode' SharedPreferences key, so a theme change applied to
    // one instance and was only picked up by the other after a restart.
    return FutureBuilder<void>(
      future: _themeColorFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            localizationsDelegates: [
              FlutterQuillLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [
              Locale('en', 'US'),
            ],
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        return Consumer<themeprovider.ThemeProvider>(
          builder: (context, themeProvider, _) {
            return AnimatedBuilder(
              animation: widget.themeNotifier,
              builder: (context, _) {
                return MaterialApp(
                  localizationsDelegates: const [
                    FlutterQuillLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('en', 'US'),
                  ],
                  navigatorKey: _navigatorKey, // Assign the navigatorKey
                  title: 'Wheeler Honor Societies',
                  debugShowCheckedModeBanner: false,
                  theme: themeProvider
                      .getThemeData(widget.themeNotifier.themeColor),
                  initialRoute: '/',
                  routes: {
                    '/': (context) => const LoginPage(),
                    '/society_selection': (context) =>
                        const SocietySelectionPage(),
                    '/reset-password': (context) => const ResetPasswordPage(),
                  },
                  onGenerateRoute: (settings) {
                    if (settings.name == '/reset-password') {
                      final args =
                          settings.arguments as ResetPasswordPageArguments?;
                      String? accessToken = args?.accessToken;

                      return MaterialPageRoute(
                        builder: (context) => ResetPasswordPage(
                          accessToken: accessToken,
                          onPasswordResetFlowComplete: () {
                            if (mounted) {
                              // Ensure _MyAppState is still mounted
                              setState(() {
                                _isProcessingPasswordRecovery = false;
                                debugPrint(
                                    "ResetPasswordPage flow complete. _isProcessingPasswordRecovery set to false.");
                              });
                            }
                          },
                        ),
                        settings: settings,
                      );
                    }
                    if (settings.name == '/society_selection') {
                      return MaterialPageRoute(
                          builder: (context) => const SocietySelectionPage());
                    }
                    if (settings.name == '/') {
                      return MaterialPageRoute(
                          builder: (context) => const LoginPage());
                    }
                    // Handle other routes if necessary, or return null
                    return null;
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _fetchUserThemeColor(ThemeNotifier themeNotifier) async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('themeColor');
    final color = colorValue != null ? Color(colorValue) : Colors.blue;
    themeNotifier.updateThemeColor(color);
  }
}
