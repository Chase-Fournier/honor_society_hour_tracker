import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'providers/societyprovider.dart';
import 'providers/themeprovider.dart' as themeprovider;
import 'providers/themenotifier.dart';
import 'screens/loginpage.dart';
import 'screens/societyselectionpage.dart';

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

  final themeNotifier = ThemeNotifier();
  final themeProvider = themeprovider.ThemeProvider();
  final societyProvider = SocietyProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeNotifier),
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => societyProvider),
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
  @override
  void initState() {
    super.initState();

    // Listen for auth state changes to reload societies when user signs in/out
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        // User signed in, load their societies
        Provider.of<SocietyProvider>(context, listen: false)
            .loadUserSocieties();
      } else if (event == AuthChangeEvent.signedOut) {
        // User signed out, clear provider data
        // This is handled implicitly in the provider as it depends on currentUser
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => widget.themeNotifier),
        ChangeNotifierProvider(create: (_) => themeprovider.ThemeProvider()),
      ],
      child: FutureBuilder<void>(
        future: _fetchUserThemeColor(widget.themeNotifier),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MaterialApp(
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
                    title: 'NHS Hour Tracking',
                    debugShowCheckedModeBanner: false,
                    theme: themeProvider
                        .getThemeData(widget.themeNotifier.themeColor),
                    initialRoute: '/',
                    routes: {
                      '/': (context) => const LoginPage(),
                      '/society_selection': (context) =>
                          const SocietySelectionPage(),
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Retrieves the user's saved theme color from SharedPreferences.
  /// If no color is saved, defaults to blue.
  ///
  /// Parameters:
  /// - themeNotifier: ThemeNotifier instance to update the theme color
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _fetchUserThemeColor(ThemeNotifier themeNotifier) async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('themeColor');
    final color = colorValue != null ? Color(colorValue) : Colors.blue;
    themeNotifier.updateThemeColor(color);
  }
}

final supabase = Supabase.instance.client;
