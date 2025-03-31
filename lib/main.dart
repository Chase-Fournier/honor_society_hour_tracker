import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:bottom_navy_bar/bottom_navy_bar.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as add2cal;
import 'package:toastification/toastification.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:barcode/barcode.dart' as barcodeGen;
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/src/painting/text_span.dart' as textspan;
import 'package:flutter/src/painting/box_border.dart' as border;
import 'snake.dart';
import 'societyadminpage.dart';
import 'societyprovider.dart';
import 'societyadmindashboard.dart';
import 'accountsettingspage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hcuygigxjucxutavjvsc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhjdXlnaWd4anVjeHV0YXZqdnNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTI4NzU1NjgsImV4cCI6MjAyODQ1MTU2OH0.0x6jIeOANj6_Y5s7EQ9tuU3GhZLZblobDAt_W2dOLJA',
  );

  final themeNotifier = ThemeNotifier();
  final themeProvider = ThemeProvider();
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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
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
          return Consumer<ThemeProvider>(
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SocietyProvider>(
      builder: (context, societyProvider, _) {
        if (societyProvider.isLoading ||
            societyProvider.currentSociety == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final isAdmin = societyProvider.isAdmin;
        final society = societyProvider.currentSociety!;
        final bool isWideScreen = MediaQuery.of(context).size.width >= 600;

        final List<Widget> pages = [
          if (isAdmin) ...[
            const SocietyAdminDashboard(),
            const AdminEventsPage(),
            const AdminAttendancePage(),
            const AdminListPage(),
            const SettingsPage(),
          ] else ...[
            const HomePage(),
            const CompletedHoursPage(),
            const SettingsPage(),
          ],
        ];

        final List<BottomNavyBarItem> navItems = [
          if (isAdmin) ...[
            BottomNavyBarItem(
              title: const Text('Dashboard'),
              icon: const Icon(Icons.dashboard),
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.onSurface,
            ),
            BottomNavyBarItem(
              title: const Text('Events'),
              icon: const Icon(Icons.event),
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.onSurface,
            ),
            BottomNavyBarItem(
              title: const Text('Attendance'),
              icon: const Icon(Icons.check_circle),
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.onSurface,
            ),
            BottomNavyBarItem(
              title: const Text('Members'),
              icon: const Icon(Icons.people),
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.onSurface,
            ),
            BottomNavyBarItem(
              title: const Text('Settings'),
              icon: const Icon(Icons.settings),
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.onSurface,
            ),
          ] else ...[
            BottomNavyBarItem(
              title: const Text('Home'),
              icon: const Icon(Icons.home),
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.onSurface,
            ),
            BottomNavyBarItem(
              title: const Text('Details'),
              icon: const Icon(Icons.watch_later),
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.onSurface,
            ),
            BottomNavyBarItem(
              title: const Text('Profile'),
              icon: const Icon(Icons.account_circle),
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ];

        return Scaffold(
          body: Row(
            children: [
              if (isWideScreen)
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                    _pageController.jumpToPage(index);
                  },
                  labelType: NavigationRailLabelType.selected,
                  destinations: navItems.map((item) {
                    return NavigationRailDestination(
                      icon: item.icon,
                      label: item.title,
                    );
                  }).toList(),
                ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  children: pages,
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWideScreen
              ? null
              : BottomNavyBar(
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerLowest,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  selectedIndex: _currentIndex,
                  onItemSelected: (index) {
                    setState(() => _currentIndex = index);
                    _pageController.jumpToPage(index);
                  },
                  items: navItems,
                ),
        );
      },
    );
  }

  /// Navigates to the Society Admin page
  void _navigateToSocietyAdmin(BuildContext context) {
    final provider = Provider.of<SocietyProvider>(context, listen: false);
    final society = provider.currentSociety;

    if (society != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SocietyAdminPage(),
        ),
      ).then((_) {
        // Refresh society data when returning from admin page
        provider.refreshCurrentSociety();
      });
    }
  }

  void _navigateToSocietySelection(BuildContext context) {
    // Clear any loading state in the provider before navigating
    final provider = Provider.of<SocietyProvider>(context, listen: false);
    if (provider.isLoading) {
      provider.cancelLoading(); // Add this method to SocietyProvider
    }

    // Navigate to society selection
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const SocietySelectionPage(),
      ),
      (route) => false, // Remove all previous routes
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Login',
                style: TextStyle(
                  fontSize: 32.0,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32.0),
              SupaEmailAuth(
                onSignUpComplete: (response) {
                  // Navigate to a waiting page after sign-up
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const WaitingPage()),
                  );
                },
                redirectTo: kIsWeb ? null : 'com.wheelermun.nhs://callback',
                onSignInComplete: (AuthResponse response) {
                  if (response.session != null) {
                    // Navigate to society selection on successful sign-in
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SocietySelectionPage()),
                      (route) => false,
                    );
                  }
                },
              ),
              SupaSocialsAuth(
                socialProviders: const [],
                colored: true,
                onSuccess: (Session response) {
                  // Navigate to the home page on successful social sign-in
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SocietySelectionPage()),
                  );
                },
                onError: (error) {
                  // Handle the error
                  print('Social sign-in error: $error');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WaitingPage extends StatelessWidget {
  const WaitingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.email,
              size: 80.0,
              color: Colors.blue,
            ),
            const SizedBox(height: 24.0),
            const Text(
              'Thank you for signing up!',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            const Text(
              'Please check your email to verify your account.',
              style: TextStyle(fontSize: 18.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: () {
                // Navigate back to the login page
                Navigator.pushReplacementNamed(context, '/');
              },
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final HonorSociety? society;

  const HomePage({super.key, this.society});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentPageIndex = 0;
  List<Collection> _collections = [];
  List<Event> _events = [];
  String _selectedEventType = 'All';
  // Existing state variables...
  late Map<String, double> _completedHoursMap = {};
  late Map<String, double> _potentialHoursMap = {};
  late Map<String, double> _requirementMap = {};
  int _meetingRequirement = 5; // Default value
  List<String> _availableEventTypes = ['All'];
  bool _isLoading = true;
  final DateFormat formatter = DateFormat('jm');

  @override
  void initState() {
    super.initState();
    _fetchData();
    _checkPendingSwapRequests();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Get the current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get society requirements
      _meetingRequirement = society.meetingRequirement;
      _requirementMap = {};
      _availableEventTypes = ['All'];

      for (final req in society.hourRequirements) {
        if (req.isActive) {
          _requirementMap[req.type] = req.hoursNeeded;
          if (!_availableEventTypes.contains(req.type)) {
            _availableEventTypes.add(req.type);
          }
        }
      }

      // Add Meeting type if not already present
      if (!_availableEventTypes.contains('Meeting')) {
        _availableEventTypes.add('Meeting');
      }

      // Run fetches in parallel
      await Future.wait([
        _fetchEvents(),
        _fetchCollections(),
        _fetchCompletedHours(),
      ]);

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEvents() async {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return;

    final eventResponse = await Supabase.instance.client
        .from('Events')
        .select()
        .eq('society_id', society.id)
        .gt('date',
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String())
        .order('date');

    final List<dynamic> eventData = eventResponse;
    final List<Event> events =
        eventData.map((json) => Event.fromJson(json)).toList();

    // Fetch time slots for each event
    for (var event in events) {
      final timeSlotResponse = await Supabase.instance.client
          .from('Time slots')
          .select()
          .eq('event_id', event.id);

      final List<dynamic> timeSlotData = timeSlotResponse;
      final List<TimeSlot> timeSlots =
          timeSlotData.map((json) => TimeSlot.fromJson(json)).toList();

      for (var timeSlot in timeSlots) {
        final attendeeResponse = await Supabase.instance.client
            .from('Attendees')
            .select('*, profiles!inner(name)')
            .eq('timeslot_id', timeSlot.id ?? 0);

        final List<Attendee> attendees = attendeeResponse
            .map((json) => Attendee.fromJson({
                  ...json,
                  'name': json['profiles']['name'],
                }))
            .toList();

        timeSlot.attendees = attendees;
      }

      event.timeSlots = timeSlots;
    }

    if (mounted) {
      setState(() {
        _events = events;
        // Sort events from closest to furthest date
        _events.sort((a, b) => a.date.compareTo(b.date));
      });
    }
  }

  Future<void> _fetchCompletedHours() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;

    if (userId != null && society != null) {
      // Get user's service hours for this society in a single query
      final response = await Supabase.instance.client
          .from('Service hours')
          .select('hours, type, event_name, date')
          .eq('user_id', userId)
          .eq('society_id', society.id);

      if (_events != null) {
        final data = response;
        Map<String, double> completedHoursMap = {};
        Map<String, double> potentialHoursMap = {};
        Map<String, List<CompletedHour>> hoursByTypeMap = {};

        // Initialize maps with all requirement types
        for (final reqType in _requirementMap.keys) {
          completedHoursMap[reqType] = 0;
          potentialHoursMap[reqType] = 0;
          hoursByTypeMap[reqType] = [];
        }

        // Always include Meeting type
        if (!completedHoursMap.containsKey('Meeting')) {
          completedHoursMap['Meeting'] = 0;
          potentialHoursMap['Meeting'] = 0;
          hoursByTypeMap['Meeting'] = [];
        }

        // Process completed hours
        for (final entry in data) {
          final hours = entry['hours'] + 0.0 ?? 0.0;
          final eventType = entry['type'] as String;
          final eventName = entry['event_name'] as String? ?? 'Unknown Event';
          final dateString = entry['date'] as String?;
          final DateTime date =
              dateString != null ? DateTime.parse(dateString) : DateTime.now();

          // Use normalized type for consistent matching
          final normalizedType = normalizeType(eventType);

          if (completedHoursMap.containsKey(normalizedType)) {
            completedHoursMap[normalizedType] =
                completedHoursMap[normalizedType]! + hours;
            potentialHoursMap[normalizedType] =
                potentialHoursMap[normalizedType]! + hours;

            // Also store the individual hour entries
            hoursByTypeMap[normalizedType]!.add(CompletedHour(
              title: eventName,
              date: date,
              hours: hours,
            ));
          }
        }

        // Process potential hours from upcoming events
        for (final event in _events) {
          for (final timeSlot in event.timeSlots) {
            final isSignedUp =
                timeSlot.attendees.any((attendee) => attendee.userId == userId);
            final isNotPresent = timeSlot.attendees.any(
                (attendee) => attendee.userId == userId && !attendee.isPresent);

            if (isSignedUp && isNotPresent) {
              final duration =
                  NhsFormatUtils.calculateDuration(timeSlot.time, timeSlot.endTime);

              // Use normalized type for consistent matching
              final normalizedType = normalizeType(event.type);

              if (potentialHoursMap.containsKey(normalizedType)) {
                potentialHoursMap[normalizedType] =
                    potentialHoursMap[normalizedType]! + duration;
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            // Store the full maps for dynamic rendering
            _completedHoursMap = completedHoursMap;
            _potentialHoursMap = potentialHoursMap;
          });
        }
      }
    }
  }

  // Build event type filter chips based on society requirements
  List<Widget> _buildEventTypeChips() {
    return _availableEventTypes.map((type) {
      return FilterChip(
        label: Text(type),
        selected: _selectedEventType == type,
        onSelected: (selected) {
          setState(() {
            _selectedEventType = type;
          });
        },
      );
    }).toList();
  }

  // Filter events based on selected type
  List<Event> _getFilteredEvents() {
    if (_selectedEventType == 'All') {
      return _events;
    } else {
      return _events
          .where((event) =>
              normalizeType(event.type) == normalizeType(_selectedEventType))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        title: Text(
          'Home',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Progress bars for each requirement type
                    ..._buildProgressBars(),

                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      children: _buildEventTypeChips(),
                    ),
                    const SizedBox(height: 20),

                    // Event listings
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _getFilteredEvents().length,
                      itemBuilder: (context, index) {
                        return _buildEventCard(_getFilteredEvents()[index]);
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Retrieves all collections from the database.
  /// Updates the state with fetched collections.
  ///
  /// Returns:
  /// - Future<void>
  ///
  /// Throws:
  /// - DatabaseException if collection fetch fails
  Future<void> _fetchCollections() async {
    final response =
        await Supabase.instance.client.from('Collections').select('*');

    final List<dynamic> data = response;
    if (mounted) {
      setState(() {
        _collections = data.map((json) => Collection.fromJson(json)).toList();
      });
    }
  }

  // Updated method to create better looking progress bars with Material You styling
  List<Widget> _buildProgressBars() {
    List<Widget> progressBars = [];

    // First add all the hour requirements in more compact cards
    _requirementMap.forEach((type, hoursNeeded) {
      final completedHours = _completedHoursMap[type] ?? 0.0;
      final potentialHours = _potentialHoursMap[type] ?? 0.0;

      progressBars.add(_buildDoubleProgressBar(
          context, type, completedHours, potentialHours, hoursNeeded.floor()));
    });

    // Then add the special meeting requirement
    final meetingHours = _completedHoursMap['Meeting'] ?? 0.0;
    progressBars.add(
        _buildMeetingProgressBar(context, meetingHours, _meetingRequirement));

    return progressBars;
  }

  /// Creates a double progress bar showing completed and potential hours.
  Widget _buildDoubleProgressBar(BuildContext context, String title,
      double completedHours, double potentialHours, int hoursNeeded) {
    // Calculate percentage for display
    final percentage =
        ((completedHours / hoursNeeded) * 100).clamp(0, 100).toInt();
    final isComplete = completedHours >= hoursNeeded;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title with icon
                Row(
                  children: [
                    Icon(
                      getIconForType(title, context),
                      size: 18,
                      color: isComplete
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$title',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                // Hours text more compact
                Text(
                  '${completedHours.toStringAsFixed(1)} / $hoursNeeded',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isComplete
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Progress bars with animation
            Stack(
              children: [
                // Background track
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),

                // Potential hours progress
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeInOut,
                  tween: Tween<double>(
                    begin: 0,
                    end: (potentialHours / hoursNeeded).clamp(0.0, 1.0),
                  ),
                  builder: (context, potentialValue, _) {
                    return FractionallySizedBox(
                      widthFactor: potentialValue,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    );
                  },
                ),

                // Completed hours progress
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutQuart,
                  tween: Tween<double>(
                    begin: 0,
                    end: (completedHours / hoursNeeded).clamp(0.0, 1.0),
                  ),
                  builder: (context, completedValue, _) {
                    return FractionallySizedBox(
                      widthFactor: completedValue,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: isComplete
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.8),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Only show this info if there's additional potential hours
            if (potentialHours > completedHours)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.upcoming,
                      size: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Potential: ${potentialHours.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.7),
                      ),
                    ),
                    if (isComplete)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Complete',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Creates a progress bar specifically for meeting attendance with Material You styling
  Widget _buildMeetingProgressBar(
      BuildContext context, double completedHours, int hoursNeeded) {
    final meetingsAttended = completedHours.floor();
    final meetingsLeft =
        _events.where((event) => event.type == 'Meeting').length;
    final isComplete = meetingsAttended >= hoursNeeded;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title with icon
                Row(
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 18,
                      color: isComplete
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Meetings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                // Meetings text
                Text(
                  '$meetingsAttended / $hoursNeeded',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isComplete
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Progress bar with animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutQuart,
              tween: Tween<double>(
                begin: 0,
                end: (meetingsAttended / hoursNeeded).clamp(0.0, 1.0),
              ),
              builder: (context, value, _) {
                return Stack(
                  children: [
                    // Background track
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),

                    // Progress
                    FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: isComplete
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context)
                                  .colorScheme
                                  .tertiary
                                  .withOpacity(0.8),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            if (meetingsLeft > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Upcoming: $meetingsLeft',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.7),
                      ),
                    ),
                    if (isComplete)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 12,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Complete',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.tertiary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Returns unique collections from a list of events.
  ///
  /// Parameters:
  /// - events: List<Event> - Events to process
  ///
  /// Returns:
  /// - List<Collection>
  List<Collection> _getUniqueCollections(List<Event> events) {
    final collectionIds =
        events.map((event) => event.collectionId).whereType<int>().toSet();
    return collectionIds
        .map((id) =>
            _collections.firstWhere((collection) => collection.id == id))
        .toList();
  }

  /// Finds the earliest event date in a collection.
  ///
  /// Parameters:
  /// - collection: Collection - Collection to check
  ///
  /// Returns:
  /// - DateTime
  DateTime _getClosestEventDate(Collection collection) {
    final collectionEvents =
        _events.where((event) => event.collectionId == collection.id).toList();
    return collectionEvents
        .map((event) => event.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  Widget _buildEventCard(Event event) {
    final bool isNew = event.createdAt
        .isAfter(DateTime.now().subtract(const Duration(days: 3)));
    final bool isMandatory = event.isMandatory;
    final currentUserId = supabase.auth.currentUser?.id;

    // Check if forms are required and completed
    final bool formsCompleted = event.timeSlots.any((timeSlot) =>
        timeSlot.attendees.any((attendee) =>
            attendee.userId == currentUserId && attendee.formsCompleted));

    final bool showRequiredForms = event.requiresForms &&
        !formsCompleted &&
        event.timeSlots.any((timeSlot) => timeSlot.attendees
            .any((attendee) => attendee.userId == currentUserId));

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 1,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Event type indicator line
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(
              color: _getColorForEventType(event.type, context),
            ),
          ),

          // Main content with padding to account for the type indicator
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: CustomExpansionTile(
              title: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event icon
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          _getColorForEventType(event.type, context)
                              .withOpacity(0.15),
                      child: Icon(
                        getIconForType(event.type, context),
                        color: _getColorForEventType(event.type, context),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Event details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and badges row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Use more compact badges
                              if (showRequiredForms)
                                _buildBadge('Forms', Icons.assignment_late,
                                    Theme.of(context).colorScheme.error)
                              else if (isMandatory)
                                _buildBadge('Required', Icons.priority_high,
                                    Theme.of(context).colorScheme.tertiary)
                              else if (isNew)
                                _buildBadge('New', Icons.fiber_new,
                                    Theme.of(context).colorScheme.secondary),
                            ],
                          ),

                          // Date and description
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.event_note,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${event.date.month}/${event.date.day}/${event.date.year}",
                                style: TextStyle(
                                  fontSize: 13.0,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      _getColorForEventType(event.type, context)
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  event.type,
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w500,
                                    color: _getColorForEventType(
                                        event.type, context),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),
                          Text(
                            event.description,
                            style: TextStyle(
                              fontSize: 13.0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              children: _buildTimeSlotItems(event, currentUserId),
            ),
          ),
        ],
      ),
    );
  }

// Add this method to build time slot items
  List<Widget> _buildTimeSlotItems(Event event, String? currentUserId) {
    final bool isMandatory = event.isMandatory;

    return event.timeSlots.map((timeSlot) {
      // Get timeslot-specific status
      final isSignedUp = timeSlot.attendees
          .any((attendee) => attendee.userId == currentUserId);

      // Get society requirements and check if user has completed them
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      bool hasCompletedRequirements = false;

      if (society != null) {
        // For Meeting type, use the society's meeting requirement
        if (event.type == 'Meeting') {
          final meetingsCompleted = _completedHoursMap['Meeting'] ?? 0.0;
          hasCompletedRequirements =
              meetingsCompleted >= society.meetingRequirement;
        } else {
          // For other types, find the matching requirement in the society
          final matchingRequirement = society.hourRequirements.firstWhere(
            (req) => normalizeType(req.type) == normalizeType(event.type),
            orElse: () => HourRequirement(
              id: -1,
              type: event.type,
              hoursNeeded: 0,
              description: '',
              isActive: false,
            ),
          );

          // Check if user has completed the required hours for this type
          final completedHours =
              _completedHoursMap[normalizeType(event.type)] ?? 0.0;
          hasCompletedRequirements =
              completedHours >= matchingRequirement.hoursNeeded;
        }
      }

      // Check if signup is delayed
      final canSignUp = !hasCompletedRequirements ||
          !event.hasDelay ||
          event.canSignUpForTimeSlot(timeSlot);

      // Check if we can show the cancel button
      final isTimeSlotInFuture = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        timeSlot.time.hour,
        timeSlot.time.minute,
      ).isAfter(DateTime.now());

      // Check if we can show the swap button
      final canRequestSwap = isSignedUp &&
          DateTime.now()
              .isAfter(event.date.subtract(event.swapRequestDeadline)) &&
          DateTime.now().isBefore(DateTime(
            event.date.year,
            event.date.month,
            event.date.day,
            timeSlot.time.hour,
            timeSlot.time.minute,
          ));

      // Get forms status for this timeslot
      final timeSlotFormsCompleted = isSignedUp
          ? timeSlot.attendees
              .firstWhere((attendee) => attendee.userId == currentUserId)
              .formsCompleted
          : false;

      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time info row
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    event.type == 'Meeting'
                        ? timeSlot.time.format(context)
                        : '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const Spacer(),

                  // Capacity info
                  if (!(event.type == 'Meeting'))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people,
                            size: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${timeSlot.numberOfPeople} spots',
                            style: TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Notes if available
              if (timeSlot.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  timeSlot.notes,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              // Action buttons
              const SizedBox(height: 10),
              isSignedUp
                  ? Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: Icon(Icons.calendar_today, size: 14),
                          label:
                              Text('Calendar', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _addEventToCalendar(event, timeSlot),
                        ),
                        if (canRequestSwap &&
                            event.type != 'Meeting' &&
                            !isMandatory)
                          OutlinedButton.icon(
                            icon: Icon(Icons.swap_horiz, size: 14),
                            label: Text('Swap', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () =>
                                _showSwapRequestDialog(event, timeSlot),
                          ),
                        if (isTimeSlotInFuture &&
                            !isMandatory &&
                            event.type != 'Meeting' &&
                            !canRequestSwap)
                          OutlinedButton.icon(
                            icon: Icon(Icons.cancel, size: 14),
                            label:
                                Text('Cancel', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size(0, 28),
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _removeAttendee(event, timeSlot),
                          ),
                        if (event.requiresForms)
                          OutlinedButton.icon(
                            icon: Icon(
                              timeSlotFormsCompleted
                                  ? Icons.inventory
                                  : Icons.pending_actions,
                              size: 14,
                            ),
                            label: Text(
                                timeSlotFormsCompleted ? 'Forms' : 'Need Forms',
                                style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size(0, 28),
                              foregroundColor: timeSlotFormsCompleted
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _showUploadFormsDialog(
                                event, timeSlot, timeSlotFormsCompleted),
                          ),
                      ],
                    )
                  : isMandatory || event.type == 'Meeting'
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'Automatically Enrolled',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                        )
                      : !canSignUp
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.timer,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onTertiaryContainer,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Available ${event.delayHours}h before event',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onTertiaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _showSignUpForm(event, timeSlot),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Sign Up'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                minimumSize: const Size(double.infinity, 36),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
            ],
          ),
        ),
      );
    }).toList();
  }

// Helper method to build compact badges
  Widget _buildBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: border.Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

// Add this method to build time slot items

// Helper for action buttons
  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14, color: color),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  /// Displays dialog for initiating a swap request.
  /// Allows user to select another member to swap with.
  ///
  /// Parameters:
  /// - event: Event - Event to swap
  /// - timeSlot: TimeSlot - Time slot to swap
  ///
  /// Returns:
  /// - void
  void _showSwapRequestDialog(Event event, TimeSlot timeSlot) {
    String searchQuery = '';
    List<UserProfile> allUsers = [];
    List<UserProfile> filteredUsers = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Request Swap'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        filteredUsers = allUsers
                            .where((user) => user.name
                                .toLowerCase()
                                .contains(searchQuery.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search Members',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<UserProfile>>(
                    future: _fetchAllUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          allUsers.isEmpty) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else {
                        if (snapshot.hasData && allUsers.isEmpty) {
                          allUsers = snapshot.data!;
                          filteredUsers = allUsers;
                        }
                        return SizedBox(
                          height: 300,
                          width: 300,
                          child: ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return ListTile(
                                title: Text(user.name),
                                onTap: () {
                                  _showSwapConfirmationDialog(
                                      event, timeSlot, user);
                                },
                              );
                            },
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSwapConfirmationDialog(
      Event event, TimeSlot timeSlot, UserProfile targetUser) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Swap Request'),
          content: Text(
              'Are you sure you want to request a swap with ${targetUser.name} for the event "${event.name}"?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Confirm'),
              onPressed: () async {
                // Check if the user has already requested a swap for this time slot
                final hasPendingSwap =
                    await _checkPendingSwap(event.id, timeSlot.id ?? 0);

                if (hasPendingSwap) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'You already have a pending swap request for this time slot.')),
                  );
                } else {
                  _sendSwapRequest(event, timeSlot, targetUser);
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Close both dialogs
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Checks if user has pending swap requests for an event.
  ///
  /// Parameters:
  /// - eventId: int - Event to check
  /// - timeSlotId: int - Time slot to check
  ///
  /// Returns:
  /// - Future<bool>
  Future<bool> _checkPendingSwap(int eventId, int timeSlotId) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final pendingSwaps = await Supabase.instance.client
        .from('swap_requests')
        .select()
        .eq('event_id', eventId)
        .eq('timeslot_id', timeSlotId)
        .eq('requester_id', currentUserId)
        .eq('status', 'pending');

    return pendingSwaps.isNotEmpty;
  }

  /// Creates a new swap request in the database.
  ///
  /// Parameters:
  /// - event: Event - Event to swap
  /// - timeSlot: TimeSlot - Time slot to swap
  /// - targetUser: UserProfile - User to request swap with
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _sendSwapRequest(
      Event event, TimeSlot timeSlot, UserProfile targetUser) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await Supabase.instance.client.from('swap_requests').insert({
        'event_id': event.id,
        'timeslot_id': timeSlot.id,
        'requester_id': currentUserId,
        'target_id': targetUser.id,
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Swap request sent to ${targetUser.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending swap request: $e')),
      );
    }
  }

  /// Retrieves all user profiles with their completed hours.
  /// Used in admin interface for user management.
  ///
  /// Returns:
  /// - Future<void>
  Future<List<UserProfile>> _fetchAllUsers() async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('user_id, name')
        .order('name');

    return (response as List)
        .map((user) => UserProfile(
              id: user['user_id'],
              name: user['name'],
              completedHours: [], // You might want to fetch this information separately if needed
            ))
        .toList();
  }

  /// Displays dialog for managing form submissions.
  /// Handles form completion status and updates.
  ///
  /// Parameters:
  /// - event: Event - Associated event
  /// - timeSlot: TimeSlot - Associated time slot
  /// - formsCompleted: bool - Current completion status
  ///
  /// Returns:
  /// - void
  void _showUploadFormsDialog(
      Event event, TimeSlot timeSlot, bool hasFilledForms) {
    final currentUserId = supabase.auth.currentUser?.id;
    final attendee = event.timeSlots
        .expand((timeSlot) => timeSlot.attendees)
        .firstWhere((attendee) => attendee.userId == currentUserId,
            orElse: () => Attendee(id: 0, timeSlotId: 0, userId: '', name: ''));

    final bool formsCompleted = attendee.formsCompleted;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(formsCompleted ? 'Forms Completed' : 'Required Forms'),
          content: Text(formsCompleted
              ? 'You have already completed the forms for this event.'
              : 'This event requires forms to be completed.'),
          actions: [
            Row(
              children: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                SizedBox(
                  width: 4,
                ),
                if (!formsCompleted) ...[
                  ElevatedButton(
                    child: const Text('Fill Out'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _launchFormLink(event.formLink!);
                    },
                  ),
                  SizedBox(
                    width: 4,
                  ),
                  ElevatedButton(
                    child: const Text('Complete'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _markFormsAsCompleted(event, timeSlot, true);
                    },
                  ),
                ] else
                  ElevatedButton(
                    child: const Text('Remove Completion'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _markFormsAsCompleted(event, timeSlot, false);
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Opens external form URL in device browser.
  /// Use
  ///
  /// Parameters:
  /// - urls: String - URL to open
  ///
  /// Returns:
  /// - Future<void>
  ///
  /// Throws:
  /// - PlatformException if URL launch fails
  void _launchFormLink(String urls) async {
    final Uri url = Uri.parse(urls);
    await launchUrl(url);
  }

  /// Updates the form completion status for an attendee.
  ///
  /// Parameters:
  /// - event: Event - Associated event
  /// - timeSlot: TimeSlot - Associated time slot
  /// - completed: bool - New completion status
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _markFormsAsCompleted(
      Event event, TimeSlot timeSlot, bool completed) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('Attendees')
            .update({'forms_completed': completed})
            .eq('user_id', userId)
            .eq('timeslot_id', timeSlot.id ?? 0);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(completed
                  ? 'Forms marked as completed'
                  : 'Form completion status removed')),
        );

        // Refresh the events to update the UI
        _fetchEvents();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating form status: $e')),
      );
    }
  }

  Widget _buildCollectionEventCard(Event event) {
    final bool isNew = event.createdAt
        .isAfter(DateTime.now().subtract(const Duration(days: 7)));
    final bool isMandatory = event.isMandatory;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          if (isMandatory)
            Positioned(
              left: 255,
              top: 32,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star,
                  color: Theme.of(context).colorScheme.onError,
                  size: 16,
                ),
              ),
            )
          else if (isNew)
            Positioned(
              left: 250,
              top: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'New',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          CustomExpansionTile(
            title: ListTile(
              title: Text(
                "${event.name} - ${event.date.month}/${event.date.day}/${event.date.year}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
              subtitle: Text(
                event.description,
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.grey[600],
                ),
              ),
            ),
            children: event.timeSlots.map((timeSlot) {
              final isSignedUp = timeSlot.attendees.any(
                  (attendee) => attendee.name == supabase.auth.currentUser?.id);
              final isEventInFuture = event.date
                  .isAfter(DateTime.now().add(const Duration(days: 1)));
              final isMandatory = event.isMandatory;
              final isMeeting = event.type == 'Meeting';

              return ListTile(
                title: Text(
                  event.type == 'Meeting'
                      ? 'Time: ${timeSlot.time.format(context)}'
                      : 'Time: ${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
                  style: const TextStyle(
                    fontSize: 14.0,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Number of People: ${timeSlot.numberOfPeople}',
                      style: TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (timeSlot.notes.isNotEmpty)
                      Text(
                        'Notes: ${timeSlot.notes}',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                trailing: isSignedUp
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () {
                              _addEventToCalendar(event, timeSlot);
                            },
                          ),
                          if (isEventInFuture && !isMandatory && !isMeeting)
                            IconButton(
                              icon: const Icon(Icons.cancel),
                              onPressed: () {
                                _removeAttendee(event, timeSlot);
                              },
                            ),
                        ],
                      )
                    : isMandatory || isMeeting
                        ? const Text('Automatically Signed Up')
                        : ElevatedButton(
                            onPressed: () {
                              _showSignUpForm(event, timeSlot);
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text('  Sign Up  '),
                          ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Creates a widget displaying collection information and associated events.
  ///
  /// Parameters:
  /// - collection: Collection - Collection to display
  /// - index: int - Index in the collection list
  ///
  /// Returns:
  /// - Widget
  Widget _buildCollectionCard(Collection collection) {
    final collectionEvents =
        _events.where((event) => event.collectionId == collection.id).toList();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CustomExpansionTile(
        title: ListTile(
          leading: const Icon(Icons.folder),
          title: Text(
            collection.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.0,
            ),
          ),
        ),
        children:
            collectionEvents.map((event) => _buildEventCard(event)).toList(),
      ),
    );
  }

  void _showSignUpForm(Event event, TimeSlot timeSlot) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign Up'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Event: ${event.name}'),
              const SizedBox(height: 8),
              Text('Time: ${timeSlot.time.format(context)}'),
              const SizedBox(height: 8),
              Text('Number of People: ${timeSlot.numberOfPeople}'),
            ],
          ),
          actions: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 3),
                  ElevatedButton(
                    child: const Text('Sign Up'),
                    onPressed: () {
                      _signUpForTimeSlot(event, timeSlot);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: const Text('Add to Calendar'),
                onPressed: () {
                  _signUpForTimeSlot(event, timeSlot);
                  _addEventToCalendar(event, timeSlot);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Removes a user's attendance registration from a time slot.
  /// Updates available capacity and logs the change.
  ///
  /// Parameters:
  /// - event: Event - Event containing the time slot
  /// - timeSlot: TimeSlot - Time slot to remove from
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _removeAttendee(Event event, TimeSlot timeSlot) async {
    final userId = supabase.auth.currentUser?.id;

    if (userId != null) {
      await Supabase.instance.client
          .from('Attendees')
          .delete()
          .eq('timeslot_id', timeSlot?.id ?? 0)
          .eq('user_id', userId);

      await Supabase.instance.client
          .from('Time slots')
          .update({'number_of_people': timeSlot.numberOfPeople + 1}).eq(
              'id', timeSlot?.id ?? 0);

      await _logActivity(
        event.name,
        '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
        NhsFormatUtils.calculateDuration(timeSlot.time, timeSlot.endTime),
        'unsignup',
        userId,
      );

      _fetchEvents();
    }
  }

  /// Registers a user for a specific time slot in an event.
  /// Checks capacity and existing registration.
  ///
  /// Parameters:
  /// - event: Event - Target event
  /// - timeSlot: TimeSlot - Selected time slot
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _signUpForTimeSlot(Event event, TimeSlot timeSlot) async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;

    if (userId != null) {
      // Check if the user has completed requirements using existing state
      // Replace the hardcoded requirement check with this dynamic version:

      // Get society's requirements
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      bool hasCompletedRequirements = false;

      if (society != null) {
        // For Meeting type, use the society's meeting requirement
        if (event.type == 'Meeting') {
          final meetingsCompleted = _completedHoursMap['Meeting'] ?? 0.0;
          hasCompletedRequirements =
              meetingsCompleted >= society.meetingRequirement;
        } else {
          // For other types, find the matching requirement in the society
          final matchingRequirement = society.hourRequirements.firstWhere(
            (req) => normalizeType(req.type) == normalizeType(event.type),
            orElse: () => HourRequirement(
              id: -1,
              type: event.type,
              hoursNeeded: 0,
              description: '',
              isActive: false,
            ),
          );

          // Check if user has completed the required hours for this type
          final completedHours =
              _completedHoursMap[normalizeType(event.type)] ?? 0.0;
          hasCompletedRequirements =
              completedHours >= matchingRequirement.hoursNeeded;
        }
      }

// Check if signup is delayed
      final canSignUp = !hasCompletedRequirements ||
          !event.hasDelay ||
          event.canSignUpForTimeSlot(timeSlot);
      if (!canSignUp) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Signup will be available ${event.delayHours} hours before the event',
            ),
          ),
        );
        return;
      }
      // Check if the user is already signed up
      final existingAttendee = await Supabase.instance.client
          .from('Attendees')
          .select()
          .eq('timeslot_id', timeSlot.id ?? 0)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingAttendee == null) {
        // Add the user to the Attendees table
        await Supabase.instance.client.from('Attendees').insert({
          'timeslot_id': timeSlot?.id ?? 0,
          'user_id': userId,
          'is_present': false,
        });

        // Update the number of people in the time slot
        await Supabase.instance.client
            .from('Time slots')
            .update({'number_of_people': timeSlot.numberOfPeople - 1}).eq(
                'id', timeSlot?.id ?? 0);

        await _logActivity(
          event.name,
          '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
          NhsFormatUtils.calculateDuration(timeSlot.time, timeSlot.endTime),
          'signup',
          userId,
        );

        _fetchEvents();
      }
    }
  }

  /// Adds an event to the device calendar.
  ///
  /// Parameters:
  /// - event: Event - Event to add
  /// - timeSlot: TimeSlot - Specific time slot
  ///
  /// Returns:
  /// - void
  void _addEventToCalendar(Event event, TimeSlot timeSlot) {
    final calendarEventp = add2cal.Event(
      title: event.name,
      description: event.description,
      startDate: DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        timeSlot.time.hour,
        timeSlot.time.minute,
      ),
      endDate: DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        timeSlot.endTime.hour,
        timeSlot.endTime.minute,
      ),
      iosParams: const add2cal.IOSParams(
        reminder: Duration(minutes: 10),
      ),
      androidParams: const add2cal.AndroidParams(
        emailInvites: [],
      ),
    );

    add2cal.Add2Calendar.addEvent2Cal(calendarEventp);
  }

  /// Opens external URL in device browser.
  /// Used for opening error correction form.
  ///
  /// Returns:
  /// - Future<void>
  void _openWebsite() async {
    final Uri url = Uri.parse(
        'https://docs.google.com/forms/d/1ZcXKKctcGjxJYi5KXuqmZ8u1BQP-825KSFJmP-rcKtA/viewform?edit_requested=true');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch url');
    }
  }

  Future<void> _checkPendingSwapRequests() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final swapRequests = await Supabase.instance.client
        .from('swap_requests')
        .select(
            '*, Events!swap_requests_event_id_fkey(*), profiles!swap_requests_requester_id_fkey(*), "Time slots"!swap_requests_timeslot_id_fkey(start_time, end_time)')
        .eq('status', 'pending')
        .eq("target_id", currentUserId);

    await handleSwapRequests(swapRequests);
  }

  /// Processes incoming swap requests.
  /// Shows notifications and handles user responses.
  ///
  /// Parameters:
  /// - swapRequests: List<Map<String, dynamic>> - Pending swap requests
  ///
  /// Returns:
  /// - Future<void>
  Future<void> handleSwapRequests(
      List<Map<String, dynamic>> swapRequests) async {
    for (final request in swapRequests) {
      try {
        final swapRequest = SwapRequest.fromJson(request);

        Map<String, dynamic>? eventData;
        if (request['Events'] == null) {
          final eventResponse = await Supabase.instance.client
              .from('Events')
              .select()
              .eq('id', swapRequest.eventId)
              .single();
          eventData = eventResponse as Map<String, dynamic>?;
        } else {
          eventData = request['Events'] as Map<String, dynamic>?;
        }

        final profileData = request['profiles'] as Map<String, dynamic>?;

        if (eventData != null && profileData != null) {
          await _showSwapRequestNotification(
              swapRequest, eventData, profileData, _events);
        } else {
          print('Invalid swap request data: $request');
        }
      } catch (e) {
        print('Error processing swap request: $e');
      }
    }
  }

  Future<void> _showSwapRequestNotification(
    SwapRequest swapRequest,
    Map<String, dynamic> eventData,
    Map<String, dynamic> profileData,
    List<Event> listofevents,
  ) async {
    final isAlreadySignedUp = await _isAlreadySignedUp(swapRequest);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Swap Request'),
          content: Text(
              '${profileData['name']} wants to swap for ${eventData['name']} (Time Slot: ${formatter.format(swapRequest.startTime)} - ${formatter.format(swapRequest.endTime)})'),
          actions: [
            TextButton(
              child: const Text('Decline'),
              onPressed: () {
                // Handle decline action
                _declineSwapRequest(swapRequest);
                Navigator.of(context).pop();
              },
            ),
            Visibility(
              visible: !isAlreadySignedUp,
              child: ElevatedButton(
                child: const Text('Accept'),
                onPressed: () {
                  // Handle accept action
                  _acceptSwapRequest(swapRequest, eventData);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _isAlreadySignedUp(SwapRequest swapRequest) async {
    final response = await Supabase.instance.client
        .from('Time slots')
        .select('*, Attendees(*)')
        .eq('id', swapRequest.timeSlotId)
        .eq('event_id', swapRequest.eventId)
        .single();

    final attendees = response['Attendees'] as List<dynamic>;
    return attendees.any(
        (attendee) => attendee['user_id'] == swapRequest.currentAttendeeId);
  }

  void _declineSwapRequest(SwapRequest swapRequest) async {
    try {
      await Supabase.instance.client
          .from('swap_requests')
          .update({'status': 'declined'}).eq('id', swapRequest.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Swap request declined')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining swap request: $e')),
      );
    }
  }

  void _acceptSwapRequest(
      SwapRequest swapRequest, Map<String, dynamic> eventData) async {
    try {
      await Supabase.instance.client
          .from('swap_requests')
          .update({'status': 'accepted'}).eq('id', swapRequest.id);

      await _swapAttendees(
          swapRequest.currentAttendeeId,
          swapRequest.requesterId,
          swapRequest.eventId,
          swapRequest.timeSlotId,
          eventData,
          swapRequest);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Swap request accepted')),
      );

      // Refresh the UI
      await _fetchEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting swap request: $e')),
      );
    }
  }

  /// Executes attendance swap between two users.
  /// Updates database and notifications.
  ///
  /// Parameters:
  /// - currentAttendee: Attendee - Current event attendee
  /// - newUser: UserProfile - User to swap with
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _swapAttendees(
      String newAttendeeId,
      String currentAttendeeId,
      int eventId,
      int timeSlotId,
      Map<String, dynamic> eventData,
      SwapRequest swapRequest) async {
    try {
      // Remove the current attendee
      await Supabase.instance.client
          .from('Attendees')
          .delete()
          .eq('user_id', currentAttendeeId)
          .eq('timeslot_id', timeSlotId);

      // Add the new attendee
      await Supabase.instance.client.from('Attendees').insert({
        'user_id': newAttendeeId,
        'timeslot_id': timeSlotId,
        'is_present': false,
        'forms_completed': false,
      });

      await _logActivity(
        eventData['name'],
        '${formatter.format(swapRequest.startTime)} - ${formatter.format(swapRequest.endTime)}',
        NhsFormatUtils.calculateDuration(TimeOfDay.fromDateTime(swapRequest.startTime),
            TimeOfDay.fromDateTime(swapRequest.endTime)),
        'swap',
        currentAttendeeId,
        oldUserId: currentAttendeeId,
        newUserId: newAttendeeId,
      );
    } catch (e) {
      print('Error swapping attendees: $e');
      rethrow;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _respondToSwapRequest(SwapRequest request, bool accepted) async {
    try {
      // Update the swap request status
      await Supabase.instance.client.from('swap_requests').update(
          {'status': accepted ? 'accepted' : 'denied'}).eq('id', request.id);

      if (accepted) {
        // Perform the swap
        await _performSwap(request);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Swap request ${accepted ? 'accepted' : 'denied'}')),
      );

      // Refresh the events list
      _fetchEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing swap request: $e')),
      );
    }
  }

  Future<void> _performSwap(SwapRequest request) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Remove the requester from the event
    await Supabase.instance.client
        .from('Attendees')
        .delete()
        .eq('timeslot_id', request.timeSlotId)
        .eq('user_id', request.requesterId);

    // Add the target (current user) to the event
    await Supabase.instance.client.from('Attendees').insert({
      'timeslot_id': request.timeSlotId,
      'user_id': currentUserId,
      'is_present': false,
    });

    // You may want to handle transferring any additional data (like forms_completed) here
  }
}

Future<void> exportToExcel(
    BuildContext context, List<UserProfile> users) async {
  try {
    // Get current society to properly filter data and get requirements
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot export: No society selected')),
      );
      return;
    }

    // Set up Excel document
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Members'];
    int maxEvents = 0;

    // Get all user IDs for batched queries
    final userIds = users.map((u) => u.id).toList();

    // Get email addresses
    final emailsResponse = await Supabase.instance.client
        .from('profiles')
        .select('user_id, email')
        .inFilter('user_id', userIds);

    final emailMap = {
      for (var item in emailsResponse)
        item['user_id'] as String: item['email'] as String
    };

    // Get service hours for current society only
    final hoursResponse = await Supabase.instance.client
        .from('Service hours')
        .select('user_id, event_name, hours, type, date, timeslot')
        .eq('society_id', society.id) // Filter by current society
        .inFilter('user_id', userIds)
        .order('date');

    // Build a list of society's hour requirement types
    List<String> requirementTypes = ['Meeting']; // Always include Meeting
    for (final req in society.hourRequirements) {
      if (req.isActive && !requirementTypes.contains(req.type)) {
        requirementTypes.add(req.type);
      }
    }

    // Process hours data for each user
    Map<String, dynamic> userServiceData = {};
    for (final entry in hoursResponse) {
      try {
        final userId = entry['user_id']?.toString() ?? '';
        if (userId.isEmpty) continue;

        final hours = (entry['hours'] as num?)?.toDouble() ?? 0.0;
        final type = entry['type']?.toString() ?? 'Unknown Type';
        final normalizedType =
            normalizeType(type); // Normalize for consistent comparison
        final eventName = entry['event_name']?.toString() ?? 'Unnamed Event';

        // Parse date safely
        DateTime date;
        try {
          date = entry['date'] != null
              ? DateTime.parse(entry['date'].toString())
              : DateTime.now();
        } catch (e) {
          date = DateTime.now();
        }

        final timeSlot = entry['timeslot']?.toString() ?? 'No time specified';

        if (userId.isNotEmpty) {
          // Initialize user data structure if not already done
          if (!userServiceData.containsKey(userId)) {
            userServiceData[userId] = {
              'eventsList': <String>[],
              'hoursByType': {
                for (var type in requirementTypes) normalizeType(type): 0.0
              },
              'meetingsAttended': 0,
              'totalHours': 0.0,
            };
          }

          final userData = userServiceData[userId];

          // Update hour totals based on type
          // Use normalized comparison to match requirement types
          bool typeMatched = false;
          for (var reqType in requirementTypes) {
            if (normalizeType(reqType) == normalizedType) {
              if (reqType == 'Meeting') {
                userData['meetingsAttended'] += 1; // Count meetings
              } else {
                userData['hoursByType'][normalizeType(reqType)] += hours;
              }
              typeMatched = true;
              break;
            }
          }

          // If no match found, try to add to a fallback category
          if (!typeMatched) {
            if (userData['hoursByType'].containsKey('Service')) {
              userData['hoursByType']['Service'] += hours;
            } else if (userData['hoursByType'].isNotEmpty) {
              // Add to the first available requirement type as fallback
              final firstType = userData['hoursByType'].keys.first;
              userData['hoursByType'][firstType] += hours;
            }
          }

          // Update total hours
          userData['totalHours'] = (userData['totalHours'] as double) + hours;

          // Format and add event detail to ordered list
          final formattedDate = '${date.month}/${date.day}/${date.year}';
          final eventDetail =
              '$eventName ($formattedDate - $timeSlot): $hours hours ($type)';
          userData['eventsList'].add(eventDetail);

          // Update max events count
          maxEvents = userData['eventsList'].length > maxEvents
              ? userData['eventsList'].length
              : maxEvents;
        }
      } catch (e) {
        print('Error processing entry: $e');
        continue;
      }
    }

    // Prepare dynamic headers based on society's requirements
    final baseHeaders = [
      'Name',
      'Email',
      'Dues Paid',
      'Total Hours',
      'Meetings Attended',
    ];

    // Add headers for each requirement type
    final requirementHeaders = requirementTypes
        .where((type) => type != 'Meeting') // Meeting already covered
        .map((type) => '$type Hours')
        .toList();

    // Event headers
    final eventHeaders = List.generate(maxEvents, (i) => 'Event ${i + 1}');
    final allHeaders = [...baseHeaders, ...requirementHeaders, ...eventHeaders];

    // Write headers to Excel
    for (var i = 0; i < allHeaders.length; i++) {
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(allHeaders[i])
        ..cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
    }

    // Write data for each user
    int rowIndex = 1;
    for (var user in users) {
      final userData = userServiceData[user.id] ??
          {
            'hoursByType': {
              for (var type in requirementTypes) normalizeType(type): 0.0
            },
            'meetingsAttended': 0,
            'totalHours': 0.0,
            'eventsList': <String>[],
          };

      // Column index tracker
      int colIndex = 0;

      // Base data
      sheetObject
          .cell(CellIndex.indexByColumnRow(
              columnIndex: colIndex++, rowIndex: rowIndex))
          .value = TextCellValue(user.name);

      sheetObject
          .cell(CellIndex.indexByColumnRow(
              columnIndex: colIndex++, rowIndex: rowIndex))
          .value = TextCellValue(emailMap[user.id] ?? '');

      sheetObject
          .cell(CellIndex.indexByColumnRow(
              columnIndex: colIndex++, rowIndex: rowIndex))
          .value = TextCellValue(user.hasPaidDues ? 'Yes' : 'No');

      sheetObject
          .cell(CellIndex.indexByColumnRow(
              columnIndex: colIndex++, rowIndex: rowIndex))
          .value = DoubleCellValue(userData['totalHours']);

      sheetObject
          .cell(CellIndex.indexByColumnRow(
              columnIndex: colIndex++, rowIndex: rowIndex))
          .value = IntCellValue(userData['meetingsAttended']);

      // Dynamic requirement type hours
      for (var type in requirementTypes) {
        if (type == 'Meeting') continue; // Skip Meeting (already added)

        final hours = userData['hoursByType'][normalizeType(type)] ?? 0.0;
        sheetObject
            .cell(CellIndex.indexByColumnRow(
                columnIndex: colIndex++, rowIndex: rowIndex))
            .value = DoubleCellValue(hours);
      }

      // Event details in sequential columns
      for (var i = 0; i < (userData['eventsList'] as List).length; i++) {
        sheetObject
            .cell(CellIndex.indexByColumnRow(
                columnIndex: colIndex + i, rowIndex: rowIndex))
            .value = TextCellValue(userData['eventsList'][i]);
      }

      rowIndex++;
    }

    // Auto-fit columns
    for (var i = 0; i < allHeaders.length; i++) {
      sheetObject.setColumnWidth(i, 30);
    }

    // Save the file
    final fileBytes = excel.save(fileName: 'NHS_Members_Report.xlsx');
    if (fileBytes != null) {
      if (kIsWeb) {
        // Web handling is automatic through excel package
      } else {
        if (Platform.isAndroid) {
          final file =
              File('storage/emulated/0/Download/NHS_Members_Report.xlsx');
          await file.writeAsBytes(fileBytes);
        } else if (Platform.isIOS) {
          final Directory dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/NHS_Members_Report.xlsx');
          await file.writeAsBytes(fileBytes);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report saved successfully!')),
        );
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error generating report: $e')),
    );
  }
}

/// Helper class to store processed user data
class UserServiceData {
  double serviceHours = 0;
  double tutoringHours = 0;
  int meetingsAttended = 0;
  List<String> eventsList = []; // Maintains events in order
}

/// Retrieves user's display name from their ID.
///
/// Parameters:
/// - userId: String? - User ID to look up
///
/// Returns:
/// - Future<String>

Future<String> _getUserName(String? userId) async {
  if (userId != null) {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('name')
        .eq('user_id', userId)
        .single();

    return response['name'] ?? 'Unknown User';
  }
  return 'Unknown User';
}

class UserRanking {
  final String userId;
  final String name;
  double totalHours;
  int rank;

  UserRanking({
    required this.userId,
    required this.name,
    this.totalHours = 0,
    required this.rank,
  });
}

class LeaderboardPage extends StatefulWidget {
  final String currentUserId;

  const LeaderboardPage({Key? key, required this.currentUserId})
      : super(key: key);

  @override
  _LeaderboardPageState createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<UserRanking> _rankings = [];
  UserRanking? _currentUserRanking;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboardData();
  }

  Future<void> _fetchLeaderboardData() async {
    try {
      // Fetch profiles first
      final profilesResponse =
          await supabase.from('profiles').select('user_id, name');

      // Create a map of user_id to name for quick lookup
      Map<String, String> userNames = {
        for (var profile in profilesResponse)
          profile['user_id'].toString(): profile['name'].toString()
      };

      // Fetch service hours
      final response = await supabase
          .from('Service hours')
          .select('user_id, hours, type')
          .neq('type', 'Meeting'); // Exclude meeting hours

      // Process the data to calculate total hours per user
      Map<String, UserRanking> userHours = {};

      for (var record in response) {
        final userId = record['user_id'] as String;
        final hours = (record['hours'] as num).toDouble();
        final userName = userNames[userId] ?? 'Unknown User';

        if (!userHours.containsKey(userId)) {
          userHours[userId] = UserRanking(
            userId: userId,
            name: userName,
            totalHours: 0,
            rank: 0,
          );
        }
        userHours[userId]!.totalHours += hours;
      }

      // Convert to list and sort by total hours
      List<UserRanking> rankings = userHours.values.toList()
        ..sort((a, b) => b.totalHours.compareTo(a.totalHours));

      // Assign ranks
      for (int i = 0; i < rankings.length; i++) {
        rankings[i].rank = i + 1;
      }

      if (mounted) {
        setState(() {
          _rankings = rankings.take(10).toList(); // Top 10
          _currentUserRanking = rankings.firstWhere(
            (ranking) => ranking.userId == widget.currentUserId,
            orElse: () => UserRanking(
              userId: widget.currentUserId,
              name: 'You',
              totalHours: 0,
              rank: rankings.length + 1,
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching leaderboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Leaderboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchLeaderboardData,
              color: Theme.of(context).colorScheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Header section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.5),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Top Contributors',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                          Text(
                            'Service Hour Champions',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_rankings.isNotEmpty) _buildTopThree(),
                        ],
                      ),
                    ),

                    if (_rankings.length > 3) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.emoji_events_outlined,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Honorable Mentions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _rankings.length - 3,
                        itemBuilder: (context, index) {
                          return _buildRankingTile(_rankings[index + 3]);
                        },
                      ),
                    ],

                    // Current user section (if not in top 10)
                    if (_currentUserRanking != null &&
                        _currentUserRanking!.rank > 10) ...[
                      const Divider(height: 40, thickness: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Your Position',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: border.Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: _buildRankingTile(_currentUserRanking!),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTopThree() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_rankings.length > 1)
          _buildPodiumItem(_rankings[1], 2, Colors.grey[400]!),
        if (_rankings.isNotEmpty)
          _buildPodiumItem(_rankings[0], 1, Colors.amber),
        if (_rankings.length > 2)
          _buildPodiumItem(_rankings[2], 3, Colors.brown[300]!),
      ],
    );
  }

  // Keep the original podium item design
  Widget _buildPodiumItem(UserRanking ranking, int position, Color color) {
    final double baseHeight = 120.0;
    final double height = position == 1
        ? baseHeight
        : position == 2
            ? baseHeight * 0.85
            : baseHeight * 0.7;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: color,
                radius: position == 1 ? 30 : 25,
                child: Text(
                  position.toString(),
                  style: TextStyle(
                    fontSize: position == 1 ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: position == 1 ? 100 : 80,
                height: height,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        ranking.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: position == 1 ? 16 : 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${ranking.totalHours.toStringAsFixed(1)}h',
                        style: TextStyle(
                          fontSize: position == 1 ? 14 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankingTile(UserRanking ranking) {
    final bool isCurrentUser = ranking.userId == widget.currentUserId;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isCurrentUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            ranking.rank.toString(),
            style: TextStyle(
              color: isCurrentUser
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        ranking.name,
        style: TextStyle(
          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '${ranking.totalHours.toStringAsFixed(1)}h',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCurrentUser
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// Helper method to get color based on event type
Color _getColorForEventType(String type, BuildContext context) {
  return Theme.of(context).colorScheme.primary;
}

class CompletedHoursPage extends StatefulWidget {
  const CompletedHoursPage({super.key});

  @override
  _CompletedHoursPageState createState() => _CompletedHoursPageState();
}

class _CompletedHoursPageState extends State<CompletedHoursPage> {
  Map<String, double> _completedHoursMap = {};
  Map<String, List<CompletedHour>> _hoursByTypeMap = {};
  Map<String, double> _requirementMap = {};
  int _meetingRequirement = 5; // Default value

  List<MeetingNote> _meetingNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Get current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get society requirements
      _meetingRequirement = society.meetingRequirement;
      _requirementMap = {};

      for (final req in society.hourRequirements) {
        if (req.isActive) {
          _requirementMap[req.type] = req.hoursNeeded;
        }
      }

      // Run queries in parallel
      await Future.wait([
        _fetchCompletedHours(),
        _fetchMeetingNotes(),
      ]);

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMeetingNotes() async {
    try {
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) return;

      final response = await Supabase.instance.client
          .from('Notes')
          .select('*')
          .eq('society_id', society.id)
          .order('created_at', ascending: false);

      setState(() {
        _meetingNotes =
            response.map((json) => MeetingNote.fromJson(json)).toList();
      });
    } catch (e) {
      print('Error fetching meeting notes: $e');
    }
  }

  Future<void> _fetchCompletedHours() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;

    if (userId != null && society != null) {
      // Get all service hours for this user in this society in a single query
      final response = await Supabase.instance.client
          .from('Service hours')
          .select('hours, type, event_name, date')
          .eq('user_id', userId)
          .eq('society_id', society.id);

      final data = response;
      Map<String, double> hoursMap = {};
      Map<String, List<CompletedHour>> hoursByType = {};

      // Initialize maps with all requirement types
      for (final reqType in _requirementMap.keys) {
        hoursMap[reqType] = 0;
        hoursByType[reqType] = [];
      }

      // Always include Meeting type
      if (!hoursMap.containsKey('Meeting')) {
        hoursMap['Meeting'] = 0;
        hoursByType['Meeting'] = [];
      }

      // Process completed hours
      for (final entry in data) {
        final hours = entry['hours'] + 0.0 ?? 0.0;
        final eventType = entry['type'] as String;
        final eventName = entry['event_name'] as String? ?? 'Unknown Event';
        final dateString = entry['date'] as String?;
        final DateTime date =
            dateString != null ? DateTime.parse(dateString) : DateTime.now();

        // Use normalized type for consistent matching
        final normalizedType = normalizeType(eventType);

        if (hoursMap.containsKey(normalizedType)) {
          hoursMap[normalizedType] = hoursMap[normalizedType]! + hours;

          // Also store the individual hour entries
          hoursByType[normalizedType]!.add(CompletedHour(
            title: eventName,
            date: date,
            hours: hours,
          ));
        }
      }

      setState(() {
        _completedHoursMap = hoursMap;
        _hoursByTypeMap = hoursByType;
      });
    }
  }

  void _showMeetingNotesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Meeting Notes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _meetingNotes.map((note) {
                return ListTile(
                  title: Text(note.title),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showNoteDetailsDialog(note);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showNoteDetailsDialog(MeetingNote note) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          scrollable: true,
          title: Text(note.title),
          content: Text(note.text),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _openLeaderboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaderboardPage(
          currentUserId: supabase.auth.currentUser?.id ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Completed Hours',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            color: Theme.of(context).colorScheme.primary,
            tooltip: 'View Leaderboard',
            onPressed: _openLeaderboard,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Header with meeting notes button
                    Card(
                      margin: const EdgeInsets.all(16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: InkWell(
                        onTap: _showMeetingNotesDialog,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).colorScheme.secondary,
                                child: Icon(
                                  Icons.notes,
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Meeting Notes',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'View important information from previous meetings',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer
                                            .withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Hour requirements sections
                    ..._buildRequirementsList(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWebsite,
        icon: const Icon(Icons.report_problem),
        label: const Text('Report Issue'),
        elevation: 4,
      ),
    );
  }

// Build list of requirements with progress and details
  List<Widget> _buildRequirementsList() {
    List<Widget> widgets = [];

    // First build standard hour requirements
    _requirementMap.forEach((type, hoursNeeded) {
      final completedHours = _completedHoursMap[type] ?? 0.0;

      widgets.add(_buildProgressBar(
          context, type, completedHours, hoursNeeded.floor()));

      widgets.add(_buildCompletedHoursList(type, _hoursByTypeMap[type] ?? []));

      widgets.add(const SizedBox(height: 20));
    });

    // Then add the special meeting requirement
    final meetingHours = _completedHoursMap['Meeting'] ?? 0.0;
    widgets.add(_buildProgressBar(
        context, 'Meeting', meetingHours, _meetingRequirement,
        isMeeting: true));

    widgets.add(
        _buildCompletedHoursList('Meeting', _hoursByTypeMap['Meeting'] ?? []));

    return widgets;
  }

  Widget _buildProgressBar(BuildContext context, String title,
      double completedHours, int hoursNeeded,
      {bool isMeeting = false}) {
    // Calculate percentage for display
    final percentage =
        ((completedHours / hoursNeeded) * 100).clamp(0, 100).toInt();
    final isComplete = completedHours >= hoursNeeded;
    final color = isMeeting
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.primary;
    final backgroundColor = isMeeting
        ? Theme.of(context).colorScheme.tertiaryContainer
        : Theme.of(context).colorScheme.primaryContainer;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Type with icon
              Row(
                children: [
                  Icon(
                    isMeeting ? Icons.groups_rounded : getIconForType(title, context),
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMeeting ? 'Meeting Attendance' : '$title Hours',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),

              // Completion percentage
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isComplete
                      ? color
                      : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isComplete ? 'Complete!' : '$percentage%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isComplete
                        ? (isMeeting
                            ? Theme.of(context).colorScheme.onTertiary
                            : Theme.of(context).colorScheme.onPrimary)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Hours text and progress
          Row(
            children: [
              Expanded(
                child: Text(
                  '${completedHours.toStringAsFixed(1)} / $hoursNeeded ${isMeeting ? 'meetings' : 'hours'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                isMeeting
                    ? '$completedHours of $hoursNeeded required'
                    : '${(completedHours / hoursNeeded * 100).toStringAsFixed(0)}% complete',
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress bar with animation
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutQuart,
            tween: Tween<double>(
              begin: 0,
              end: (completedHours / hoursNeeded).clamp(0.0, 1.0),
            ),
            builder: (context, value, _) {
              return Stack(
                children: [
                  // Background track
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: backgroundColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),

                  // Progress
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 12,
                    width: MediaQuery.of(context).size.width * value * 0.89,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedHoursList(String type, List<CompletedHour> hours) {
    if (hours.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: border.Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.event_busy,
                  size: 32,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  'No ${type.toLowerCase()} hours recorded yet',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              '${hours.length} ${hours.length == 1 ? 'Event' : 'Events'}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: hours.length,
            itemBuilder: (context, index) {
              final hour = hours[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  dense: false,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor:
                        _getColorForEventType(type, context).withOpacity(0.2),
                    child: Text(
                      hour.title.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: _getColorForEventType(type, context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    hour.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hour.date.year == 0
                            ? 'Date not recorded'
                            : '${hour.date.month}-${hour.date.day}-${hour.date.year}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          _getColorForEventType(type, context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${hour.hours.toStringAsFixed(1)}h',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getColorForEventType(type, context),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openWebsite() async {
    final Uri url = Uri.parse(
        'https://docs.google.com/forms/d/e/1FAIpQLSeXg0ctE8Lg3r4aLhUSZYWj8GlvxwxM4aTRhf3axEQRljeRtw/viewform');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch url');
    }
  }
}

class Collection {
  final int id;
  final String name;
  final List<String> eventIds;
  bool rendered;

  Collection({
    required this.id,
    required this.name,
    required this.eventIds,
    this.rendered = false,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'],
      name: json['name'],
      eventIds: json['event_ids'] is List<dynamic>
          ? List<String>.from(json['event_ids'])
          : [],
    );
  }
}

class CompletedHour {
  final String title;
  final DateTime date;
  final double hours;

  CompletedHour({
    required this.title,
    required this.date,
    required this.hours,
  });
}

class ThemeNotifier with ChangeNotifier {
  Color _themeColor = Colors.blue;

  Color get themeColor => _themeColor;

  void updateThemeColor(Color color) {
    _themeColor = color;
    notifyListeners();
  }
}

enum ThemeMode { light, dark, midnight }

class ThemeProvider extends ChangeNotifier {
  // Current theme mode
  ThemeMode _themeMode = ThemeMode.light;

  // Getter for theme mode
  ThemeMode get themeMode => _themeMode;

  // Convenience getters
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isMidnightMode => _themeMode == ThemeMode.midnight;

  ThemeProvider() {
    loadThemePreference();
  }

  /// Sets theme to specified mode
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    saveThemePreference();
    notifyListeners();
  }

  /// Loads saved theme preference from SharedPreferences.
  /// Defaults to light theme if no preference is saved.
  ///
  /// Returns:
  /// - Future<void>
  Future<void> loadThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  /// Persists current theme preference to SharedPreferences.
  ///
  /// Returns:
  /// - Future<void>
  Future<void> saveThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _themeMode.index);
  }

  // Get theme data based on current mode
  ThemeData getThemeData(Color themeColor) {
    switch (_themeMode) {
      case ThemeMode.light:
        return ThemeData(
          colorSchemeSeed: themeColor,
          useMaterial3: true,
          brightness: Brightness.light,
        );
      case ThemeMode.dark:
        return ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: themeColor,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        );
      case ThemeMode.midnight:
        // Create a truly dark "midnight" theme with deep blacks
        return ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: themeColor,
            brightness: Brightness.dark,
            background: const Color(0xFF000000),
            surface: const Color(0xFF121212),
            surfaceVariant: const Color(0xFF1C1C1C),
            surfaceContainerLowest: const Color(0xFF080808),
            primaryContainer: themeColor.withOpacity(0.1),
          ),
          scaffoldBackgroundColor: const Color(0xFF000000),
          canvasColor: const Color(0xFF121212),
          useMaterial3: true,
          cardTheme: const CardTheme(
            color: Color(0xFF121212),
          ),
          dialogTheme: const DialogTheme(
            backgroundColor: Color(0xFF121212),
          ),
        );
    }
  }
}

class SettingsPage extends StatefulWidget {
  final HonorSociety? society;

  const SettingsPage({super.key, this.society});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _email;
  late String _graduationYear;
  late String _password;
  Color _selectedColor = Colors.blue;
  bool _isAdmin = false;
  List<HonorSociety> _userSocieties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _name = '';
    _email = '';
    _graduationYear = '';
    _password = '';
    _fetchUserProfile();
    _fetchThemeColorFromPrefs();
    _fetchUserSocieties();
    if (widget.society != null) {
      _checkAdminStatus(widget.society!.id);
    }
  }

  Future<void> _fetchThemeColorFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('themeColor');
    setState(() {
      _selectedColor = colorValue != null ? Color(colorValue) : Colors.blue;
    });
  }

  Future<void> _fetchUserProfile() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;

    if (userId != null) {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          _name = response['name'] ?? '';
          _email = response['email'] ?? '';
          _graduationYear = response['graduation_year']?.toString() ?? '';
        });
      }
    }
  }

  Future<void> _fetchUserSocieties() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final societies =
          await supabase.from('user_society_memberships').select('''
            honor_societies!inner(
              id,
              name,
              description,
              image_url,
              meeting_requirement,
              created_at,
              hour_requirements(
                id,
                type,
                description,
                hours_needed,
                is_active
              )
            )
          ''').eq('user_id', userId);

      if (mounted) {
        setState(() {
          _userSocieties = societies.map<HonorSociety>((membership) {
            final societyData = membership['honor_societies'];
            final hourRequirements = (societyData['hour_requirements'] as List)
                .map((req) => HourRequirement.fromJson(req))
                .toList();

            return HonorSociety(
              id: societyData['id'],
              name: societyData['name'],
              description: societyData['description'],
              imageUrl: societyData['image_url'],
              hourRequirements: hourRequirements,
              meetingRequirement: societyData['meeting_requirement'],
              createdAt: DateTime.parse(societyData['created_at']),
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading societies: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAdminStatus(int societyId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('user_society_memberships')
          .select('is_admin')
          .eq('user_id', userId)
          .eq('society_id', societyId)
          .single();

      setState(() {
        _isAdmin = response['is_admin'] ?? false;
      });
    } catch (e) {
      print('Error checking admin status: $e');
    }
  }

  Future<void> _updateUserProfile() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;

    if (userId != null) {
      await Supabase.instance.client.from('profiles').update({
        'graduation_year': int.tryParse(_graduationYear) ?? 0,
      }).eq('user_id', userId);
    }
  }

  void _handleColorChange(Color color) {
    setState(() {
      _selectedColor = color;
    });
    _saveThemeColorToPrefs(color);
    Provider.of<ThemeNotifier>(context, listen: false).updateThemeColor(color);
  }

  Future<void> _saveThemeColorToPrefs(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', color.value);
  }

  void _switchSociety(HonorSociety society) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => MainScreen()),
      (route) => false,
    );
  }

  void _showManageSocietiesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Societies'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _userSocieties.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.group_off,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'You\'re not a member of any societies',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _userSocieties.length,
                      itemBuilder: (context, index) {
                        final society = _userSocieties[index];
                        final isCurrent = widget.society?.id == society.id;

                        return ListTile(
                          leading: society.imageUrl != null
                              ? CircleAvatar(
                                  backgroundImage:
                                      NetworkImage(society.imageUrl!))
                              : CircleAvatar(child: Text(society.name[0])),
                          title: Text(society.name),
                          subtitle: isCurrent ? const Text('Current') : null,
                          trailing: isCurrent
                              ? Icon(Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary)
                              : TextButton(
                                  child: const Text('Switch'),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _switchSociety(society);
                                  },
                                ),
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SocietyJoinRequestPage()),
              );
            },
            child: const Text('Join New Society'),
          ),
        ],
      ),
    );
  }

  void _openSocietyAdmin() {
    if (widget.society != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SocietyAdminPage(),
        ),
      );
    }
  }

  void _navigateToAccountSettings() {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const AccountSettingsPage()),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (context) => const SocietySelectionPage()),
              (route) => false,
            );
          },
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        title: Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isAdmin && widget.society != null)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Society Admin Settings',
              onPressed: _openSocietyAdmin,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Society Card
            if (widget.society != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (widget.society!.imageUrl != null)
                            CircleAvatar(
                              radius: 24,
                              backgroundImage:
                                  NetworkImage(widget.society!.imageUrl!),
                            )
                          else
                            CircleAvatar(
                              radius: 24,
                              child: Text(widget.society!.name[0]),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.society!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                if (_isAdmin)
                                  Chip(
                                    label: const Text('Admin'),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    labelStyle: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.switch_account),
                            tooltip: 'Switch Society',
                            onPressed: _showManageSocietiesDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // User Profile Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Account Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Name: $_name'),
                        Text('Email: $_email'),
                        Text('Graduation Year: $_graduationYear'),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      onPressed: _signOut,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    initialValue: _graduationYear,
                    decoration:
                        const InputDecoration(labelText: 'Graduation Year'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your graduation year';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _graduationYear = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        _updateUserProfile();
                        toastification.show(
                          context: context,
                          type: ToastificationType.success,
                          style: ToastificationStyle.simple,
                          title: const Text("Settings Successfully Updated"),
                          description: const Text(""),
                          alignment: Alignment.center,
                          autoCloseDuration: const Duration(seconds: 4),
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: lowModeShadow,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        );
                      }
                    },
                    child: const Text('Update'),
                  ),
                  // Then in the build method of SettingsPage, add this card somewhere appropriate:
                  const SizedBox(height: 24.0),
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.account_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text('Account Settings'),
                        subtitle: const Text('Update email and password'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _navigateToAccountSettings,
                      ),
                    ),
                  const SizedBox(height: 24.0),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appearance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Theme Color Picker
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _selectedColor,
                                radius: 20,
                              ),
                              title: const Text('Theme Color'),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Select Theme Color'),
                                      content: SingleChildScrollView(
                                        child: SlidePicker(
                                          pickerColor: _selectedColor,
                                          onColorChanged: _handleColorChange,
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          child: const Text('OK'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),

                            const Divider(),

                            // Theme Mode Selection
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 8.0),
                                  child: Text('Theme Mode'),
                                ),
                                RadioListTile<ThemeMode>(
                                  title: const Text('Light'),
                                  value: ThemeMode.light,
                                  groupValue:
                                      Provider.of<ThemeProvider>(context)
                                          .themeMode,
                                  onChanged: (value) {
                                    Provider.of<ThemeProvider>(context,
                                            listen: false)
                                        .setThemeMode(ThemeMode.light);
                                  },
                                ),
                                RadioListTile<ThemeMode>(
                                  title: const Text('Dark'),
                                  value: ThemeMode.dark,
                                  groupValue:
                                      Provider.of<ThemeProvider>(context)
                                          .themeMode,
                                  onChanged: (value) {
                                    Provider.of<ThemeProvider>(context,
                                            listen: false)
                                        .setThemeMode(ThemeMode.dark);
                                  },
                                ),
                                RadioListTile<ThemeMode>(
                                  title: const Text('Midnight'),
                                  value: ThemeMode.midnight,
                                  groupValue:
                                      Provider.of<ThemeProvider>(context)
                                          .themeMode,
                                  onChanged: (value) {
                                    Provider.of<ThemeProvider>(context,
                                            listen: false)
                                        .setThemeMode(ThemeMode.midnight);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            // QR Code for attendance
            Center(
              child: Column(
                children: [
                  const Text(
                    'Your Attendance QR Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BarcodeWidget(
                    barcode: barcodeGen.Barcode.qrCode(),
                    data: supabase.auth.currentUser?.id ?? '',
                    width: 200,
                    height: 200,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24.0),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SnakePage()),
                );
              },
              icon: const Icon(Icons.games),
              label: const Text('Play Snake'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionData');
    await supabase.auth.signOut();
    Navigator.pushReplacementNamed(context, '/');
  }
}

class AdminEventsPage extends StatefulWidget {
  final HonorSociety? society;
  const AdminEventsPage({super.key, this.society});

  @override
  _AdminEventsPageState createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  List<Event> _events = [];
  List<Collection> _collections = [];
  Event? _draggedEvent;
  int? _hoveredCollectionIndex;
  bool _isLoading = false;
  String _selectedEventType = 'All';

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _fetchCollections();
  }

  // Get available requirement types from current society
  List<String> get _availableEventTypes {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null)
      return ['All', 'Service', 'Tutoring', 'Meeting']; // Default fallback

    // Start with All and Meeting (special case)
    final types = ['All', 'Meeting'];

    // Add all active requirements from the society
    for (final req in society.hourRequirements) {
      if (req.isActive && !types.contains(req.type)) {
        types.add(req.type);
      }
    }

    return types;
  }

  // Add this filtered events getter
  List<Event> get _filteredEvents {
    if (_selectedEventType == 'All') return _events;

    return _events
        .where((event) =>
            normalizeType(event.type) == normalizeType(_selectedEventType))
        .toList();
  }

  // Build event type filter chips based on society requirements
  List<Widget> _buildEventTypeChips() {
    return _availableEventTypes.map((type) {
      return FilterChip(
        label: Text(type),
        selected: _selectedEventType == type,
        onSelected: (selected) {
          setState(() {
            _selectedEventType = type;
          });
        },
        backgroundColor:
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uncategorizedEvents =
        _filteredEvents.where((event) => event.collectionId == null).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        title: Text(
          'Events',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: Row(
        children: [
          // Optional side panel for wide screens
          if (isWideScreen)
            Container(
              width: 250,
              height: double.infinity,
              decoration: BoxDecoration(
                border: border.Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Vertical chips for wider screens
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      direction: Axis.vertical,
                      children: _buildEventTypeChips(),
                    ),
                    const Divider(height: 32),
                    Text(
                      'Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.add,
                          color: Theme.of(context).colorScheme.primary),
                      title: const Text('Add Event'),
                      onTap: _showAddEventDialog,
                      dense: true,
                    ),
                    ListTile(
                      leading: Icon(Icons.create_new_folder,
                          color: Theme.of(context).colorScheme.primary),
                      title: const Text('Add Collection'),
                      onTap: _showAddCollectionDialog,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),

          // Main content area (takes full width on mobile, remaining space on web)
          Expanded(
            child: Column(
              children: [
                // Show horizontal chips only on mobile
                if (!isWideScreen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 12,
                        children: _buildEventTypeChips(),
                      ),
                    ),
                  ),

                // Event Count and Loading Indicator
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isLoading
                            ? 'Loading events...'
                            : '${_filteredEvents.length} ${_filteredEvents.length == 1 ? 'event' : 'events'}${_selectedEventType != 'All' ? ' - $_selectedEventType' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                ),

                // Main event list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _fetchEvents();
                            await _fetchCollections();
                          },
                          child: _filteredEvents.isEmpty && _collections.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.event_busy,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No events found',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall,
                                      ),
                                      if (_selectedEventType != 'All')
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: TextButton.icon(
                                            icon: const Icon(
                                                Icons.filter_alt_off),
                                            label: const Text('Clear filter'),
                                            onPressed: () {
                                              setState(() {
                                                _selectedEventType = 'All';
                                              });
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _collections.length +
                                      uncategorizedEvents.length,
                                  itemBuilder: (context, index) {
                                    if (index < _collections.length) {
                                      final collection = _collections[index];
                                      return _buildCollectionCard(
                                          collection, index);
                                    } else {
                                      final event = uncategorizedEvents[
                                          index - _collections.length];
                                      return _buildEventCard(event);
                                    }
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Only show FAB on mobile
      floatingActionButton: isWideScreen
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: _showAddEventDialog,
                  heroTag: 'addEvent',
                  child: const Icon(Icons.add),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: _showAddCollectionDialog,
                  heroTag: 'addCollection',
                  child: const Icon(Icons.create_new_folder),
                ),
              ],
            ),
    );
  }

  Widget _buildEventCard(Event event) {
    final bool isNew = event.createdAt
        .isAfter(DateTime.now().subtract(const Duration(days: 7)));
    final bool isMandatory = event.isMandatory;

    // Get color for event type
    final Color typeColor = _getColorForEventType(event.type, context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Draggable<Event>(
        data: event,
        feedback: Card(
          elevation: 4.0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: typeColor.withOpacity(0.15),
                      radius: 16,
                      child: Icon(
                        getIconForType(event.type, context),
                        color: typeColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: border.Border.all(
                  color: typeColor.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'Moving ${event.name}...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        onDragStarted: () => _onEventDragStarted(event),
        onDragEnd: (details) {
          if (event.collectionId != null) {
            _onEventDropped(event, null);
          }
        },
        child: Stack(
          children: [
            // Type indicator side bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(color: typeColor),
            ),

            // Main content with full expansion
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Event icon with type color
                      CircleAvatar(
                        backgroundColor: typeColor.withOpacity(0.15),
                        radius: 20,
                        child: Icon(
                          getIconForType(event.type, context),
                          color: typeColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Event title and date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    event.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.0,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Event badges
                                if (isNew)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: border.Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withOpacity(0.2),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      'New',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                      ),
                                    ),
                                  ),

                                if (isMandatory)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiary
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: border.Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiary
                                            .withOpacity(0.2),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      'Required',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // Date and type on same row
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  "${DateFormat('MMM d, y').format(event.date)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: typeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    event.type,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: typeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Indicate number of time slots
                                Text(
                                  '${event.timeSlots.length} ${event.timeSlots.length == 1 ? 'slot' : 'slots'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons as trailing widgets
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditEventDialog(event),
                      tooltip: 'Edit Event',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _deleteEvent(event),
                      tooltip: 'Delete Event',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                // Time slots as children when expanded
                children: [
                  const Divider(height: 1),
                  ...event.timeSlots.map((timeSlot) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 2),
                          title: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: typeColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
                                style: const TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(left: 18, top: 2),
                            child: Row(
                              children: [
                                Text(
                                  'Capacity: ${timeSlot.numberOfPeople}',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Attendees: ${timeSlot.attendees.length}',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () =>
                                _showEditTimeSlotDialog(event, timeSlot),
                            visualDensity: VisualDensity.standard,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionCard(Collection collection, int index) {
    final isHovered = _hoveredCollectionIndex == index;
    final eventsInCollection = _filteredEvents
        .where((event) => event.collectionId == collection.id)
        .toList();

    return DragTarget<Event>(
      onWillAccept: (data) => true,
      onAccept: (data) {
        if (data is Event) {
          _onEventDropped(data, collection.id);
        }
      },
      onLeave: (data) {
        setState(() {
          _hoveredCollectionIndex = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isHovered
              ? Theme.of(context).colorScheme.surfaceVariant
              : Theme.of(context).colorScheme.surface,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(
                Icons.folder,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      collection.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                  // Show count of events in this collection
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: eventsInCollection.isEmpty
                          ? Theme.of(context).colorScheme.surfaceVariant
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      eventsInCollection.length.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: eventsInCollection.isEmpty
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _showDeleteCollectionDialog(collection),
                    tooltip: 'Delete Collection',
                  ),
                  const Icon(Icons.expand_more),
                ],
              ),
              children: eventsInCollection.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No events in this collection',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Drag and drop events here',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]
                  : eventsInCollection
                      .map((event) => _buildEventCard(event))
                      .toList(),
            ),
          ),
        );
      },
    );
  }

  // Helper method to get color based on event type
  Color _getColorForEventType(String type, BuildContext context) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('service'))
      return Theme.of(context).colorScheme.primary;
    if (lowerType.contains('tutor'))
      return Theme.of(context).colorScheme.secondary;
    if (lowerType.contains('meeting'))
      return Theme.of(context).colorScheme.tertiary;
    if (lowerType.contains('leader')) return Colors.amber;
    return Theme.of(context).colorScheme.primary;
  }

  void _showAddEventDialog() {
    final _formKey = GlobalKey<FormState>();
    String _eventName = '';
    String _eventDescription = '';
    DateTime _eventDate = DateTime.now();
    List<TimeSlot> _timeSlots = [];
    bool _isMandatory = false;
    String? _selectedEventType;
    int? _selectedCollectionId;
    bool _requiresForms = false;
    String _formLink = '';
    int swap_request_deadline_hours = 24;
    bool _hasDelay = false;
    int _delayHours = 0;
    late int _societyId =
        widget.society?.id ?? 1; // Default to society_id 1 if none selected

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Add Event'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Society Selection (if user is member of multiple societies)
                      FutureBuilder<List<HonorSociety>>(
                        future: _fetchUserSocieties(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          }

                          final societies = snapshot.data ?? [];

                          // Only show society dropdown if user is in multiple societies
                          if (societies.length > 1) {
                            return DropdownButtonFormField<int>(
                              value: _societyId,
                              items: societies
                                  .map((society) => DropdownMenuItem(
                                        value: society.id,
                                        child: Text(society.name),
                                      ))
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _societyId = value!),
                              decoration: const InputDecoration(
                                labelText: 'Society',
                                border: OutlineInputBorder(),
                                hintText: 'Select society for this event',
                              ),
                            );
                          }

                          // If only one society, show it as text
                          if (societies.isNotEmpty) {
                            _societyId = societies.first.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                children: [
                                  const Text('Society: ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(societies.first.name),
                                ],
                              ),
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 16),

                      // Event details
                      TextFormField(
                        decoration:
                            const InputDecoration(labelText: 'Event Name'),
                        validator: (value) => value!.isEmpty
                            ? 'Please enter an event name'
                            : null,
                        onSaved: (value) => _eventName = value!,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(
                            labelText: 'Event Description'),
                        validator: (value) => value!.isEmpty
                            ? 'Please enter a description'
                            : null,
                        onSaved: (value) => _eventDescription = value!,
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      ElevatedButton(
                        child: Text(_eventDate == null
                            ? 'Select Date'
                            : '${_eventDate.toString().substring(0, 10)}'),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _eventDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _eventDate = picked);
                          }
                        },
                      ),
                      FutureBuilder<List<HourRequirement>>(
                          future: _fetchSocietyHourRequirements(_societyId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }

                            final requirements = snapshot.data ?? [];
                            final activeTypes = requirements
                                .where((req) => req.isActive)
                                .map((req) => req.type)
                                .toList();

                            // Add Meeting to the types if not already present
                            if (!activeTypes.contains('Meeting')) {
                              activeTypes.add('Meeting');
                            }

                            return DropdownButtonFormField<String>(
                              value: _selectedEventType,
                              items: activeTypes
                                  .map((type) => DropdownMenuItem(
                                      value: type, child: Text(type)))
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedEventType = value),
                              decoration: const InputDecoration(
                                  labelText: 'Event Type'),
                              validator: (value) => value == null
                                  ? 'Please select an event type'
                                  : null,
                            );
                          }),

                      // Add remaining fields from the original implementation
                      DropdownButtonFormField<int>(
                        value: _selectedCollectionId,
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('No Collection')),
                          ..._collections.map((collection) => DropdownMenuItem(
                                value: collection.id,
                                child: Text(collection.name),
                              )),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedCollectionId = value),
                        decoration:
                            const InputDecoration(labelText: 'Collection'),
                      ),
                      TextFormField(
                        initialValue: swap_request_deadline_hours.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Cancel Deadline (hours before event)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the deadline';
                          }
                          final hours = int.tryParse(value);
                          if (hours == null || hours < 0) {
                            return 'Please enter a valid number of hours';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          swap_request_deadline_hours = int.parse(value!);
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Mandatory'),
                        value: _isMandatory,
                        onChanged: (bool? value) {
                          setState(() => _isMandatory = value!);
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Requires Forms'),
                        value: _requiresForms,
                        onChanged: (bool? value) {
                          setState(() => _requiresForms = value!);
                        },
                      ),
                      if (_requiresForms)
                        TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'Form Link'),
                          validator: (value) => value!.isEmpty
                              ? 'Please enter a form link'
                              : null,
                          onSaved: (value) => _formLink = value!,
                        ),
                      CheckboxListTile(
                        title: const Text('Signup Delay'),
                        value: _hasDelay,
                        onChanged: (bool? value) {
                          setState(() => _hasDelay = value!);
                        },
                      ),
                      if (_hasDelay)
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Delay Hours Before Event',
                            helperText: 'Hours before event to allow signup',
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: _delayHours.toString(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter delay hours';
                            }
                            final hours = int.tryParse(value);
                            if (hours == null || hours < 0) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _delayHours = int.parse(value!);
                          },
                        ),
                      SizedBox(
                        height: 15,
                      ),
                      ElevatedButton(
                        child: const Text('Add Time Slot'),
                        onPressed: () =>
                            _showAddTimeSlotDialog(setState, _timeSlots),
                      ),
                      ..._timeSlots.map((timeSlot) => ListTile(
                            title: Text(
                                '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}'),
                            subtitle:
                                Text('Capacity: ${timeSlot.numberOfPeople}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () =>
                                  setState(() => _timeSlots.remove(timeSlot)),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Add Event'),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      _addEvent(
                        _eventName,
                        _eventDescription,
                        _eventDate,
                        _selectedEventType!,
                        _isMandatory,
                        _selectedCollectionId,
                        _timeSlots,
                        _requiresForms,
                        _formLink,
                        Duration(hours: swap_request_deadline_hours),
                        _hasDelay,
                        _delayHours,
                        _societyId,
                      );
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

// Add this helper method to fetch user societies
  Future<List<HonorSociety>> _fetchUserSocieties() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final societies =
          await supabase.from('user_society_memberships').select('''
          honor_societies!inner(
            id,
            name,
            description,
            image_url,
            meeting_requirement,
            created_at
          )
        ''').eq('user_id', userId);

      return societies.map<HonorSociety>((membership) {
        final societyData = membership['honor_societies'];

        return HonorSociety(
          id: societyData['id'],
          name: societyData['name'],
          description: societyData['description'],
          imageUrl: societyData['image_url'],
          hourRequirements: [], // We'll fetch these separately if needed
          meetingRequirement: societyData['meeting_requirement'],
          createdAt: DateTime.parse(societyData['created_at']),
        );
      }).toList();
    } catch (e) {
      print('Error fetching user societies: $e');
      return [];
    }
  }

// Add this helper method to fetch society hour requirements
  Future<List<HourRequirement>> _fetchSocietyHourRequirements(
      int societyId) async {
    try {
      final response = await supabase
          .from('hour_requirements')
          .select()
          .eq('society_id', societyId);

      return response
          .map<HourRequirement>((json) => HourRequirement.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching society hour requirements: $e');
      return [];
    }
  }

// Update _fetchEvents to filter by society if specified
// In AdminEventsPage class - replace the current _fetchEvents method

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() {
          _events = [];
          _isLoading = false;
        });
        return;
      }

      // 1. Fetch events for this society
      final eventsResponse = await supabase
          .from('Events')
          .select()
          .eq('society_id', society.id)
          .order('date');

      // Create events with empty time slots first
      List<Event> events =
          eventsResponse.map<Event>((json) => Event.fromJson(json)).toList();

      // 2. Fetch time slots for all events in a single query
      final eventIds = events.map((e) => e.id).toList();
      if (eventIds.isEmpty) {
        setState(() {
          _events = [];
          _isLoading = false;
        });
        return;
      }

      final timeSlotsResponse = await supabase
          .from('Time slots')
          .select()
          .inFilter('event_id', eventIds);

      // Create a map of event_id -> List<TimeSlot>
      Map<int, List<TimeSlot>> timeSlotsByEvent = {};
      for (var json in timeSlotsResponse) {
        final timeSlot = TimeSlot.fromJson(json);
        final eventId = timeSlot.eventId;

        if (!timeSlotsByEvent.containsKey(eventId)) {
          timeSlotsByEvent[eventId] = [];
        }
        timeSlotsByEvent[eventId]!.add(timeSlot);
      }

      // 3. Fetch attendees for all time slots
      final timeSlotIds =
          timeSlotsResponse.map<int>((json) => json['id']).toList();

      if (timeSlotIds.isNotEmpty) {
        final attendeesResponse = await supabase
            .from('Attendees')
            .select('*, profiles:user_id(name)')
            .inFilter('timeslot_id', timeSlotIds);

        // Create a map of timeslot_id -> List<Attendee>
        Map<int, List<Attendee>> attendeesByTimeSlot = {};
        for (var json in attendeesResponse) {
          final attendee = Attendee(
            id: json['id'],
            timeSlotId: json['timeslot_id'],
            userId: json['user_id'],
            name: json['profiles']['name'],
            isPresent: json['is_present'] ?? false,
            formsCompleted: json['forms_completed'] ?? false,
          );

          final timeSlotId = attendee.timeSlotId;
          if (!attendeesByTimeSlot.containsKey(timeSlotId)) {
            attendeesByTimeSlot[timeSlotId] = [];
          }
          attendeesByTimeSlot[timeSlotId]!.add(attendee);
        }

        // Now assign attendees to time slots
        for (var timeSlotList in timeSlotsByEvent.values) {
          for (var timeSlot in timeSlotList) {
            if (attendeesByTimeSlot.containsKey(timeSlot.id)) {
              timeSlot.attendees = attendeesByTimeSlot[timeSlot.id]!;
            }
          }
        }
      }

      // Finally, assign time slots to events
      for (var event in events) {
        if (timeSlotsByEvent.containsKey(event.id)) {
          event.timeSlots = timeSlotsByEvent[event.id]!;
        }
      }

      // Update state with the fully assembled events
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching events: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

// Also update the _fetchCollections method to filter by society if specified
  Future<void> _fetchCollections() async {
    try {
      var query = Supabase.instance.client.from('Collections').select('*');

      // If we have a society specified, filter by it
      if (widget.society != null) {
        query = query.eq('society_id', widget.society!.id);
      }

      final response = await query;

      final List<dynamic> data = response;
      if (mounted) {
        setState(() {
          _collections = data.map((json) => Collection.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print('Error fetching collections: $e');
    }
  }

  void _showDeleteCollectionDialog(Collection collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Text(
          'Are you sure you want to delete "${collection.name}"? Events in this collection will be uncategorized but not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteCollection(collection);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCollection(Collection collection) async {
    try {
      // First update all events in this collection to remove the collection_id
      await supabase
          .from('Events')
          .update({'collection_id': null}).eq('collection_id', collection.id);

      // Then delete the collection
      await supabase.from('Collections').delete().eq('id', collection.id);

      // Update local state
      setState(() {
        _collections.removeWhere((c) => c.id == collection.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection deleted successfully')),
      );

      // Refresh events to update their display
      _fetchEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting collection: $e')),
      );
    }
  }

  void _showCollectionEvents(Collection collection) {
    showDialog(
      context: context,
      builder: (context) {
        final collectionEvents = _events
            .where((event) => event.collectionId == collection.id)
            .toList();

        return AlertDialog(
          title: Text(collection.name),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: collectionEvents.length,
              itemBuilder: (context, index) {
                final event = collectionEvents[index];
                return ListTile(
                  title: Text(event.name),
                  subtitle: Text(
                    '${event.date.month}/${event.date.day}/${event.date.year}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      _removeEventFromCollection(event, collection);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _removeEventFromCollection(Event event, Collection collection) async {
    await Supabase.instance.client.from('Events').update({
      'collection_id': null,
    }).eq('id', event.id);
    if (mounted) {
      setState(() {
        final index = _events.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          final updatedEvent = Event(
            id: event.id,
            name: event.name,
            description: event.description,
            date: event.date,
            type: event.type,
            collectionId: null,
            createdAt: event.createdAt,
          );
          _events[index] = updatedEvent;
        }
      });
    }

    Navigator.of(context).pop();
  }

  /// Creates a card widget displaying event details.
  /// Includes event information, time slots, and action buttons.
  ///
  /// Parameters:
  /// - event: Event - Event to display
  ///
  /// Returns:
  /// - Widget
  void _onEventDragStarted(Event event) {
    setState(() {
      _draggedEvent = event;
    });
  }

  void _onEventDragEnded(Event event) {
    setState(() {
      _draggedEvent = null;
    });
  }

  /// Handles drag-and-drop operations for events between collections.
  /// Updates database and UI state.
  ///
  /// Parameters:
  /// - event: Event - Event being moved
  /// - collectionId: int? - Target collection ID (null for uncategorized)
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _onEventDropped(Event event, int? collectionId) async {
    try {
      // Update the event in the database
      await Supabase.instance.client
          .from('Events')
          .update({'collection_id': collectionId}).eq('id', event.id);

      setState(() {
        final index = _events.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          // Create a new Event object with the updated collectionId
          _events[index] = Event(
            id: event.id,
            name: event.name,
            description: event.description,
            date: event.date,
            type: event.type,
            timeSlots: event.timeSlots,
            isMandatory: event.isMandatory,
            createdAt: event.createdAt,
            collectionId: collectionId,
          );
        }
      });

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(collectionId != null
                ? 'Event moved to collection'
                : 'Event removed from collection')),
      );
    } catch (e) {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating event: $e')),
      );
    }
  }

  void _showEditNotesDialog(Event event, TimeSlot timeSlot) {
    String notes = timeSlot.notes;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Notes'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Notes',
            ),
            maxLines: 3,
            controller: TextEditingController(text: notes),
            onChanged: (value) {
              notes = value;
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                _updateNotes(event, timeSlot, notes);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Updates existing meeting notes.
  ///
  /// Parameters:
  /// - noteId: int - ID of note to update
  /// - title: String - Updated title
  /// - text: String - Updated content
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _updateNotes(
      Event event, TimeSlot timeSlot, String notes) async {
    try {
      // Update the notes in the TimeSlot object
      final updatedTimeSlot = timeSlot.copyWith(notes: notes);

      // Update the TimeSlot in the database
      await Supabase.instance.client.from('Time slots').update({
        'notes': notes,
      }).eq('id', timeSlot.id ?? 0);

      // Update the TimeSlot in the Event object
      final index =
          event.timeSlots.indexWhere((slot) => slot.id == timeSlot.id);
      if (index != -1) {
        event.timeSlots[index] = updatedTimeSlot;
      }

      // Optionally, you can trigger a UI update here if needed
      // setState(() {});

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes updated successfully')),
      );
    } catch (e) {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating notes: $e')),
      );
    }
  }

  /// Displays dialog for adding new time slots to an event.
  /// Handles time selection and capacity input.
  ///
  /// Parameters:
  /// - parentSetState: StateSetter - Parent widget's setState function
  /// - timeSlots: List<TimeSlot> - Current time slots list
  ///
  /// Returns:
  /// - void
  void _showAddTimeSlotDialog(
      StateSetter parentSetState, List<TimeSlot> timeSlots) {
    final _formKey = GlobalKey<FormState>();
    TimeOfDay _startTime = TimeOfDay.now();
    TimeOfDay _endTime = TimeOfDay.now();
    int _capacity = 1;
    String _notes = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Add Time Slot'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      child: Text('Start Time: ${_startTime.format(context)}'),
                      onPressed: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (picked != null) {
                          setState(() => _startTime = picked);
                        }
                      },
                    ),
                    SizedBox(height: 14),
                    ElevatedButton(
                      child: Text('End Time: ${_endTime.format(context)}'),
                      onPressed: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (picked != null) {
                          setState(() => _endTime = picked);
                        }
                      },
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Capacity'),
                      keyboardType: const TextInputType.numberWithOptions(),
                      validator: (value) => int.tryParse(value!) == null
                          ? 'Please enter a valid number'
                          : null,
                      onSaved: (value) => _capacity = int.parse(value!),
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Notes'),
                      onSaved: (value) => _notes = value!,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Add Time Slot'),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      parentSetState(() {
                        timeSlots.add(TimeSlot(
                          id: DateTime.now()
                              .millisecondsSinceEpoch, // Temporary ID
                          time: _startTime,
                          endTime: _endTime,
                          numberOfPeople: _capacity,
                          notes: _notes,
                          eventId:
                              0, // This will be set when the event is created
                          createdAt: DateTime.now(),
                          attendees: [],
                        ));
                      });
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // In AdminEventsPage class - replace the _showEditEventDialog method

  void _showEditEventDialog(Event event) {
    final _formKey = GlobalKey<FormState>();
    String _eventName = event.name;
    String _eventDescription = event.description;
    DateTime _eventDate = event.date;
    List<TimeSlot> _timeSlots = List.from(event.timeSlots);
    bool _isMandatory = event.isMandatory;
    String? _selectedEventType = event.type;
    int? _selectedCollectionId = event.collectionId;
    bool _requiresForms = event.requiresForms;
    String _formLink = event.formLink ?? '';
    int swapRequestDeadline = event.swapRequestDeadline.inHours;
    bool _hasDelay = event.hasDelay;
    int _delayHours = event.delayHours;

    // Get available event types from society
    List<String> availableTypes = _getAvailableEventTypes();

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: const Text('Edit Event'),
                content: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          initialValue: _eventName,
                          decoration:
                              const InputDecoration(labelText: 'Event Name'),
                          validator: (value) => value!.isEmpty
                              ? 'Please enter an event name'
                              : null,
                          onSaved: (value) => _eventName = value!,
                        ),
                        TextFormField(
                          initialValue: _eventDescription,
                          decoration: const InputDecoration(
                              labelText: 'Event Description'),
                          validator: (value) => value!.isEmpty
                              ? 'Please enter a description'
                              : null,
                          onSaved: (value) => _eventDescription = value!,
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        ElevatedButton(
                          child: Text(
                              'Date: ${_eventDate.toString().substring(0, 10)}'),
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _eventDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _eventDate = picked);
                            }
                          },
                        ),
                        DropdownButtonFormField<String>(
                          value: availableTypes.contains(_selectedEventType)
                              ? _selectedEventType
                              : availableTypes.first,
                          items: availableTypes
                              .map((type) => DropdownMenuItem(
                                  value: type, child: Text(type)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedEventType = value),
                          decoration:
                              const InputDecoration(labelText: 'Event Type'),
                          validator: (value) => value == null
                              ? 'Please select an event type'
                              : null,
                        ),
                        TextFormField(
                          initialValue: swapRequestDeadline.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Cancel Deadline (hours before Event)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the deadline';
                            }
                            final hours = int.tryParse(value);
                            if (hours == null || hours < 0) {
                              return 'Please enter a valid number of hours';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            swapRequestDeadline = int.parse(value!);
                          },
                        ),
                        DropdownButtonFormField<int>(
                          value: _selectedCollectionId,
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('No Collection')),
                            ..._collections
                                .map((collection) => DropdownMenuItem(
                                      value: collection.id,
                                      child: Text(collection.name),
                                    )),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedCollectionId = value),
                          decoration:
                              const InputDecoration(labelText: 'Collection'),
                        ),
                        CheckboxListTile(
                          title: const Text('Mandatory'),
                          value: _isMandatory,
                          onChanged: (bool? value) {
                            setState(() => _isMandatory = value!);
                          },
                        ),
                        CheckboxListTile(
                          title: const Text('Requires Forms'),
                          value: _requiresForms,
                          onChanged: (bool? value) {
                            setState(() => _requiresForms = value!);
                          },
                        ),
                        if (_requiresForms)
                          TextFormField(
                            initialValue: _formLink,
                            decoration:
                                const InputDecoration(labelText: 'Form Link'),
                            validator: (value) => value!.isEmpty
                                ? 'Please enter a form link'
                                : null,
                            onSaved: (value) => _formLink = value!,
                          ),
                        CheckboxListTile(
                          title: const Text('Signup Delay'),
                          value: _hasDelay,
                          onChanged: (bool? value) {
                            setState(() => _hasDelay = value!);
                          },
                        ),
                        if (_hasDelay)
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Delay Hours Before Event',
                              helperText: 'Hours before event to allow signup',
                            ),
                            keyboardType: TextInputType.number,
                            initialValue: _delayHours.toString(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter delay hours';
                              }
                              final hours = int.tryParse(value);
                              if (hours == null || hours < 0) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _delayHours = int.parse(value!);
                            },
                          ),
                        ElevatedButton(
                          child: const Text('Add Time Slot'),
                          onPressed: () =>
                              _showAddTimeSlotDialog(setState, _timeSlots),
                        ),
                        ..._timeSlots.map((timeSlot) => ListTile(
                              title: Text(
                                  '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}'),
                              subtitle:
                                  Text('Capacity: ${timeSlot.numberOfPeople}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () =>
                                    setState(() => _timeSlots.remove(timeSlot)),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  ElevatedButton(
                    child: const Text('Update'),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        _updateEvent(
                            event.id,
                            _eventName,
                            _eventDescription,
                            _eventDate,
                            _selectedEventType!,
                            _isMandatory,
                            _selectedCollectionId,
                            _timeSlots,
                            _requiresForms,
                            _formLink,
                            Duration(hours: swapRequestDeadline),
                            _hasDelay,
                            _delayHours);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              );
            },
          );
        });
  }

// In AdminEventsPage class - add this helper method for getting available event types
  List<String> _getAvailableEventTypes() {
    // Get the current society
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) {
      // Default fallback types if no society is available
      return ['Service', 'Tutoring', 'Meeting'];
    }

    // Always include Meeting as a type
    final types = ['Meeting'];

    // Add all active requirement types
    for (final req in society.hourRequirements) {
      if (req.isActive && !types.contains(req.type)) {
        types.add(req.type);
      }
    }

    // If somehow we still don't have any types, add default ones
    if (types.isEmpty) {
      types.addAll(['Service', 'Tutoring', 'Meeting']);
    }

    return types;
  }

// In AdminEventsPage class - update the _showAddEventDialog method

// Update the _addEvent method to include societyId
  Future<void> _addEvent(
    String name,
    String description,
    DateTime date,
    String type,
    bool isMandatory,
    int? collectionId,
    List<TimeSlot> timeSlots,
    bool requiresForms,
    String formLink,
    Duration swapRequestDeadline,
    bool hasDelay,
    int delayHours,
    int societyId, // Add new parameter
  ) async {
    try {
      // Insert the event
      final eventResponse = await Supabase.instance.client
          .from('Events')
          .insert({
            'name': name,
            'description': description,
            'date': date.toIso8601String(),
            'type': type,
            'isMandatory': isMandatory,
            'collection_id': collectionId,
            'created_at': DateTime.now().toIso8601String(),
            'requires_forms': requiresForms,
            'form_link': requiresForms ? formLink : null,
            'swap_request_deadline_hours': swapRequestDeadline.inHours,
            'has_delay': hasDelay,
            'delay_hours': delayHours,
            'society_id': societyId, // Add society_id
          })
          .select()
          .single();

      final newEventId = eventResponse['id'];

      // Insert time slots
      for (var timeSlot in timeSlots) {
        final timeSlotResponse = await Supabase.instance.client
            .from('Time slots')
            .insert({
              'event_id': newEventId,
              'start_time': DateTime(DateTime.now().year, date.month, date.day,
                      timeSlot.time.hour, timeSlot.time.minute)
                  .toIso8601String(),
              'end_time': DateTime(DateTime.now().year, date.month, date.day,
                      timeSlot.endTime.hour, timeSlot.endTime.minute)
                  .toIso8601String(),
              'number_of_people': timeSlot.numberOfPeople,
              'notes': timeSlot.notes,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        final newTimeSlotId = timeSlotResponse['id'];

        // If the event is mandatory, add all users of the society as attendees
        if (isMandatory || type == "Meeting") {
          final usersResponse = await Supabase.instance.client
              .from('user_society_memberships')
              .select('user_id')
              .eq('society_id', societyId);

          for (var user in usersResponse) {
            await Supabase.instance.client.from('Attendees').insert({
              'timeslot_id': newTimeSlotId,
              'user_id': user['user_id'],
              'is_present': false,
            });
          }
        }
      }

      // Refresh the events list
      await _fetchEvents();

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event added successfully')),
      );
    } catch (e) {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding event: $e')),
      );
    }
  }

  void _showAddCollectionDialog() async {
    String collectionName = '';

    final result = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Collection Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the collection name';
                  }
                  return null;
                },
                onChanged: (value) {
                  collectionName = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () {
                if (collectionName.isNotEmpty) {
                  _addCollection(collectionName);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Creates a new collection in the database.
  ///
  /// Parameters:
  /// - name: String - Name of the new collection
  ///
  /// Returns:
  /// - Future<void>
  ///
  /// Throws:
  /// - DatabaseException if collection creation fails
  Future<void> _addCollection(String name) async {
    final response = await Supabase.instance.client
        .from('Collections')
        .insert({'name': name, 'event_ids': []});

    if (response != null) {
      final newCollection = Collection.fromJson(response[0]);
      setState(() {
        _collections.add(newCollection);
      });
    } else {
      // Handle error
      print('Failed to add collection');
    }
  }

  /// Updates an existing event's details and time slots.
  /// Handles changes in mandatory status and form requirements.
  ///
  /// Parameters:
  /// - eventId: int - ID of event to update
  /// - name: String - Updated event name
  /// - description: String - Updated description
  /// - date: DateTime - Updated date
  /// - type: String - Updated event type
  /// - isMandatory: bool - Updated mandatory status
  /// - collectionId: int? - Updated collection association
  /// - timeSlots: List<TimeSlot> - Updated time slots
  /// - requiresForms: bool - Updated forms requirement
  /// - formLink: String - Updated form link
  /// - swapRequestDeadline: Duration - Updated swap deadline
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _updateEvent(
    int eventId,
    String name,
    String description,
    DateTime date,
    String type,
    bool isMandatory,
    int? collectionId,
    List<TimeSlot> timeSlots,
    bool requiresForms,
    String formLink,
    Duration swapRequestDeadline,
    bool hasDelay,
    int delayHours,
  ) async {
    try {
      // Update the event
      await Supabase.instance.client.from('Events').update({
        'name': name,
        'description': description,
        'date': date.toIso8601String(),
        'type': type,
        'isMandatory': isMandatory,
        'collection_id': collectionId,
        'requires_forms': requiresForms,
        'form_link': requiresForms ? formLink : null,
        'swap_request_deadline_hours': swapRequestDeadline.inHours,
        'has_delay': hasDelay,
        'delay_hours': delayHours,
      }).eq('id', eventId);

      // Fetch existing time slots
      final existingTimeSlotsResponse = await Supabase.instance.client
          .from('Time slots')
          .select()
          .eq('event_id', eventId);

      final existingTimeSlots = existingTimeSlotsResponse
          .map((slot) => TimeSlot.fromJson(slot))
          .toList();

      // Update, add, or delete time slots
      for (var timeSlot in timeSlots) {
        // Check if this timeSlot exists in our existingTimeSlots list
        if (existingTimeSlots.any((slot) => slot.id == timeSlot.id)) {
          // Update existing time slot
          await Supabase.instance.client.from('Time slots').update({
            'start_time': DateTime(DateTime.now().year, date.month, date.day,
                    timeSlot.time.hour, timeSlot.time.minute)
                .toIso8601String(),
            'end_time': DateTime(DateTime.now().year, date.month, date.day,
                    timeSlot.endTime.hour, timeSlot.endTime.minute)
                .toIso8601String(),
            'number_of_people': timeSlot.numberOfPeople,
            'notes': timeSlot.notes,
          }).eq('id', timeSlot.id ?? 0);

          // Remove from existingTimeSlots list
          existingTimeSlots.removeWhere((slot) => slot.id == timeSlot.id);
        } else {
          // Add new time slot
          final newTimeSlotResponse = await Supabase.instance.client
              .from('Time slots')
              .insert({
                'event_id': eventId,
                'start_time': DateTime(DateTime.now().year, date.month,
                        date.day, timeSlot.time.hour, timeSlot.time.minute)
                    .toIso8601String(),
                'end_time': DateTime(DateTime.now().year, date.month, date.day,
                        timeSlot.endTime.hour, timeSlot.endTime.minute)
                    .toIso8601String(),
                'number_of_people': timeSlot.numberOfPeople,
                'notes': timeSlot.notes,
                'created_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

          final newTimeSlotId = newTimeSlotResponse['id'];

          // If the event is mandatory, add all users as attendees for the new time slot
          if (isMandatory) {
            final usersResponse = await Supabase.instance.client
                .from('profiles')
                .select('user_id');

            for (var user in usersResponse) {
              await Supabase.instance.client.from('Attendees').insert({
                'timeslot_id': newTimeSlotId,
                'user_id': user['user_id'],
                'is_present': false,
              });
            }
          }
        }
      }

      // Delete time slots that are no longer present
      for (var slotToDelete in existingTimeSlots) {
        await Supabase.instance.client
            .from('Time slots')
            .delete()
            .eq('id', slotToDelete.id ?? 0);

        // Also delete associated attendees
        await Supabase.instance.client
            .from('Attendees')
            .delete()
            .eq('timeslot_id', slotToDelete.id ?? 0);
      }

      // If the event has become mandatory, add all users to all time slots
      if (isMandatory) {
        final allTimeSlots = await Supabase.instance.client
            .from('Time slots')
            .select()
            .eq('event_id', eventId);

        final usersResponse =
            await Supabase.instance.client.from('profiles').select('user_id');

        for (var timeSlot in allTimeSlots) {
          for (var user in usersResponse) {
            // Check if the user is already an attendee
            final existingAttendee = await Supabase.instance.client
                .from('Attendees')
                .select()
                .eq('timeslot_id', timeSlot['id'])
                .eq('user_id', user['user_id'])
                .maybeSingle();

            if (existingAttendee == null) {
              await Supabase.instance.client.from('Attendees').insert({
                'timeslot_id': timeSlot['id'],
                'user_id': user['user_id'],
                'is_present': false,
              });
            }
          }
        }
      }

      // Refresh the events list
      await _fetchEvents();

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated successfully')),
      );
    } catch (e) {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating event: $e')),
      );
    }
  }

  /// Displays dialog for editing existing time slot details.
  ///
  /// Parameters:
  /// - event: Event - Parent event
  /// - timeSlot: TimeSlot - Time slot to edit
  ///
  /// Returns:
  /// - void
  void _showEditTimeSlotDialog(Event event, TimeSlot timeSlot) {
    final _formKey = GlobalKey<FormState>();
    TimeOfDay _startTime = timeSlot.time;
    TimeOfDay _endTime = timeSlot.endTime;
    int _capacity = timeSlot.numberOfPeople;
    String _notes = timeSlot.notes;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Time Slot'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  child: Text('Start Time: ${_startTime.format(context)}'),
                  onPressed: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _startTime,
                    );
                    if (picked != null) {
                      setState(() => _startTime = picked);
                    }
                  },
                ),
                SizedBox(height: 14),
                ElevatedButton(
                  child: Text('End Time: ${_endTime.format(context)}'),
                  onPressed: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _endTime,
                    );
                    if (picked != null) {
                      setState(() => _endTime = picked);
                    }
                  },
                ),
                TextFormField(
                  initialValue: _capacity.toString(),
                  decoration: const InputDecoration(labelText: 'Capacity'),
                  keyboardType: const TextInputType.numberWithOptions(),
                  validator: (value) => int.tryParse(value!) == null
                      ? 'Please enter a valid number'
                      : null,
                  onSaved: (value) => _capacity = int.parse(value!),
                ),
                TextFormField(
                  initialValue: _notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  onSaved: (value) => _notes = value!,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Update Time Slot'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  _updateTimeSlot(
                      event, timeSlot, _startTime, _endTime, _capacity, _notes);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Updates existing time slot information.
  ///
  /// Parameters:
  /// - event: Event - Parent event
  /// - timeSlot: TimeSlot - Time slot to update
  /// - startTime: TimeOfDay - New start time
  /// - endTime: TimeOfDay - New end time
  /// - capacity: int - New capacity
  /// - notes: String - Updated notes
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _updateTimeSlot(
      Event event,
      TimeSlot timeSlot,
      TimeOfDay startTime,
      TimeOfDay endTime,
      int capacity,
      String notes) async {
    try {
      // Update the time slot in the database
      await Supabase.instance.client.from('Time slots').update({
        'start_time': DateTime(DateTime.now().year, event.date.month,
                event.date.day, startTime.hour, startTime.minute)
            .toIso8601String(),
        'end_time': DateTime(DateTime.now().year, event.date.month,
                event.date.day, endTime.hour, endTime.minute)
            .toIso8601String(),
        'number_of_people': capacity,
        'notes': notes,
      }).eq('id', timeSlot.id ?? 0);

      // Update the time slot in the local state
      setState(() {
        final updatedTimeSlot = timeSlot.copyWith(
          time: startTime,
          endTime: endTime,
          numberOfPeople: capacity,
          notes: notes,
        );

        final eventIndex = _events.indexWhere((e) => e.id == event.id);
        if (eventIndex != -1) {
          final timeSlotIndex = _events[eventIndex]
              .timeSlots
              .indexWhere((ts) => ts.id == timeSlot.id);
          if (timeSlotIndex != -1) {
            _events[eventIndex].timeSlots[timeSlotIndex] = updatedTimeSlot;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time slot updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating time slot: $e')),
      );
    }
  }

  /// Creates a new event in the database with specified parameters.
  /// Handles mandatory and meeting events by automatically adding all users as attendees.
  ///
  /// Parameters:
  /// - name: String - Event name
  /// - description: String - Event description
  /// - date: DateTime - Event date
  /// - type: String - Event type (Service/Tutoring/Meeting)
  /// - isMandatory: bool - Whether attendance is required
  /// - collectionId: int? - Optional collection association
  /// - timeSlots: List<TimeSlot> - Available time slots
  /// - requiresForms: bool - Whether forms are required
  /// - formLink: String - Link to required forms
  /// - swapRequestDeadline: Duration - Deadline for swap requests
  ///
  /// Returns:
  /// - Future<void>

  /// Registers a user for a specific time slot in an event.
  /// Checks capacity and existing registration.
  ///
  /// Parameters:
  /// - event: Event - Target event
  /// - timeSlot: TimeSlot - Selected time slot
  ///
  /// Returns:
  /// - Future<void>
  void _deleteEvent(Event event) async {
    setState(() {
      _events.remove(event);
    });
    await Supabase.instance.client.from('Events').delete().eq('id', event.id);
  }
}

class TimeSlot {
  final int? id;
  final TimeOfDay time;
  final TimeOfDay endTime;
  final int numberOfPeople;
  final String notes;
  final int eventId;
  final DateTime createdAt;
  List<Attendee> attendees;

  TimeSlot({
    this.id,
    required this.time,
    required this.endTime,
    required this.numberOfPeople,
    this.notes = '',
    required this.eventId,
    required this.createdAt,
    List<Attendee>? attendees,
  }) : attendees = attendees ?? [];

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      id: json['id'],
      time: TimeOfDay.fromDateTime(
          DateTime.parse(json['start_time'] ?? "2012-02-27" as String)),
      endTime: TimeOfDay.fromDateTime(
          DateTime.parse(json['end_time'] ?? "2012-02-27" as String)),
      numberOfPeople: json['number_of_people'] as int? ?? 0,
      notes: json['notes'] as String? ?? '',
      eventId: json['event_id'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      attendees: [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_time': '${time.hour}:${time.minute}',
      'end_time': '${endTime.hour}:${endTime.minute}',
      'number_of_people': numberOfPeople,
      'notes': notes,
      'event_id': eventId,
      'created_at': createdAt.toIso8601String(),
      'attendees': attendees.map((attendee) => attendee.toJson()).toList(),
    };
  }

  TimeSlot copyWith({
    int? id,
    TimeOfDay? time,
    TimeOfDay? endTime,
    int? numberOfPeople,
    String? notes,
    int? eventId,
    DateTime? createdAt,
    List<Attendee>? attendees,
  }) {
    return TimeSlot(
      id: id ?? this.id,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      numberOfPeople: numberOfPeople ?? this.numberOfPeople,
      notes: notes ?? this.notes,
      eventId: eventId ?? this.eventId,
      createdAt: createdAt ?? this.createdAt,
      attendees: attendees ?? List.from(this.attendees),
    );
  }
}

class Event {
  final int id;
  final String name;
  final String description;
  final DateTime date;
  final String type;
  final bool isMandatory;
  final DateTime createdAt;
  final int? collectionId;
  List<TimeSlot> timeSlots;
  final bool requiresForms;
  final String? formLink;
  final bool hasDelay;
  final int delayHours;
  final Duration swapRequestDeadline; // New property

  Event({
    required this.id,
    required this.name,
    required this.description,
    required this.date,
    required this.type,
    this.isMandatory = false,
    required this.createdAt,
    this.collectionId,
    List<TimeSlot>? timeSlots,
    this.requiresForms = false,
    this.formLink,
    this.swapRequestDeadline = const Duration(days: 1),
    this.hasDelay = false,
    this.delayHours = 0,
  }) : timeSlots = timeSlots ?? [];

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      type: json['type'],
      isMandatory: json['isMandatory'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      collectionId: json['collection_id'],
      timeSlots: (json['timeSlots'] as List<dynamic>?)
              ?.map((timeSlotJson) => TimeSlot.fromJson(timeSlotJson))
              .toList() ??
          [],
      requiresForms: json['requires_forms'] ?? false,
      formLink: json['form_link'],
      swapRequestDeadline:
          Duration(hours: json['swap_request_deadline_hours'] ?? 24),
      hasDelay: json['has_delay'] ?? false,
      delayHours: json['delay_hours'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'date': date.toIso8601String(),
      'type': type,
      'isMandatory': isMandatory,
      'created_at': createdAt.toIso8601String(),
      'collection_id': collectionId,
      'timeSlots': timeSlots.map((timeSlot) => timeSlot.toJson()).toList(),
      'requires_forms': requiresForms,
      'form_link': formLink,
      'swap_request_deadline_hours': swapRequestDeadline.inHours,
      'has_delay': hasDelay,
      'delay_hours': delayHours,
    };
  }

  bool canSignUpForTimeSlot(TimeSlot timeSlot) {
    if (!hasDelay) return true;

    final now = DateTime.now();
    final eventDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      timeSlot.time.hour,
      timeSlot.time.minute,
    );

    final signupDateTime = eventDateTime.subtract(Duration(hours: delayHours));
    return now.isAfter(signupDateTime);
  }

  Event copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? date,
    String? type,
    bool? isMandatory,
    DateTime? createdAt,
    int? collectionId,
    List<TimeSlot>? timeSlots,
    bool? requiresForms,
    String? formLink,
    Duration? swapRequestDeadline,
    bool? hasDelay,
    int? delayHours,
  }) {
    return Event(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        date: date ?? this.date,
        type: type ?? this.type,
        isMandatory: isMandatory ?? this.isMandatory,
        createdAt: createdAt ?? this.createdAt,
        collectionId: collectionId ?? this.collectionId,
        timeSlots: timeSlots ?? List.from(this.timeSlots),
        requiresForms: requiresForms ?? this.requiresForms,
        formLink: formLink ?? this.formLink,
        hasDelay: hasDelay ?? this.hasDelay,
        delayHours: delayHours ?? this.delayHours,
        swapRequestDeadline: swapRequestDeadline ?? this.swapRequestDeadline);
  }
}

extension UserRequirementsCheck on UserProfile {
  bool hasMetRequirements(String eventType, HonorSociety society) {
    // Map to count hours by type
    Map<String, double> hoursByType = {};

    // Initialize with 0 for each requirement type
    for (final req in society.hourRequirements) {
      if (req.isActive) {
        hoursByType[req.type] = 0.0;
      }
    }

    // Add special Meeting type if not already covered
    hoursByType.putIfAbsent('Meeting', () => 0.0);

    // Tally up the completed hours by type
    for (final hour in completedHours) {
      final type = hour.type;
      if (hoursByType.containsKey(type)) {
        hoursByType[type] = hoursByType[type]! + hour.hours;
      }
    }

    // For Meeting type, we check against the meeting requirement
    if (eventType == 'Meeting') {
      return hoursByType['Meeting']! >= society.meetingRequirement;
    }

    // For other types, find the corresponding requirement
    for (final req in society.hourRequirements) {
      if (req.isActive && req.type == eventType) {
        return hoursByType[eventType]! >= req.hoursNeeded;
      }
    }

    // If we get here, there's no specific requirement for this event type
    return false;
  }

  // Check if user has met all requirements for the society
  bool hasMetAllRequirements(HonorSociety society) {
    // Map to count hours by type
    Map<String, double> hoursByType = {};

    // Initialize with 0 for each requirement type
    for (final req in society.hourRequirements) {
      if (req.isActive) {
        hoursByType[req.type] = 0.0;
      }
    }

    // Add special Meeting type if not already covered
    hoursByType.putIfAbsent('Meeting', () => 0.0);

    // Tally up the completed hours by type
    for (final hour in completedHours) {
      final type = hour.type;
      if (hoursByType.containsKey(type)) {
        hoursByType[type] = hoursByType[type]! + hour.hours;
      }
    }

    // Check Meeting requirement
    if (hoursByType['Meeting']! < society.meetingRequirement) {
      return false;
    }

    // Check all other active requirements
    for (final req in society.hourRequirements) {
      if (req.isActive && hoursByType[req.type]! < req.hoursNeeded) {
        return false;
      }
    }

    return true;
  }
}

class MeetingNote {
  final int id;
  final String title;
  final String text;
  final DateTime createdAt;

  MeetingNote({
    required this.id,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  factory MeetingNote.fromJson(Map<String, dynamic> json) {
    return MeetingNote(
      id: json['id'],
      title: json['title'] ?? '',
      text: json['text'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

Future<void> fetchEventDetails(Event event) async {
  // Fetch time slots
  final timeSlotResponse = await Supabase.instance.client
      .from('Time slots')
      .select()
      .eq('event_id', event.id);

  final List<TimeSlot> timeSlots = timeSlotResponse
      .map((json) => TimeSlot.fromJson(json as Map<String, dynamic>))
      .toList();
  // Fetch attendees for each time slot
  for (var timeSlot in timeSlots) {
    final attendeeResponse = await Supabase.instance.client
        .from('Attendees')
        .select('*, profiles!inner(name)')
        .eq('timeslot_id', timeSlot?.id ?? 0);

    final List<Attendee> attendees = attendeeResponse
        .map((json) => Attendee.fromJson({
              ...json,
              'name': json['profiles']['name'],
            }))
        .toList();

    timeSlot.attendees = attendees;

    // Attach attendees to the time slot (you might want to create a new property in TimeSlot class for this)
    // timeSlot.attendees = attendees;
  }
}

class CustomExpansionTile extends ExpansionTile {
  const CustomExpansionTile({
    super.key,
    required super.title,
    required super.children,
    super.initiallyExpanded,
    super.tilePadding,
  });

  @override
  Widget _buildChildren(BuildContext context, Widget? child,
      AnimationController? controller, bool expanded) {
    return Container(
      child: Column(
        children: children,
      ),
    );
  }
}

class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  _AdminAttendancePageState createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  List<Event> _events = [];
  List<Collection> _collections = [];
  bool _isLoading = true;
  String _selectedEventType = 'All'; // Added for filtering
  DateTime? _startDate;
  DateTime? _endDate;


  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _fetchEvents(),
        _fetchCollections(),
      ]);
    } catch (e) {
      print('Error fetching data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Get available requirement types from current society
  List<String> get _availableEventTypes {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null)
      return ['All', 'Service', 'Tutoring', 'Meeting']; // Default fallback

    // Start with All and Meeting (special case)
    final types = ['All', 'Meeting'];

    // Add all active requirements from the society
    for (final req in society.hourRequirements) {
      if (req.isActive && !types.contains(req.type)) {
        types.add(req.type);
      }
    }

    return types;
  }

  // Add this filtered events getter
  List<Event> get _filteredEvents {
    if (_selectedEventType == 'All') return _events;

    return _events
        .where((event) =>
            normalizeType(event.type) == normalizeType(_selectedEventType))
        .toList();
  }

  // Build event type filter chips based on society requirements
  List<Widget> _buildEventTypeChips() {
    return _availableEventTypes.map((type) {
      return FilterChip(
        label: Text(type),
        selected: _selectedEventType == type,
        onSelected: (selected) {
          setState(() {
            _selectedEventType = type;
          });
        },
        backgroundColor:
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        title: Text(
          'Attendance',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: Row(
        children: [
          // Optional side panel for wide screens
          if (isWideScreen)
            Container(
              width: 250,
              height: double.infinity,
              decoration: BoxDecoration(
                border: border.Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Date selector in sidebar for wide screens
                    _buildDateRangeSelector(isCompact: false),
                    const SizedBox(height: 16),
                    // Vertical chips for wider screens
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      direction: Axis.vertical,
                      children: _buildEventTypeChips(),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            
          // Main content area (takes full width on mobile, remaining space on web)
          Expanded(
            child: Column(
              children: [
                // Today's Events Section 
                _buildTodaysEventsHeader(),
                
                // Show horizontal chips and date selector only on mobile
                if (!isWideScreen) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 12,
                        children: _buildEventTypeChips(),
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: _buildDateRangeSelector(isCompact: true),
                  ),
                ],
                
                // Event Count and Loading Indicator
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _filteredEvents.isEmpty 
                          ? 'No events found' 
                          : '${_filteredEvents.length} ${_filteredEvents.length == 1 ? 'event' : 'events'}${_selectedEventType != 'All' ? ' - $_selectedEventType' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_isLoading) 
                        const SizedBox(
                          width: 16, 
                          height: 16, 
                          child: CircularProgressIndicator(strokeWidth: 2)
                        ),
                    ],
                  ),
                ),
                
                // Main event list
                Expanded(
                  child: _filteredEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No events found',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (_selectedEventType != 'All')
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextButton.icon(
                                  icon: const Icon(Icons.filter_alt_off),
                                  label: const Text('Clear filter'),
                                  onPressed: () {
                                    setState(() {
                                      _selectedEventType = 'All';
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredEvents.length,
                        itemBuilder: (context, index) {
                          final event = _filteredEvents[index];
                          return _buildEventCard(event);
                        },
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // Now create a date range selector widget
  Widget _buildDateRangeSelector({required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCompact) 
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Date Range',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        Row(
          children: [
            // Start date selector
            Expanded(
              child: InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked;
                    });
                    _fetchEvents();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: border.Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _startDate == null 
                              ? 'Start Date' 
                              : DateFormat('MMM d, y').format(_startDate!),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _startDate == null 
                                ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_startDate != null)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _startDate = null;
                            });
                            _fetchEvents();
                          },
                          child: Icon(
                            Icons.clear,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // End date selector
            Expanded(
              child: InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? (_startDate != null ? _startDate! : DateTime.now()),
                    firstDate: _startDate ?? DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _endDate = picked;
                    });
                    _fetchEvents();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: border.Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _endDate == null 
                              ? 'End Date' 
                              : DateFormat('MMM d, y').format(_endDate!),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _endDate == null 
                                ? Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_endDate != null)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _endDate = null;
                            });
                            _fetchEvents();
                          },
                          child: Icon(
                            Icons.clear,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // Show applied filter info if dates are selected
        if (_startDate != null || _endDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _getDateRangeText(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    _fetchEvents();
                  },
                  child: Text(
                    'Clear filter',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Helper to generate date range description text
  String _getDateRangeText() {
    if (_startDate != null && _endDate != null) {
      return 'Showing events from ${DateFormat('MMM d').format(_startDate!)} to ${DateFormat('MMM d').format(_endDate!)}';
    } else if (_startDate != null) {
      return 'Showing events from ${DateFormat('MMM d').format(_startDate!)} onwards';
    } else if (_endDate != null) {
      return 'Showing events until ${DateFormat('MMM d').format(_endDate!)}';
    }
    return '';
  }
    // Display today's events or upcoming events section
  Widget _buildTodaysEventsHeader() {
    // Filter today's events
    final now = DateTime.now();
    final todaysEvents = _events.where((event) {
      return event.date.year == now.year &&
          event.date.month == now.month &&
          event.date.day == now.day;
    }).toList();

    // If no events today, don't show the section
    if (todaysEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_available,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Events",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d').format(now),
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Chip(
                  label: Text(
                    '${todaysEvents.length} ${todaysEvents.length == 1 ? 'event' : 'events'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ],
            ),
          ),

          // Today's events list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todaysEvents.length,
            itemBuilder: (context, index) {
              final event = todaysEvents[index];
              return _buildTodaysEventItem(event);
            },
          ),

          // Bottom padding
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // Today's event item with attendance stats
  Widget _buildTodaysEventItem(Event event) {
    // Calculate attendance info
    int totalAttendees = 0;
    int presentAttendees = 0;

    for (final timeSlot in event.timeSlots) {
      totalAttendees += timeSlot.attendees.length;
      presentAttendees += timeSlot.attendees.where((a) => a.isPresent).length;
    }

    // Calculate attendance percentage
    final attendancePercentage =
        totalAttendees > 0 ? (presentAttendees / totalAttendees) * 100 : 0.0;

    // Determine if any time slots are happening now
    final now = DateTime.now();
    final currentHour = TimeOfDay.fromDateTime(now);

    bool isHappeningNow = false;
    TimeSlot? currentTimeSlot;

    for (final timeSlot in event.timeSlots) {
      final startMinutes = timeSlot.time.hour * 60 + timeSlot.time.minute;
      final endMinutes = timeSlot.endTime.hour * 60 + timeSlot.endTime.minute;
      final currentMinutes = currentHour.hour * 60 + currentHour.minute;

      if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
        isHappeningNow = true;
        currentTimeSlot = timeSlot;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to attendance check page for this event/time slot
          if (event.timeSlots.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceCheckPage(
                  event: event,
                  timeSlot: currentTimeSlot ?? event.timeSlots.first,
                ),
              ),
            ).then((_) => _fetchData());
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Event icon with type color
              CircleAvatar(
                backgroundColor: _getColorForEventType(event.type, context)
                    .withOpacity(0.15),
                child: Icon(
                  getIconForType(event.type, context),
                  color: _getColorForEventType(event.type, context),
                ),
              ),
              const SizedBox(width: 12),

              // Event info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event title with optional "happening now" badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isHappeningNow)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'NOW',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Event type
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getColorForEventType(event.type, context)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        event.type,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getColorForEventType(event.type, context),
                        ),
                      ),
                    ),

                    // Time slots
                    if (event.timeSlots.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.timeSlots.length == 1
                            ? NhsFormatUtils.formatTimeSlot(event.timeSlots.first, context)
                            : '${event.timeSlots.length} time slots',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Attendance ratio
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attendance info
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$presentAttendees/$totalAttendees',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: presentAttendees > 0
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress indicator
                  SizedBox(
                    width: 60,
                    height: 8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalAttendees > 0
                            ? presentAttendees / totalAttendees
                            : 0,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Percentage text
                  Text(
                    '${attendancePercentage.round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    // Get color for event type
    final Color typeColor = _getColorForEventType(event.type, context);

    // Calculate attendance stats
    int totalAttendees = 0;
    int presentAttendees = 0;

    for (final timeSlot in event.timeSlots) {
      totalAttendees += timeSlot.attendees.length;
      presentAttendees += timeSlot.attendees.where((a) => a.isPresent).length;
    }

    final attendancePercentage =
        totalAttendees > 0 ? (presentAttendees / totalAttendees) * 100 : 0.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Type indicator side bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(color: typeColor),
          ),

          // Main content with full expansion
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 0, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Event icon with type color
                    CircleAvatar(
                      backgroundColor: typeColor.withOpacity(0.15),
                      radius: 20,
                      child: Icon(
                        getIconForType(event.type, context),
                        color: typeColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Event info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event title
                          Text(
                            event.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Date and type
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${DateFormat('MMM d').format(event.date)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  event.type,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Attendance ratio
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Attendance: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '$presentAttendees/$totalAttendees',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${attendancePercentage.round()}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Time slots as children when expanded
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time Slots',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${event.timeSlots.length} ${event.timeSlots.length == 1 ? 'slot' : 'slots'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ...event.timeSlots.map((timeSlot) {
                  final timeSlotAttendees = timeSlot.attendees.length;
                  final timeSlotPresent =
                      timeSlot.attendees.where((a) => a.isPresent).length;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: border.Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        title: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: typeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${NhsFormatUtils.formatTimeOfDay(timeSlot.time, context)} - ${NhsFormatUtils.formatTimeOfDay(timeSlot.endTime, context)}',
                              style: const TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(left: 18, top: 2),
                          child: Text(
                            'Attendance: $timeSlotPresent/$timeSlotAttendees',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.checklist, size: 20),
                          color: Theme.of(context).colorScheme.onSurface,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AttendanceCheckPage(
                                  event: event,
                                  timeSlot: timeSlot,
                                ),
                              ),
                            ).then((_) => _fetchData());
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 0),
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get color based on event type
  Color _getColorForEventType(String type, BuildContext context) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('service'))
      return Theme.of(context).colorScheme.primary;
    if (lowerType.contains('tutor'))
      return Theme.of(context).colorScheme.secondary;
    if (lowerType.contains('meeting'))
      return Theme.of(context).colorScheme.tertiary;
    if (lowerType.contains('leader')) return Colors.amber;
    return Theme.of(context).colorScheme.primary;
  }

  Future<void> _fetchEvents() async {
    
      setState(() {
        _isLoading = true;
      });
    try {
      // Get current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() {
          _events = [];
          _isLoading = false;
        });
        return;
      }

      // 1. Start building query for events in this society
      var query = supabase
          .from('Events')
          .select()
          .eq('society_id', society.id);
      
      // 2. Apply date range filter if dates are selected
      if (_startDate != null) {
        query = query.gte('date', _startDate!.toIso8601String());
      }
      
      if (_endDate != null) {
        // Include the entire end date by setting time to end of day
        final endOfDay = DateTime(
          _endDate!.year, 
          _endDate!.month, 
          _endDate!.day, 
          23, 59, 59
        );
        query = query.lte('date', endOfDay.toIso8601String());
      }
      
      // 3. Order by date
      final eventResponse = await query.order('date');

      // Create events map for quick lookups
      final Map<int, Event> eventsMap = {
        for (var json in eventResponse) json['id']: Event.fromJson(json)
      };

      // 2. Fetch all time slots for these events in a single query
      final timeSlotResponse = await Supabase.instance.client
          .from('Time slots')
          .select()
          .inFilter('event_id', eventsMap.keys.toList());

      // Create time slots map for quick lookups
      final Map<int, TimeSlot> timeSlotsMap = {
        for (var json in timeSlotResponse) json['id']: TimeSlot.fromJson(json)
      };

      // Create a map of event_id to list of time slot ids
      final Map<int, List<int>> eventToTimeSlots = {};
      for (var timeSlot in timeSlotResponse) {
        final eventId = timeSlot['event_id'] as int;
        eventToTimeSlots
            .putIfAbsent(eventId, () => [])
            .add(timeSlot['id'] as int);
      }

      // 3. Fetch all attendees with their profiles in a single query
      final attendeeResponse = await Supabase.instance.client
          .from('Attendees')
          .select('*, profiles!inner(name)')
          .inFilter('timeslot_id', timeSlotsMap.keys.toList());

      // Organize attendees by time slot
      for (var attendeeJson in attendeeResponse) {
        final timeSlotId = attendeeJson['timeslot_id'] as int;
        final attendee = Attendee.fromJson({
          ...attendeeJson,
          'name': attendeeJson['profiles']['name'],
        });

        if (timeSlotsMap.containsKey(timeSlotId)) {
          timeSlotsMap[timeSlotId]!.attendees.add(attendee);
        }
      }

      // Assemble the final event structure
      final List<Event> assembledEvents = [];
      for (var entry in eventToTimeSlots.entries) {
        final eventId = entry.key;
        final timeSlotIds = entry.value;

        if (eventsMap.containsKey(eventId)) {
          final event = eventsMap[eventId]!;
          event.timeSlots = timeSlotIds.map((id) => timeSlotsMap[id]!).toList();
          assembledEvents.add(event);
        }
      }

      if (mounted) {
        setState(() {
          _events = assembledEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching events: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: $e')),
        );
      }
    }
  }

  Future<void> _fetchCollections() async {
    try {
      // Get current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() => _collections = []);
        return;
      }

      final collectionsResponse = await Supabase.instance.client
          .from('Collections')
          .select('*')
          .eq('society_id', society.id);

      setState(() {
        _collections = collectionsResponse
            .map<Collection>((json) => Collection.fromJson(json))
            .toList();
      });
    } catch (e) {
      print('Error fetching collections: $e');
    }
  }
}

class AdminListPage extends StatefulWidget {
  const AdminListPage({super.key});

  @override
  _AdminListPageState createState() => _AdminListPageState();
}

enum SortField {
  name,
  totalHours,
  serviceHours,
  tutoringHours,
  meetingHours,
}

enum SortOrder {
  ascending,
  descending,
}

  class _AdminListPageState extends State<AdminListPage> {
  final List<UserProfile> _users = [];
  String _searchQuery = '';
  SortField _sortField = SortField.name;
  SortOrder _sortOrder = SortOrder.ascending;
  String? _selectedHourType;
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // Helper method to get available requirement types from current society
  List<String> get _availableHourTypes {
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return ['All'];
    
    final types = ['All', 'Meeting']; // Always include these
    

    
    // Add all active requirements from the society
    for (final req in society.hourRequirements) {
      if (req.isActive && !types.contains(req.type)) {
        types.add(req.type);
      }
    }
    
    return types;
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _users.clear();
      _isLoading = true;
    });

    try {
      // Get current society
      final societyId = Provider.of<SocietyProvider>(context, listen: false).currentSociety?.id;
      if (societyId == null) {
        setState((){
          _isLoading = false;
        });
        return;
      }
      
      // Get all the data we need in just two queries run in parallel
      final results = await Future.wait([
        // 1. Get members with their profiles and dues status in a single query
        supabase
          .from('user_society_memberships')
          .select('''
            user_id, 
            has_paid_dues,
            profiles:user_id(name, email)
          ''')
          .eq('society_id', societyId),
        
        // 2. Get all service hours for this society at once
        supabase
          .from('Service hours')
          .select('user_id, event_name, hours, type')
          .eq('society_id', societyId)
      ]);
      
      final memberships = results[0] as List;
      final hoursData = results[1] as List;
      
      // Process hours data into a map for quick lookup
      Map<String, List<CompletedUserHour>> userHoursMap = {};
      for (final hourData in hoursData) {
        final userId = hourData['user_id'] as String;
        final hour = CompletedUserHour.fromJson(hourData);
        userHoursMap.putIfAbsent(userId, () => []).add(hour);
      }
      
      // Build the user profiles from the combined data
      final List<UserProfile> users = [];
      for (final membership in memberships) {
        final userId = membership['user_id'] as String;
        final profileData = membership['profiles'];
        
        if (profileData != null) {
          users.add(UserProfile(
            name: profileData['name'] as String,
            id: userId,
            completedHours: userHoursMap[userId] ?? [],
            hasPaidDues: membership['has_paid_dues'] as bool? ?? false,
          ));
        }
      }
      
      // Sort users by name
      users.sort((a, b) => a.name.compareTo(b.name));
      
      if (mounted) {
        setState(() {
          _users.addAll(users);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching users: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  List<UserProfile> _getFilteredAndSortedUsers() {
    List<UserProfile> filteredUsers = _users;

    if (_searchQuery.isNotEmpty) {
      final lowercaseQuery = _searchQuery.toLowerCase();
      filteredUsers = filteredUsers.where((user) {
        final lowercaseName = user.name.toLowerCase();
        return lowercaseName.contains(lowercaseQuery);
      }).toList();
    }

    // Filter by hour type if selected
    if (_selectedHourType != null && _selectedHourType != 'All') {
      filteredUsers = filteredUsers.where((user) {
        return user.completedHours.any((hour) => 
          normalizeType(hour.type) == normalizeType(_selectedHourType!));
      }).toList();
    }

    filteredUsers.sort((a, b) {
      int comparison;
      switch (_sortField) {
        case SortField.name:
          comparison = a.name.compareTo(b.name);
          break;
        case SortField.totalHours:
          comparison = _getTotalHours(a).compareTo(_getTotalHours(b));
          break;
        case SortField.serviceHours:
          if (_selectedHourType != null && _selectedHourType != 'All') {
            // Use dynamic type if specified
            comparison = _getHoursByType(a, _selectedHourType!)
                .compareTo(_getHoursByType(b, _selectedHourType!));
          } else {
            // Default to all service hours
            comparison = _getHoursByType(a, 'Service')
                .compareTo(_getHoursByType(b, 'Service'));
          }
          break;
        case SortField.tutoringHours:
          comparison = _getHoursByType(a, 'Tutoring')
              .compareTo(_getHoursByType(b, 'Tutoring'));
          break;
        case SortField.meetingHours:
          comparison = _getHoursByType(a, 'Meeting')
              .compareTo(_getHoursByType(b, 'Meeting'));
          break;
      }

      return _sortOrder == SortOrder.ascending ? comparison : -comparison;
    });

    return filteredUsers;
  }

  double _getTotalHours(UserProfile user) {
    return user.completedHours.fold(0.0, (sum, hour) => sum + hour.hours);
  }

  double _getHoursByType(UserProfile user, String type) {
    return user.completedHours
        .where((hour) => normalizeType(hour.type) == normalizeType(type))
        .fold(0.0, (sum, hour) => sum + hour.hours);
  }

  // Helper to build hour summary card in user details dialog
  Widget _buildHourTypeCards(UserProfile user) {
    final List<Widget> cards = [];
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    
    // Total hours card (always show)
    cards.add(
      Expanded(
        child: _buildHourSummaryCard(
          'Total',
          _getTotalHours(user).toStringAsFixed(1),
          Icons.watch_later,
          Theme.of(context).colorScheme.primary,
        ),
      )
    );
    
    // Meeting hours (always include)
    cards.add(
      Expanded(
        child: _buildHourSummaryCard(
          'Meeting',
          _getHoursByType(user, 'Meeting').toStringAsFixed(1),
          Icons.groups,
          Theme.of(context).colorScheme.tertiary,
        ),
      )
    );
    
    // Add cards for each active requirement type
    if (society != null) {
      for (final req in society.hourRequirements) {
        if (req.isActive && req.type != 'Meeting') {
          cards.add(
            Expanded(
              child: _buildHourSummaryCard(
                req.type,
                _getHoursByType(user, req.type).toStringAsFixed(1),
                _getIconForHourType(req.type),
                _getColorForHourType(req.type, context),
              ),
            )
          );
        }
      }
    }
    
    return Row(
      children: cards,
    );
  }

  // Helper to generate hour breakdown text based on society requirements
  String _generateHoursBreakdownText(UserProfile user) {
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return '';
    
    // If filtered by specific type
    if (_selectedHourType != null && _selectedHourType != 'All') {
      final selectedHours = _getHoursByType(user, _selectedHourType!);
      return '${selectedHours.toStringAsFixed(1)} ${_selectedHourType} hrs';
    }
    
    // Type abbreviations
    final StringBuffer text = StringBuffer();
    
    // Always include Meeting (special case)
    final meetingHours = _getHoursByType(user, 'Meeting');
    text.write('M: ${meetingHours.toStringAsFixed(1)}');
    
    // Add each active requirement type
    for (final req in society.hourRequirements) {
      if (req.isActive && req.type != 'Meeting') {
        // Create abbreviation from first letter or first two letters
        String abbr;
        if (req.type.isEmpty) {
          abbr = '?';
        } else if (req.type.length == 1) {
          abbr = req.type;
        } else {
          abbr = req.type.substring(0, 1);
        }
        
        final hours = _getHoursByType(user, req.type);
        text.write(', $abbr: ${hours.toStringAsFixed(1)}');
      }
    }
    
    return text.toString();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredAndSortedUsers();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        title: Text(
          'Members',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          // Show bulk edit button on all screen sizes
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BulkEditEventsPage()),
              );
            },
          ),
          // Show export button on all screen sizes
          IconButton(
            icon: _isExporting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                : Icon(
                    Icons.file_download,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            onPressed: _isExporting 
                ? null 
                : () {
                    setState(() => _isExporting = true);
                    exportToExcel(context, filteredUsers).then((_) {
                      setState(() => _isExporting = false);
                    });
                  },
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Side panel for filters on wide screens
                if (isWideScreen)
                  Container(
                    width: 260,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      border: border.Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search field
                          TextField(
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            decoration: InputDecoration(
                              labelText: 'Search',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Sort options
                          Text(
                            'Sort By',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSortOptionsList(),
                          
                          const SizedBox(height: 24),
                          
                          // Sort order
                          Text(
                            'Sort Order',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                           Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  _buildOrderChip(
                                SortOrder.ascending, '↑ Ascending', (setState) {}),
                              _buildOrderChip(
                                SortOrder.descending, '↓ Descending', (setState) {}),
                            ]
                              ),
                          
                          const SizedBox(height: 24),
                          
                          // Filter by hour type
                          Text(
                            'Filter by Hour Type',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _availableHourTypes.map((type) {
                              return FilterChip(
                                selected: _selectedHourType == type,
                                label: Text(type),
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedHourType = selected ? type : null;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          
                          const Spacer(),
                          
                          // Bulk add button at bottom of sidebar
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _openBulkCustomEventForm(context);
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Bulk Add Hours'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Main content area
                Expanded(
                  child: Column(
                    children: [
                      // Mobile top controls
                      if (!isWideScreen)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // Search field
                              TextField(
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  labelText: 'Search',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16.0),
                              
                              // Bulk add button
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        _openBulkCustomEventForm(context);
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('Bulk Add'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Filter button that shows bottom sheet
                                  OutlinedButton.icon(
                                    onPressed: _showFilterOptions,
                                    icon: const Icon(Icons.filter_list),
                                    label: const Text('Filter'),
                                  ),
                                ],
                              ),
                              
                              // Show selected filter if any
                              if (_selectedHourType != null && _selectedHourType != 'All')
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Filtered by: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      Chip(
                                        label: Text(_selectedHourType!),
                                        deleteIcon: const Icon(Icons.clear, size: 18),
                                        onDeleted: () {
                                          setState(() {
                                            _selectedHourType = null;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      
                      // User count info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Text(
                              '${filteredUsers.length} ${filteredUsers.length == 1 ? 'member' : 'members'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              Text(
                                ' matching "${_searchQuery}"',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // User list
                      Expanded(
                        child: filteredUsers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_search,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No members match your search'
                                          : 'No members to display',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _fetchUsers,
                                child: isWideScreen
                                    ? _buildUserTable(filteredUsers)  // Table view for wide screens
                                    : _buildUserCardList(filteredUsers)  // Card list for mobile
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUserTable(List<UserProfile> users) {
    // Enhanced table for wide screens with fixed header
    return Column(
      children: [
        // Table header
        Container(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // Name column (wider)
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (_sortField == SortField.name) {
                        _sortOrder = _sortOrder == SortOrder.ascending
                            ? SortOrder.descending
                            : SortOrder.ascending;
                      } else {
                        _sortField = SortField.name;
                        _sortOrder = SortOrder.ascending;
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        'Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _sortField == SortField.name
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      if (_sortField == SortField.name)
                        Icon(
                          _sortOrder == SortOrder.ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
              // Total hours column
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (_sortField == SortField.totalHours) {
                        _sortOrder = _sortOrder == SortOrder.ascending
                            ? SortOrder.descending
                            : SortOrder.ascending;
                      } else {
                        _sortField = SortField.totalHours;
                        _sortOrder = SortOrder.descending;
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        'Total Hours',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _sortField == SortField.totalHours
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      if (_sortField == SortField.totalHours)
                        Icon(
                          _sortOrder == SortOrder.ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
              // Dues paid column
              Expanded(
                child: Text(
                  'Dues Paid',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              // Actions column
              const SizedBox(
                width: 100,
                child: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        
        // Table body with scrolling
        Expanded(
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final totalHours = _getTotalHours(user);
    
    // Generate hour breakdown text
    final hoursText = _generateHoursBreakdownText(user);
    
    final isEvenRow = index % 2 == 0;
    
    return Container(
      color: isEvenRow 
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
      child: InkWell(
        onTap: () {
          _showUserDetailsDialog(user);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // Name column
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0] : '?',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Total hours column
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${totalHours.toStringAsFixed(1)} hrs',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      hoursText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
                        Expanded(
                          child: Center(
                            child: IconButton(
                              icon: Icon(
                                user.hasPaidDues ? Icons.check_circle : Icons.cancel,
                                color: user.hasPaidDues ? Colors.green : Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () => _toggleDuesStatus(user),
                            ),
                          ),
                        ),
                        // Actions column
                        SizedBox(
                          width: 100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add),
                                tooltip: 'Add Hours',
                                onPressed: () {
                                  _openCustomEventForm(context, user.id);
                                },
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_vert),
                                tooltip: 'More Options',
                                onPressed: () {
                                  _showUserActionsMenu(context, user);
                                },
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  

  Widget _buildUserCardList(List<UserProfile> users) {
    // Card-based list for mobile screens
    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserCard(user);
      },
    );
  }
  
  // Existing implementation
  Widget _buildUserCard(UserProfile user) {
    // Get society requirements from provider
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return const SizedBox();
    
    // Generate abbreviations for requirement types
    Map<String, String> typeAbbreviations = {};
    Set<String> usedFirstLetters = {};
    
    // Add Meeting first (special requirement)
    typeAbbreviations['Meeting'] = 'M';
    usedFirstLetters.add('M');
    
    // Add other requirements with adaptive abbreviations
    for (final req in society.hourRequirements) {
      if (req.isActive) {
        final type = req.type;
        final firstLetter = type.isEmpty ? 'X' : type[0].toUpperCase();
        
        if (!usedFirstLetters.contains(firstLetter)) {
          // If first letter isn't used yet, use it
          typeAbbreviations[type] = firstLetter;
          usedFirstLetters.add(firstLetter);
        } else {
          // If first letter is already used, use first two letters
          final secondLetter = type.length > 1 ? type[1].toLowerCase() : '';
          typeAbbreviations[type] = '$firstLetter$secondLetter';
        }
      }
    }
    
    // Calculate hours for each requirement type
    Map<String, double> hoursByType = {};
    double totalHours = 0;
    
    // Initialize with 0 for all requirement types
    typeAbbreviations.keys.forEach((type) {
      hoursByType[type] = 0;
    });
    
    // Sum hours by type
    for (final hour in user.completedHours) {
      final normalizedType = normalizeType(hour.type);
      if (hoursByType.containsKey(normalizedType)) {
        hoursByType[normalizedType] = (hoursByType[normalizedType] ?? 0) + hour.hours;
        totalHours += hour.hours;
      } else if (typeAbbreviations.keys.any((k) => normalizeType(k) == normalizedType)) {
        // Try to find a matching type with different capitalization
        final matchingType = typeAbbreviations.keys.firstWhere(
          (k) => normalizeType(k) == normalizedType,
          orElse: () => normalizedType,
        );
        hoursByType[matchingType] = (hoursByType[matchingType] ?? 0) + hour.hours;
        totalHours += hour.hours;
      }
    }
    
    // Build the hours display text
    final StringBuffer hoursText = StringBuffer();
    hoursText.write('${totalHours.toStringAsFixed(1)} hrs (');
    
    final List<String> hourParts = [];
    typeAbbreviations.forEach((type, abbr) {
      hourParts.add('$abbr: ${hoursByType[type]?.toStringAsFixed(1)}');
    });
    
    hoursText.write(hourParts.join(', '));
    hoursText.write(')');

    // Filter hours by selected type if needed
    final List<CompletedUserHour> filteredHours = _selectedHourType != null && _selectedHourType != 'All'
        ? user.completedHours.where((hour) => 
            normalizeType(hour.type) == normalizeType(_selectedHourType!)).toList()
        : user.completedHours;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CustomExpansionTile(
        title: ListTile(
          title: Text(
            user.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.0,
            ),
          ),
          subtitle: Text(
            hoursText.toString(),
            style: TextStyle(fontSize: 14),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onDoubleTap: () => _toggleDuesStatus(user),
                child: Icon(
                  user.hasPaidDues ? Icons.check_circle : Icons.cancel,
                  color: user.hasPaidDues ? Colors.green : Theme.of(context).colorScheme.error,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  _openCustomEventForm(context, user.id);
                },
              ),
            ],
          ),
        ),
        children: filteredHours.map((hour) {
          return ListTile(
            title: Text(
              hour.eventName,
              style: const TextStyle(
                fontSize: 16.0,
              ),
            ),
            subtitle: Text(
              '${hour.hours} hours - ${hour.type}',
              style: TextStyle(
                fontSize: 14.0,
                color: Colors.grey[600],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              color: Theme.of(context).colorScheme.onSurface,
              onPressed: () {
                _deleteServiceHour(hour, user.id);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // Update the sort options list to be dynamic
  Widget _buildSortOptionsList() {
    // Always include these basic sort options
    final List<Widget> options = [
      _buildSortOptionTile(SortField.name, 'Name'),
      _buildSortOptionTile(SortField.totalHours, 'Total Hours'),
    ];
    
    // Get society to determine which hour types to include
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society != null) {
      // If a specific type is selected, only show that one
      if (_selectedHourType != null && _selectedHourType != 'All') {
        options.add(_buildSortOptionTile(SortField.serviceHours, '$_selectedHourType Hours'));
      } else {
        // Otherwise show for each active requirement type
        // Always include Meeting hours
        options.add(_buildSortOptionTile(SortField.meetingHours, 'Meeting Hours'));
        
        // Add option for each active requirement type
        for (final req in society.hourRequirements) {
          if (req.isActive && req.type != 'Meeting') {
            options.add(_buildSortOptionTile(
              // We'll still use serviceHours or tutoringHours as the enum value,
              // but the display name will match the requirement type
              req.type.toLowerCase().contains('tutor') 
                  ? SortField.tutoringHours 
                  : SortField.serviceHours,
              '${req.type} Hours'
            ));
          }
        }
      }
    }
    
    return Column(children: options);
  }

  // Helper method for sort option tile
  Widget _buildSortOptionTile(SortField field, String label) {
    return RadioListTile<SortField>(
      title: Text(label),
      value: field,
      groupValue: _sortField,
      onChanged: (value) {
        setState(() {
          _sortField = value!;
        });
      },
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  // Helper to show more actions for a user
  void _showUserActionsMenu(BuildContext context, UserProfile user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${user.name} - Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add Hours'),
                onTap: () {
                  Navigator.pop(context);
                  _openCustomEventForm(context, user.id);
                },
              ),
              ListTile(
                leading: Icon(
                  user.hasPaidDues ? Icons.cancel : Icons.check_circle,
                  color: user.hasPaidDues ? Theme.of(context).colorScheme.error : Colors.green,
                ),
                title: Text(user.hasPaidDues ? 'Mark Dues Unpaid' : 'Mark Dues Paid'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleDuesStatus(user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.list),
                title: const Text('View All Hours'),
                onTap: () {
                  Navigator.pop(context);
                  _showUserDetailsDialog(user);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Show detailed user information
  void _showUserDetailsDialog(UserProfile user) {
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return;

    // Group hours by type
    final Map<String, List<CompletedUserHour>> hoursByType = {};
    
    // Initialize with empty lists for all society requirement types
    hoursByType['Meeting'] = [];

    for (final req in society.hourRequirements) {
      if (req.isActive) {
        hoursByType[req.type] = [];
      }
    }

    // Categorize hours
    for (final hour in user.completedHours) {
      final type = hour.type;
      if (hoursByType.containsKey(type)) {
        hoursByType[type]!.add(hour);
      } else {
        // Try to find a matching type with different capitalization
        final matchingType = hoursByType.keys.firstWhere(
          (k) => normalizeType(k) == normalizeType(type),
          orElse: () => 'Other',
        );
        
        if (!hoursByType.containsKey(matchingType)) {
          hoursByType[matchingType] = [];
        }
        hoursByType[matchingType]!.add(hour);
      }
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0] : '?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Dues Paid: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Icon(
                                  user.hasPaidDues ? Icons.check_circle : Icons.cancel,
                                  color: user.hasPaidDues ? Colors.green : Theme.of(context).colorScheme.error,
                                  size: 16,
                                ),
                                Text(
                                  user.hasPaidDues ? ' Yes' : ' No',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Hour summary
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child:_buildHourTypeCards(user),
                ),
                
                // Tab navigator for different hour types
                Expanded(
                  child: DefaultTabController(
                    length: hoursByType.length + 1, // All + each type
                    child: Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          tabs: [
                            const Tab(text: 'All'),
                            ...hoursByType.keys.map((type) => Tab(text: type)),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // All hours tab
                              _buildHoursList(user.completedHours),
                              // Type-specific tabs
                              ...hoursByType.values.map((hours) => _buildHoursList(hours)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Bottom actions
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openCustomEventForm(context, user.id);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Hours'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper to build hour summary card
  Widget _buildHourSummaryCard(String title, String hours, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              hours,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build hours list
  Widget _buildHoursList(List<CompletedUserHour> hours) {
    if (hours.isEmpty) {
      return Center(
        child: Text(
          'No hours recorded',
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
      );
    }
    
    // Sort hours by type (optional)
    hours.sort((a, b) => a.type.compareTo(b.type));
    
    return ListView.builder(
      itemCount: hours.length,
      itemBuilder: (context, index) {
        final hour = hours[index];
        return ListTile(
          title: Text(hour.eventName),
          subtitle: Text(hour.type),
          trailing: Text(
            '${hour.hours.toStringAsFixed(1)} hrs',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  // Helper to get icon for hour type
  // Helper to get icon for hour type - dynamic based on type name
  IconData _getIconForHourType(String type) {
    final normalizedType = type.toLowerCase();
    if (normalizedType.contains('service') || normalizedType.contains('volunteer')) 
      return Icons.volunteer_activism;
    if (normalizedType.contains('tutor') || normalizedType.contains('teach')) 
      return Icons.school;
    if (normalizedType.contains('meet')) 
      return Icons.groups;
    if (normalizedType.contains('lead') || normalizedType.contains('officer')) 
      return Icons.emoji_people;
    if (normalizedType.contains('fund') || normalizedType.contains('donat')) 
      return Icons.attach_money;
    
    // Default icon if no match
    return Icons.watch_later;
  }

  // Helper to get color for hour type
  Color _getColorForHourType(String type, BuildContext context) {
    // Use the society's categories to determine colors systematically
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return Theme.of(context).colorScheme.primary;
    
    final normalizedType = type.toLowerCase();
    
    // Meeting is special
    if (normalizedType.contains('meet')) 
      return Theme.of(context).colorScheme.tertiary;
    
    // Build color palette based on requirement index
    final List<Color> palette = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Colors.amber,
      Colors.teal,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
    ];
    
    // Find index of requirement
    int index = society.hourRequirements.indexWhere(
      (req) => normalizeType(req.type) == normalizeType(type)
    );
    
    // Default to primary if not found
    if (index == -1) return Theme.of(context).colorScheme.primary;
    
    // Return color from palette, wrapping around if needed
    return palette[index % palette.length];
  }
  
  // Existing method for order chip
  Widget _buildOrderChip(SortOrder order, String label, StateSetter setState) {
    return FilterChip(
      selected: _sortOrder == order,
      label: Text(label),
      onSelected: (selected) {
        if (selected) {
          this.setState(() => _sortOrder = order);
        }
      },
    );
  }

  // Existing method for filter options
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Filter by Hour Type',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _availableHourTypes.map((type) {
                        return FilterChip(
                          selected: _selectedHourType == type,
                          label: Text(type),
                          onSelected: (selected) {
                            setState(() => _selectedHourType = selected ? type : null);
                            this.setState(() {}); // Update main screen
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOrderChip(
                          SortOrder.ascending, '↑ Ascending', setState),
                      const SizedBox(width: 8),
                      _buildOrderChip(
                          SortOrder.descending, '↓ Descending', setState),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleDuesStatus(UserProfile user) async {
    try {
      final societyId = Provider.of<SocietyProvider>(context, listen: false)
          .currentSociety
          ?.id;
      if (societyId == null) return;

      // Update dues status in user_society_memberships table instead of profiles
      await supabase
          .from('user_society_memberships')
          .update({'has_paid_dues': !user.hasPaidDues})
          .eq('user_id', user.id)
          .eq('society_id', societyId);

      // Refresh the user list to reflect the change
      await _fetchUsers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.hasPaidDues
                  ? 'Dues marked as unpaid'
                  : 'Dues marked as paid',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating dues status: $e')),
      );
    }
  }

  Future<void> _saveCustomEvent(
    String userId,
    String eventName,
    String timeSlot,
    double hours,
    String type,
  ) async {
    try {
      final societyId = Provider.of<SocietyProvider>(context, listen: false)
          .currentSociety
          ?.id;
      if (societyId == null) return;

      await supabase.from('Service hours').insert({
        'user_id': userId,
        'event_name': eventName,
        'timeslot': timeSlot,
        'hours': hours.toDouble(),
        'type': type,
        'society_id': societyId,
      });

      await _logActivity(
        eventName,
        timeSlot,
        hours,
        'manual_addition',
        userId,
        societyId: societyId,
      );

      // Update local state
      setState(() {
        final userIndex = _users.indexWhere((u) => u.id == userId);
        if (userIndex != -1) {
          final newHour = CompletedUserHour(
            eventName: eventName,
            hours: hours,
            type: type,
          );

          final updatedHours =
              List<CompletedUserHour>.from(_users[userIndex].completedHours)
                ..add(newHour);

          _users[userIndex] = UserProfile(
            name: _users[userIndex].name,
            id: userId,
            completedHours: updatedHours,
            hasPaidDues: _users[userIndex].hasPaidDues,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service hours added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding service hours: $e')),
      );
    }

    _fetchUsers(); // Refresh the user list after saving the custom event
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: const Text(
                      'Sort By',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildSortChip(SortField.name, 'Name', setState),
                        _buildSortChip(
                            SortField.totalHours, 'Total Hours', setState),
                        _buildSortChip(
                            SortField.serviceHours, 'Service Hours', setState),
                        _buildSortChip(SortField.tutoringHours,
                            'Tutoring Hours', setState),
                        _buildSortChip(
                            SortField.meetingHours, 'Meeting Hours', setState),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOrderChip(
                          SortOrder.ascending, '↑ Ascending', setState),
                      const SizedBox(width: 8),
                      _buildOrderChip(
                          SortOrder.descending, '↓ Descending', setState),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortChip(SortField field, String label, StateSetter setState) {
    return FilterChip(
      selected: _sortField == field,
      label: Text(label),
      onSelected: (selected) {
        if (selected) {
          setState(() => _sortField = field);
          this.setState(() {});
        }
      },
    );
  }

  void _openCustomEventForm(BuildContext context, String userId,
      {String eventName = '',
      TimeOfDay? selectedTime,
      double hours = 0,
      String? type}) {
    // Get available event types from society
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    List<String> availableTypes = [
      'Service',
      'Tutoring',
      'Meeting'
    ]; // Default fallback

    if (society != null) {
      availableTypes = ['Meeting']; // Always include Meeting

      // Add all active requirement types
      for (final req in society.hourRequirements) {
        if (req.isActive && !availableTypes.contains(req.type)) {
          availableTypes.add(req.type);
        }
      }
    }

    // If type is not provided or not in available types, set default
    type ??= availableTypes.isNotEmpty ? availableTypes.first : 'Service';
    if (!availableTypes.contains(type)) {
      type = availableTypes.isNotEmpty ? availableTypes.first : 'Service';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Custom Event'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: eventName,
                  decoration: const InputDecoration(labelText: 'Event Name'),
                  onChanged: (value) {
                    eventName = value;
                  },
                ),
                Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: ElevatedButton(
                      child: Center(
                        child: Text(selectedTime != null
                            ? selectedTime.format(context)
                            : 'Select Time'),
                      ),
                      onPressed: () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          // Rebuild the dialog with the selected time and preserved form data
                          Navigator.of(context).pop();
                          _openCustomEventForm(context, userId,
                              eventName: eventName,
                              selectedTime: pickedTime,
                              hours: hours,
                              type: type);
                        }
                      },
                    )),
                TextFormField(
                  initialValue: hours.toString(),
                  decoration: const InputDecoration(labelText: 'Hours'),
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                  onChanged: (value) {
                    hours = double.tryParse(value) ?? 0.0;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: type,
                  onChanged: (value) {
                    setState(() {
                      type = value;
                    });
                  },
                  borderRadius: BorderRadius.circular(30),
                  dropdownColor: Theme.of(context).colorScheme.primaryContainer,
                  items: availableTypes
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Event Type',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select an event type';
                    }
                    return null;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                child: const Text('Save'),
                onPressed: () {
                  if (selectedTime != null && type != null) {
                    String timeSlot =
                        '${selectedTime.hour}:${selectedTime.minute}';
                    _saveCustomEvent(
                        userId,
                        eventName,
                        timeSlot,
                        hours.toDouble(),
                        type ?? "Meeting"); // Use selected type
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  /// Manually adds service hours for a specific user.
  /// Used by administrators to credit hours for external events.
  /// Used by administrators to add Penelty Hours.
  ///
  /// Parameters:
  /// - userId: String - Target user
  /// - eventName: String - Event name
  /// - timeSlot: String - Time slot description
  /// - hours: double - Hours to credit
  /// - type: String - Type of service
  ///
  /// Returns:
  /// - Future<void>
  /*  Future<void> _saveCustomEvent(
   String userId,
   String eventName,
  String timeSlot,
    double hours,
   String type,
  ) async {
   try {
     await Supabase.instance.client.from('Service hours').insert({
       'user_id': userId,
        'event_name': eventName,
     'timeslot': timeSlot,
      'hours': hours.toDouble(),
      'type': type,
    });

    await _logActivity(
      eventName,
     timeSlot,
      hours,
      'manual_addition',
      userId,
    );

    // Update local state
   setState(() {
      final userIndex = _users.indexWhere((u) => u.id == userId);
      if (userIndex != -1) {
        final newHour = CompletedUserHour(
          eventName: eventName,
          hours: hours,
          type: type,
        );

        final updatedHours =
          List<CompletedUserHour>.from(_users[userIndex].completedHours)
             ..add(newHour);

        _users[userIndex] = UserProfile(
           name: _users[userIndex].name,
         id: userId,
         completedHours: updatedHours,
       );
      }
    });

   ScaffoldMessenger.of(context).showSnackBar(
     const SnackBar(content: Text('Service hours added successfully')),
   );
  } catch (e) {
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(content: Text('Error adding service hours: $e')),
   );
 }

  _fetchUsers(); // Refresh the user list after saving the custom event
}
 */
  Future<void> _deleteServiceHour(CompletedUserHour hour, String userId) async {
    await _logActivity(
      hour.eventName,
      'N/A',
      hour.hours,
      'manual_deletion',
      userId,
    );

    await Supabase.instance.client
        .from('Service hours')
        .delete()
        .eq('event_name', hour.eventName)
        .eq('user_id', userId);

    _fetchUsers();
  }

  void _openBulkCustomEventForm(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkCustomEventFormPage(users: _users),
      ),
    );

    if (result == true) {
      // Refresh the user list if the bulk custom event was saved successfully
      _fetchUsers();
    }
  }
}

class AttendanceCheckPage extends StatefulWidget {
  final Event event;
  final TimeSlot timeSlot;

  const AttendanceCheckPage(
      {Key? key, required this.event, required this.timeSlot})
      : super(key: key);

  @override
  _AttendanceCheckPageState createState() => _AttendanceCheckPageState();
}

class _AttendanceCheckPageState extends State<AttendanceCheckPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Attendee> _allAttendees = [];
  List<Attendee> _presentAttendees = [];
  List<Attendee> _absentAttendees = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSaving = false;
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAttendees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  /// Retrieves all attendees for a specific time slot.
  /// Separates into present and absent lists.
  ///
  /// Returns:
  /// - Future<void>
  ///
  /// Throws:
  /// - DatabaseException if attendee fetch fails
  Future<void> _fetchAttendees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('Attendees')
          .select('*, profiles:user_id(name)')
          .eq('timeslot_id', widget.timeSlot.id ?? 0);

      _allAttendees = response
          .map<Attendee>((json) => Attendee.fromJson({
                ...json,
                'name': json['profiles']['name'],
              }))
          .toList();

      _presentAttendees =
          _allAttendees.where((attendee) => attendee.isPresent).toList();
      _absentAttendees =
          _allAttendees.where((attendee) => !attendee.isPresent).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching attendees: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Attendee> _getFilteredAttendees(List<Attendee> attendees) {
    if (_searchQuery.isEmpty) {
      return attendees;
    }
    final lowercaseQuery = _searchQuery.toLowerCase();
    return attendees.where((attendee) {
      return attendee.name.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Updates attendance records for multiple attendees.
  /// Handles hour crediting and activity logging.
  ///
  /// Returns:
  /// - Future<void>
  ///
  /// Throws:
  /// - DatabaseException if attendance update fails
  Future<void> _saveAttendance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<Attendee> attendeesToUpdate = _tabController.index == 0
          ? _absentAttendees.where((a) => a.isPresent).toList()
          : _presentAttendees.where((a) => !a.isPresent).toList();

      for (var attendee in attendeesToUpdate) {
        // Check if the attendee already has service hours for this event
        final existingHours = await Supabase.instance.client
            .from('Service hours')
            .select()
            .eq('user_id', attendee.userId)
            .eq('timeslot_id', widget.timeSlot.id ?? 0)
            .maybeSingle();

        if (existingHours == null && attendee.isPresent) {
          // Add service hours
          await Supabase.instance.client.from('Service hours').insert({
            'user_id': attendee.userId,
            'event_name': widget.event.name,
            'timeslot_id': widget.timeSlot.id,
            'hours': _calculateHours(widget.timeSlot),
            'date': widget.event.date.toIso8601String(),
            'type': widget.event.type,
          });

          await _logActivity(
            widget.event.name,
            '${widget.timeSlot.time.format(context)} - ${widget.timeSlot.endTime.format(context)}',
            _calculateHours(widget.timeSlot),
            'attendance_marked',
            attendee.userId,
          );
        } else if (existingHours != null && !attendee.isPresent) {
          // Remove service hours
          await Supabase.instance.client
              .from('Service hours')
              .delete()
              .eq('user_id', attendee.userId)
              .eq('timeslot_id', widget.timeSlot.id ?? 0);

          await _logActivity(
            widget.event.name,
            '${widget.timeSlot.time.format(context)} - ${widget.timeSlot.endTime.format(context)}',
            _calculateHours(widget.timeSlot),
            'attendance_removed',
            attendee.userId,
          );
        }

        // Update attendance status
        await Supabase.instance.client
            .from('Attendees')
            .update({'is_present': attendee.isPresent}).eq('id', attendee.id);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved successfully')),
      );

      // Refresh the attendees list
      await _fetchAttendees();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving attendance: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _searchQuery = '';
      });
    }
  }

  /// Calculates duration in hours between start and end times.
  ///
  /// Parameters:
  /// - timeSlot: TimeSlot - Time slot to calculate duration for
  ///
  /// Returns:
  /// - double: Duration in hours
  double _calculateHours(TimeSlot timeSlot) {
    final start = timeSlot.time;
    final end = timeSlot.endTime;
    final difference =
        end.hour * 60 + end.minute - (start.hour * 60 + start.minute);
    return difference / 60.0;
  }

  /// Initiates QR code scanning for attendance marking.
  /// Handles successful scans and user verification.
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _scanBarcode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerPage(attendees: _allAttendees),
      ),
    );

    if (result != null) {
      final attendeeIndex =
          _allAttendees.indexWhere((attendee) => attendee.userId == result);
      if (attendeeIndex != -1) {
        setState(() {
          _allAttendees[attendeeIndex].isPresent = true;
          _presentAttendees.add(_allAttendees[attendeeIndex]);
          _absentAttendees.removeWhere((attendee) => attendee.userId == result);
        });
        _showToastNotification(
            'Scanned in: ${_allAttendees[attendeeIndex].name}');
      }
    }
  }

  /// Displays a toast notification to the user.
  ///
  /// Parameters:
  /// - message: String - Message to display
  ///
  /// Returns:
  /// - void
  void _showToastNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSwapDialog(Attendee currentAttendee) {
    List<UserProfile> allUsers = [];
    List<UserProfile> filteredUsers = [];
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Swap Attendee'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) {
                      setDialogState(() {
                        searchQuery = value;
                        filteredUsers = allUsers
                            .where((user) => user.name
                                .toLowerCase()
                                .contains(searchQuery.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<UserProfile>>(
                    future: _fetchAllUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          allUsers.isEmpty) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else {
                        if (snapshot.hasData && allUsers.isEmpty) {
                          allUsers = snapshot.data!;
                          filteredUsers = allUsers;
                        }
                        return SizedBox(
                          height: 300,
                          width: 300,
                          child: ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return ListTile(
                                title: Text(user.name),
                                subtitle: Text(user.id == currentAttendee.userId
                                    ? 'Current Attendee'
                                    : ''),
                                onTap: () {
                                  if (user.id != currentAttendee.userId) {
                                    _swapAttendee(currentAttendee, user);
                                    Navigator.of(context).pop();
                                  }
                                },
                              );
                            },
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<UserProfile>> _fetchAllUsers() async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('user_id, name')
        .order('name');

    return (response as List)
        .map((user) => UserProfile(
              id: user['user_id'],
              name: user['name'],
              completedHours: [], // You might want to fetch this information separately if needed
            ))
        .toList();
  }

  Future<void> _swapAttendee(
      Attendee currentAttendee, UserProfile newUser) async {
    try {
      // Remove the current attendee
      await Supabase.instance.client
          .from('Attendees')
          .delete()
          .eq('id', currentAttendee.id);

      // Add the new attendee
      final response = await Supabase.instance.client
          .from('Attendees')
          .insert({
            'timeslot_id': currentAttendee.timeSlotId,
            'user_id': newUser.id,
            'is_present': false,
            'forms_completed': false,
          })
          .select()
          .single();

      // Create a new Attendee object with the response data
      final newAttendee = Attendee(
        id: response['id'],
        timeSlotId: response['timeslot_id'],
        userId: response['user_id'],
        name: newUser.name,
        isPresent: response['is_present'],
        formsCompleted: response['forms_completed'],
      );

      // Update the UI
      setState(() {
        final timeSlotIndex = widget.event.timeSlots
            .indexWhere((ts) => ts.id == currentAttendee.timeSlotId);
        if (timeSlotIndex != -1) {
          final attendeeIndex = widget.event.timeSlots[timeSlotIndex].attendees
              .indexWhere((a) => a.id == currentAttendee.id);
          if (attendeeIndex != -1) {
            widget.event.timeSlots[timeSlotIndex].attendees[attendeeIndex] =
                newAttendee;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendee swapped successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error swapping attendee: $e')),
      );
    }
    refreshAttendeeList();
  }

  void refreshAttendeeList() {
    setState(() {
      _allAttendees = widget.event.timeSlots
          .expand((timeSlot) => timeSlot.attendees)
          .toList();
      _presentAttendees =
          _allAttendees.where((attendee) => attendee.isPresent).toList();
      _absentAttendees =
          _allAttendees.where((attendee) => !attendee.isPresent).toList();
    });
  }

  @override
  void didUpdateWidget(AttendanceCheckPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event != widget.event) {
      refreshAttendeeList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        title: Text(
          'Attendance: ${widget.event.name}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mark Present'),
            Tab(text: 'Mark Absent'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search Attendees',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAttendeeList(
                          _getFilteredAttendees(_absentAttendees), true),
                      _buildAttendeeList(
                          _getFilteredAttendees(_presentAttendees), false),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : _saveAttendance,
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.save),
      ),
    );
  }

  /// Creates a list view of attendees with attendance marking controls.
  ///
  /// Parameters:
  /// - attendees: List<Attendee> - Attendees to display
  /// - markPresent: bool - Whether list is for marking presence
  ///
  /// Returns:
  /// - Widget
  Widget _buildAttendeeList(List<Attendee> attendees, bool markPresent) {
    return ListView.builder(
      itemCount: attendees.length,
      itemBuilder: (context, index) {
        final attendee = attendees[index];
        return CheckboxListTile(
          title: Text(attendee.name),
          value: markPresent ? attendee.isPresent : !attendee.isPresent,
          onChanged: (bool? value) {
            setState(() {
              attendee.isPresent = markPresent ? value! : !value!;
            });
          },
          secondary: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => _showSwapDialog(attendee),
              ),
              if (widget.event.requiresForms)
                IconButton(
                  icon: Icon(attendee.formsCompleted
                      ? Icons.inventory
                      : Icons.pending_actions),
                  onPressed: () {
                    _toggleFormCompletionStatus(attendee);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _toggleFormCompletionStatus(Attendee attendee) async {
    try {
      await Supabase.instance.client.from('Attendees').update(
          {'forms_completed': !attendee.formsCompleted}).eq('id', attendee.id);

      setState(() {
        attendee.formsCompleted = !attendee.formsCompleted;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Form status updated for ${attendee.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating form status: $e')),
      );
    }
  }
}

Future<void> addAttendeeToEvent(
    Event event, TimeSlot timeSlot, String userId) async {
  await Supabase.instance.client.from('Attendees').insert({
    'timeslot_id': timeSlot?.id ?? 0,
    'user_id': userId,
    'is_present': false,
  });
}

Future<void> updateAttendanceStatus(Attendee attendee) async {
  await Supabase.instance.client
      .from('Attendees')
      .update({'is_present': attendee.isPresent}).eq('id', attendee.id);
}

class BulkCustomEventFormPage extends StatefulWidget {
  final List<UserProfile> users;

  const BulkCustomEventFormPage({super.key, required this.users});

  @override
  _BulkCustomEventFormPageState createState() =>
      _BulkCustomEventFormPageState();
}

class _BulkCustomEventFormPageState extends State<BulkCustomEventFormPage> {
  String eventName = '';
  TimeOfDay? selectedTime;
  double hours = 0;
  String type = 'Service';
  List<String> selectedUserIds = [];
  String searchQuery = '';
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Get available requirement types from society
  List<String> get _availableTypes {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null)
      return ['Service', 'Tutoring', 'Meeting']; // Default fallback

    final types = ['Meeting']; // Always include Meeting

    // Add all active requirements from the society
    for (final req in society.hourRequirements) {
      if (req.isActive && !types.contains(req.type)) {
        types.add(req.type);
      }
    }

    if (types.length == 1) {
      types.add('Service');
    }

    return types;
  }

  List<UserProfile> get filteredUsers {
    return widget.users.where((user) {
      final lowercaseName = user.name.toLowerCase();
      final lowercaseQuery = searchQuery.toLowerCase();
      return lowercaseQuery.isEmpty || lowercaseName.contains(lowercaseQuery);
    }).toList();
  }

  void _validateAndSave() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct the errors in the form')),
      );
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time')),
      );
      return;
    }

    if (selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one user')),
      );
      return;
    }

    _saveBulkCustomEvent();
  }

  Future<void> _saveBulkCustomEvent() async {
    setState(() => _isLoading = true);

    try {
      // Get society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        throw Exception('No society selected');
      }

      final timeSlot = '${selectedTime!.hour}:${selectedTime!.minute}';

      final List<Map<String, dynamic>> bulkEvents =
          selectedUserIds.map((userId) {
        return {
          'user_id': userId,
          'event_name': eventName,
          'timeslot': timeSlot,
          'hours': hours.toDouble(),
          'type': type,
          'society_id': society.id, // Important: Include society ID
          'date': DateTime.now()
              .toIso8601String(), // Include date for better tracking
        };
      }).toList();

      // Insert all records in a single operation
      await supabase.from('Service hours').insert(bulkEvents);

      // Log activity for each user
      for (final userId in selectedUserIds) {
        await _logActivity(
          eventName,
          timeSlot,
          hours,
          'manual_addition',
          userId,
          societyId: society.id,
        );
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${hours.toStringAsFixed(1)} hours for ${selectedUserIds.length} users',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Return success
      Navigator.of(context).pop(true);
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving bulk events: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = _availableTypes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Bulk Custom Event'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Event Details Card
            Card(
              elevation: 0,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event_note,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Event Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Event Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an event name';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          eventName = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Event Type Dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: type,
                            onChanged: (value) {
                              setState(() {
                                type = value ?? "Meeting";
                              });
                            },
                            items: types
                                .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ))
                                .toList(),
                            decoration: const InputDecoration(
                              labelText: 'Event Type',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select an event type';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Time Selector
                        Expanded(
                          flex: 1,
                          child: InkWell(
                            onTap: () async {
                              final TimeOfDay? pickedTime =
                                  await showTimePicker(
                                context: context,
                                initialTime: selectedTime ?? TimeOfDay.now(),
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  selectedTime = pickedTime;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Time',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.access_time),
                                suffixIcon: selectedTime != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          setState(() {
                                            selectedTime = null;
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              child: Text(
                                selectedTime != null
                                    ? selectedTime!.format(context)
                                    : 'Select',
                                style: selectedTime == null
                                    ? TextStyle(
                                        color: Theme.of(context).hintColor)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Hours Input
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Hours',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.timer),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: false, decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final hours = double.tryParse(value);
                              if (hours == null || hours <= 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                hours = double.tryParse(value) ?? 0.0;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Selection Header with Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Search Members',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Selection stats chip
                  Chip(
                    label: Text(
                      '${selectedUserIds.length} selected',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    avatar: Icon(
                      Icons.people,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            // Select All Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Checkbox(
                    value: selectedUserIds.length == filteredUsers.length &&
                        filteredUsers.isNotEmpty,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value ?? false) {
                          selectedUserIds =
                              filteredUsers.map((user) => user.id).toList();
                        } else {
                          selectedUserIds.clear();
                        }
                      });
                    },
                  ),
                  const Text('Select All'),
                  const Spacer(),
                  // Action buttons to select or clear all based on search results
                  if (searchQuery.isNotEmpty) ...[
                    TextButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Select Filtered'),
                      onPressed: () {
                        setState(() {
                          for (final user in filteredUsers) {
                            if (!selectedUserIds.contains(user.id)) {
                              selectedUserIds.add(user.id);
                            }
                          }
                        });
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Clear Filtered'),
                      onPressed: () {
                        setState(() {
                          selectedUserIds.removeWhere((id) =>
                              filteredUsers.any((user) => user.id == id));
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Users List
            Expanded(
              child: filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users match your search',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    )
                  : Scrollbar(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final isSelected = selectedUserIds.contains(user.id);

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.7)
                                : Theme.of(context).colorScheme.surface,
                            child: CheckboxListTile(
                              title: Text(
                                user.name,
                                style: TextStyle(
                                  fontWeight:
                                      isSelected ? FontWeight.bold : null,
                                ),
                              ),
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value ?? false) {
                                    selectedUserIds.add(user.id);
                                  } else {
                                    selectedUserIds.remove(user.id);
                                  }
                                });
                              },
                              dense: true,
                              secondary: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: CircleAvatar(
                                  child: Text(user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?'),
                                  backgroundColor: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  foregroundColor: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _validateAndSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BulkEditEventsPage extends StatefulWidget {
  const BulkEditEventsPage({super.key});

  @override
  _BulkEditEventsPageState createState() => _BulkEditEventsPageState();
}

class _BulkEditEventsPageState extends State<BulkEditEventsPage> {
  final _formKey = GlobalKey<FormState>();
  List<CustomEventGroup> _eventGroups = [];
  Set<String> _selectedEvents = {};
  String _searchQuery = '';
  bool _isLoading = true;

  String _newEventName = '';
  String _newStartTime = '';
  double _newHours = 0;
  String _newType = 'Service';

  @override
  void initState() {
    super.initState();
    _fetchCustomEvents();
  }

  Future<void> _fetchCustomEvents() async {
    setState(() => _isLoading = true);

    try {
      // Get current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get all events for this society with related profile info in a single query
      final response = await supabase.from('Service hours').select('''
            *,
            profiles:user_id(name)
          ''').eq('society_id', society.id).order('event_name');

      // Process and group the events
      final Map<String, Map<String, dynamic>> groupedEvents = {};

      for (final record in response) {
        final eventName = record['event_name'] as String;
        if (!groupedEvents.containsKey(eventName)) {
          groupedEvents[eventName] = {
            'users': <AffectedUser>[],
            'type': record['type'],
            'hours': record['hours'],
            'timeSlot': record['timeslot'] ?? '',
          };
        }

        groupedEvents[eventName]!['users']!.add(
          AffectedUser(
            id: record['user_id'],
            name: record['profiles']['name'],
          ),
        );
      }

      // Convert to CustomEventGroup objects
      final List<CustomEventGroup> eventGroups =
          groupedEvents.entries.map((entry) {
        final eventData = entry.value;
        return CustomEventGroup(
          eventName: entry.key,
          userCount: (eventData['users'] as List).length,
          type: eventData['type'] as String,
          hours: (eventData['hours'] as num).toDouble(),
          timeSlot: eventData['timeSlot'] as String,
          affectedUsers: (eventData['users'] as List<AffectedUser>).toList(),
        );
      }).toList();

      // Sort event groups by name
      eventGroups.sort((a, b) => a.eventName.compareTo(b.eventName));

      setState(() {
        _eventGroups = eventGroups;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching custom events: $e');
      setState(() => _isLoading = false);
    }
  }

  List<CustomEventGroup> get _filteredEventGroups {
    if (_searchQuery.isEmpty) return _eventGroups;

    final query = _searchQuery.toLowerCase();
    return _eventGroups
        .where((group) =>
            group.eventName.toLowerCase().contains(query) ||
            group.type.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _updateSelectedEvents() async {
    if (_selectedEvents.isEmpty) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Get the current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No society selected')),
        );
        return;
      }

      // Format time for database
      String? formattedTime;
      if (_newStartTime.isNotEmpty) {
        // Format time as HH:MM:00 for Supabase time column
        formattedTime = '$_newStartTime:00';
      }

      // For each selected event, update all associated records
      for (var eventName in _selectedEvents) {
        final group = _eventGroups.firstWhere((g) => g.eventName == eventName);

        // Build update data
        final updateData = <String, dynamic>{};

        if (_newEventName.isNotEmpty) {
          updateData['event_name'] = _newEventName;
        }
        if (formattedTime != null) {
          updateData['timeslot'] = formattedTime;
        }
        if (_newHours > 0) {
          updateData['hours'] = _newHours;
        }

        updateData['type'] = _newType;

        // Update all records for this event in this society
        await supabase
            .from('Service hours')
            .update(updateData)
            .eq('event_name', eventName)
            .eq('society_id',
                society.id); // Important: Scope to current society
      }

      // Hide loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully updated ${_selectedEvents.length} events',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Log the bulk update activity
      final timeSlotDisplay =
          _newStartTime.isNotEmpty ? _newStartTime : 'Various Times';
      final userId = supabase.auth.currentUser?.id;

      if (userId != null && society != null) {
        await _logActivity(
          _newEventName.isEmpty ? 'Multiple Events' : _newEventName,
          timeSlotDisplay,
          _newHours == 0 ? 0 : _newHours,
          'bulk_update',
          userId,
          societyId: society.id,
        );
      }

      // Clear selection and refresh the events list
      setState(() {
        _selectedEvents.clear();
      });
      await _fetchCustomEvents();
    } catch (e) {
      // Hide loading indicator if still showing
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating events: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedEvents() async {
    if (_selectedEvents.isEmpty) return;

    try {
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No society selected')),
        );
        return;
      }

      // Delete all selected events in a single query, scoped to current society
      await supabase
          .from('Service hours')
          .delete()
          .inFilter('event_name', _selectedEvents.toList())
          .eq('society_id', society.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Events deleted successfully')),
      );

      _selectedEvents.clear();
      await _fetchCustomEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting events: $e')),
      );
    }
  }

  void _showUpdateDialog() {
    TimeOfDay? selectedTime;
    String tempEventName = '';
    String tempHours = '';
    String tempType = _newType;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update Selected Events'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'New Event Name (Optional)',
                      hintText: 'Leave blank to keep current names',
                    ),
                    onChanged: (value) => tempEventName = value,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      selectedTime == null
                          ? 'Select Time'
                          : selectedTime!.format(context),
                    ),
                    onPressed: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() => selectedTime = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'New Hours (Optional)',
                      hintText: 'Leave blank to keep current hours',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null; // Optional field
                      }
                      final number = double.tryParse(value);
                      if (number == null) {
                        return 'Please enter a valid number';
                      }
                      if (number <= 0) {
                        return 'Hours must be greater than 0';
                      }
                      return null;
                    },
                    onChanged: (value) => tempHours = value,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: tempType,
                    items: ['Service', 'Tutoring', 'Meeting']
                        .map((type) =>
                            DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) => setState(() => tempType = value!),
                    decoration: const InputDecoration(labelText: 'Event Type'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();

                  // Update values
                  _newEventName = tempEventName;
                  _newStartTime =
                      '${selectedTime!.hour}:${selectedTime!.minute}';
                  _newHours = double.tryParse(tempHours) ?? 0;
                  _newType = tempType;

                  Navigator.pop(context);
                  _updateSelectedEvents();
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Edit Custom Events'),
        actions: [
          if (_selectedEvents.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showUpdateDialog,
              tooltip: 'Edit Selected',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Selected Events'),
                    content: Text(
                      'Are you sure you want to delete ${_selectedEvents.length} events? This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteSelectedEvents();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Delete Selected',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      labelText: 'Search Events',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                // Selection Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectedEvents.length ==
                                _filteredEventGroups.length &&
                            _filteredEventGroups.isNotEmpty,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value ?? false) {
                              _selectedEvents = _filteredEventGroups
                                  .map((g) => g.eventName)
                                  .toSet();
                            } else {
                              _selectedEvents.clear();
                            }
                          });
                        },
                      ),
                      Text(
                        'Select All (${_selectedEvents.length}/${_filteredEventGroups.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                // Events List
                Expanded(
                  child: _filteredEventGroups.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No custom events found'
                                : 'No events match your search',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredEventGroups.length,
                          itemBuilder: (context, index) {
                            final group = _filteredEventGroups[index];
                            return _buildEventGroupTile(group);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEventGroupTile(CustomEventGroup group) {
    final isSelected = _selectedEvents.contains(group.eventName);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Checkbox(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value!) {
                  _selectedEvents.add(group.eventName);
                } else {
                  _selectedEvents.remove(group.eventName);
                }
              });
            },
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.eventName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.userCount} ${group.userCount == 1 ? 'user' : 'users'} • ${group.type} • ${group.hours} hours',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  group.userCount.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time Slot:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(group.timeSlot),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Affected Users:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: group.affectedUsers.map((user) {
                      return Chip(
                        label: Text(user.name),
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceVariant,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomEventGroup {
  final String eventName;
  final int userCount;
  final String type;
  final double hours;
  final String timeSlot;
  final List<AffectedUser> affectedUsers;

  CustomEventGroup({
    required this.eventName,
    required this.userCount,
    required this.type,
    required this.hours,
    required this.timeSlot,
    required this.affectedUsers,
  });
}

class AffectedUser {
  final String id;
  final String name;

  AffectedUser({
    required this.id,
    required this.name,
  });
}

class HonorSociety {
  final int id;
  final String name;
  final String description;
  final String? imageUrl;
  final List<HourRequirement> hourRequirements;
  final int meetingRequirement; // Keep meetings as special case
  final DateTime createdAt;

  HonorSociety({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.hourRequirements,
    required this.meetingRequirement,
    required this.createdAt,
  });

  factory HonorSociety.fromJson(Map<String, dynamic> json) {
    return HonorSociety(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['image_url'],
      hourRequirements: (json['hour_requirements'] as List)
          .map((req) => HourRequirement.fromJson(req))
          .toList(),
      meetingRequirement: json['meeting_requirement'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class HourRequirement {
  final int id;
  final String type;
  final double hoursNeeded;
  final String description;
  final bool isActive;
  final String iconName;

  HourRequirement({
    required this.id,
    required this.type,
    required this.hoursNeeded,
    required this.description,
    this.isActive = true,
    this.iconName = 'workspaces',
  });

  factory HourRequirement.fromJson(Map<String, dynamic> json) {
    return HourRequirement(
      id: json['id'],
      type: json['type'],
      hoursNeeded: json['hours_needed'].toDouble(),
      description: json['description'],
      isActive: json['is_active'] ?? true,
      iconName: json['icon_name'] ?? 'workspaces',
    );
  }
}

const Map<String, IconData> _kAppIcons = {
  // Original Icons
  'work': Icons.work_outline,
  'service': Icons.volunteer_activism_outlined,
  'tutoring': Icons.school_outlined,
  'leadership': Icons.group_outlined,
  'event': Icons.event_outlined,
  'meeting': Icons.groups_outlined,
  'fundraising': Icons.monetization_on_outlined,
  'sports': Icons.sports_soccer_outlined,
  'art': Icons.palette_outlined,
  'music': Icons.music_note_outlined,

  // Added Icons
  'science': Icons.science_outlined,
  'tech': Icons.computer_outlined,
  'environment': Icons.eco_outlined,
  'health': Icons.local_hospital_outlined,
  'community': Icons.people_alt_outlined,
  'culture': Icons.museum_outlined,
  'writing': Icons.edit_note_outlined,
  'reading': Icons.menu_book_outlined,
  'debate': Icons.record_voice_over_outlined,
  'chess': Icons.grid_view_outlined, // Using grid icon as placeholder
  'robotics': Icons.precision_manufacturing_outlined,
  'gardening': Icons.yard_outlined,
  'cooking': Icons.soup_kitchen_outlined,
  'construction': Icons.construction_outlined,
  'photography': Icons.camera_alt_outlined,
  'film': Icons.movie_outlined,
  'volunteer': Icons.volunteer_activism, // Filled version for emphasis
  'charity': Icons.favorite_border_outlined,
  'mentoring': Icons.supervisor_account_outlined,
  'research': Icons.biotech_outlined,
  'travel': Icons.explore_outlined,
  'language': Icons.translate_outlined,
  'code': Icons.code_outlined,
  'design': Icons.design_services_outlined,
  'agriculture': Icons.agriculture_outlined,
  'workspaces': Icons.workspaces,

  // Default/Fallback
  'default': Icons.help_outline,
};

// Helper function to get IconData from name, with a fallback
IconData getIconDataByName(String? name) {
  return _kAppIcons[name] ?? _kAppIcons['default']!;
}

class IconSelector extends StatefulWidget {
  final String initialValue; // The initial icon name (e.g., 'service')
  final ValueChanged<String> onChanged; // Callback when icon changes

  const IconSelector({
    Key? key,
    required this.initialValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  _IconSelectorState createState() => _IconSelectorState();
}

class _IconSelectorState extends State<IconSelector> {
  late String _selectedIconName;

  @override
  void initState() {
    super.initState();
    _selectedIconName = widget.initialValue;
    // Ensure the initial value exists in our map, otherwise use default
    if (!_kAppIcons.containsKey(_selectedIconName)) {
      _selectedIconName = 'default';
    }
  }

  // Function to show the icon selection bottom sheet
  void _showIconSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder( // Optional: nice rounded corners
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        // Use a GridView to display icons
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _kAppIcons.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, // Adjust column count as needed
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final iconName = _kAppIcons.keys.elementAt(index);
            final iconData = _kAppIcons.values.elementAt(index);
            final isSelected = iconName == _selectedIconName;

            return InkWell(
              onTap: () {
                // Update state and call callback
                setState(() {
                  _selectedIconName = iconName;
                });
                widget.onChanged(_selectedIconName);
                Navigator.pop(sheetContext); // Close the bottom sheet
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).primaryColorLight.withOpacity(0.3) : Colors.transparent,
                  border: border.Border.all(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Tooltip(
                  message: iconName, // Show name on hover/long press
                  child: Icon(
                    iconData,
                    size: 30,
                    color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).iconTheme.color,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Display the currently selected icon and a button to change it
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Icon',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: InkWell(
         // Use InkWell for tap feedback
        onTap: () => _showIconSelectionSheet(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(getIconDataByName(_selectedIconName)),
                const SizedBox(width: 12),
                Text(_selectedIconName),
              ],
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey), // Indicator
          ],
        ),
      ),
    );
  }
}

class UserSocietyMembership {
  final String userId;
  final int societyId;
  final bool isAdmin;
  final DateTime joinedAt;

  UserSocietyMembership({
    required this.userId,
    required this.societyId,
    required this.isAdmin,
    required this.joinedAt,
  });

  factory UserSocietyMembership.fromJson(Map<String, dynamic> json) {
    return UserSocietyMembership(
      userId: json['user_id'],
      societyId: json['society_id'],
      isAdmin: json['is_admin'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
}

class AdminTotalHoursPage extends StatefulWidget {
  const AdminTotalHoursPage({super.key});

  @override
  _AdminTotalHoursPageState createState() => _AdminTotalHoursPageState();
}

class _AdminTotalHoursPageState extends State<AdminTotalHoursPage> {
  double _totalHours = 0;
  double _totalServiceHours = 0;
  double _totalTutoringHours = 0;
  double _totalMeetingHours = 0;
  String _notesTitle = '';
  String _notesText = '';
  List<MeetingNote> _meetingNotes = [];

  @override
  void initState() {
    super.initState();
    _fetchTotalHours();
    _fetchMeetingNotes();
  }

  void _showAddNotesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Meeting Notes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
                onChanged: (value) {
                  setState(() {
                    _notesTitle = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Notes',
                ),
                maxLines: 10,
                onChanged: (value) {
                  setState(() {
                    _notesText = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                _saveNotes();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showMeetingNotesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Meeting Notes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _meetingNotes.map((note) {
                return ListTile(
                  title: Text(note.title),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showEditNotesDialog(note);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditNotesDialog(MeetingNote note) {
    String updatedTitle = note.title;
    String updatedText = note.text;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Meeting Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
                controller: TextEditingController(text: note.title),
                onChanged: (value) {
                  updatedTitle = value;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Notes',
                ),
                maxLines: 10,
                controller: TextEditingController(text: note.text),
                onChanged: (value) {
                  updatedText = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                _updateNotes(note.id, updatedTitle, updatedText);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _updateNotes(int noteId, String title, String text) async {
    await Supabase.instance.client.from('Notes').update({
      'title': title,
      'text': text,
    }).eq('id', noteId);

    _fetchMeetingNotes();
  }

  Future<void> _fetchMeetingNotes() async {
    final response = await Supabase.instance.client
        .from('Notes')
        .select('*')
        .order('created_at', ascending: false);

    final List<dynamic> data = response;
    if (mounted) {
      setState(() {
        _meetingNotes = data.map((json) => MeetingNote.fromJson(json)).toList();
      });
    }
  }

  /// Creates new meeting notes in the database.
  ///
  /// Returns:
  /// - Future<void>
  void _saveNotes() async {
    await Supabase.instance.client.from('Notes').insert({
      'title': _notesTitle,
      'text': _notesText,
      'created_at': DateTime.now().toIso8601String(),
    });

    _notesTitle = '';
    _notesText = '';

    _fetchMeetingNotes();
  }

  Future<void> _fetchTotalHours() async {
    final response = await Supabase.instance.client
        .from('Service hours')
        .select('hours, type');

    final data = response as List<dynamic>;
    double serviceHours = 0;
    double tutoringHours = 0;
    double meetingHours = 0;

    for (final entry in data) {
      final hours = entry['hours'];
      final eventType = entry['type'] as String?;

      if (eventType == 'Service') {
        serviceHours += hours;
      } else if (eventType == 'Tutoring') {
        tutoringHours += hours;
      } else if (eventType == 'Meeting') {
        meetingHours += hours;
      }
    }

    if (mounted) {
      setState(() {
        _totalServiceHours = serviceHours;
        _totalTutoringHours = tutoringHours;
        _totalMeetingHours = meetingHours;
        _totalHours = serviceHours + tutoringHours + meetingHours;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        elevation: 15,
        shadowColor: Theme.of(context).colorScheme.shadow,
        title: Text(
          'Total NHS Hours',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Main content area
            Padding(
              padding: EdgeInsets.all(isWideScreen ? 24.0 : 16.0),
              child: isWideScreen ? _buildWideLayout() : _buildCompactLayout(),
            ),

            // Quick Actions Panel
          ],
        ),
      ),
      bottomNavigationBar: _buildQuickActionsPanel(isWideScreen),
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      children: [
        // Total Hours Card
        _buildTotalHoursCard(isCompact: true),
        const SizedBox(height: 16),
        // Categories Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryCard(
                'Service',
                _totalServiceHours,
                Icons.volunteer_activism,
                Theme.of(context).colorScheme.primary,
                isCompact: true,
              ),
              const SizedBox(width: 12),
              _buildCategoryCard(
                'Tutoring',
                _totalTutoringHours,
                Icons.school,
                Theme.of(context).colorScheme.secondary,
                isCompact: true,
              ),
              const SizedBox(width: 12),
              _buildCategoryCard(
                'Meeting',
                _totalMeetingHours,
                Icons.groups,
                Theme.of(context).colorScheme.tertiary,
                isCompact: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildTotalHoursCard(isCompact: false),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  'Service',
                  _totalServiceHours,
                  Icons.volunteer_activism,
                  Theme.of(context).colorScheme.primary,
                  isCompact: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCategoryCard(
                  'Tutoring',
                  _totalTutoringHours,
                  Icons.school,
                  Theme.of(context).colorScheme.secondary,
                  isCompact: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCategoryCard(
                  'Meeting',
                  _totalMeetingHours,
                  Icons.groups,
                  Theme.of(context).colorScheme.tertiary,
                  isCompact: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalHoursCard({required bool isCompact}) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Total Hours',
            style: TextStyle(
              fontSize: isCompact ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: isCompact ? 140 : 180,
            height: isCompact ? 140 : 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: _totalHours / 2000,
                  strokeWidth: isCompact ? 12 : 16,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _totalHours.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: isCompact ? 28 : 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Hours',
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 16,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
      String title, double hours, IconData icon, Color color,
      {required bool isCompact}) {
    return Container(
      width: isCompact ? 120 : null,
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: border.Border.all(
          color: color.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isCompact ? 24 : 32),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isCompact ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: isCompact ? 2 : 4),
          Text(
            '${hours.toStringAsFixed(1)}h',
            style: TextStyle(
              fontSize: isCompact ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsPanel(bool isWideScreen) {
    if (isWideScreen) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bolt,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                      child: _buildActionButton(
                          'Add Notes', Icons.note_add, _showAddNotesDialog)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildActionButton(
                          'View Notes', Icons.notes, _showMeetingNotesDialog)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      'Activity Log',
                      Icons.history,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ActivityLogPage()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      // Mobile version remains attached to bottom
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      children: [
                        _buildActionButton(
                            'Add Notes', Icons.note_add, _showAddNotesDialog),
                        const SizedBox(height: 8),
                        _buildActionButton(
                            'View Notes', Icons.notes, _showMeetingNotesDialog),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          'Activity Log',
                          Icons.history,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ActivityLogPage()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildActionButton(
      String label, IconData icon, VoidCallback onPressed) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 900;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          vertical: 16,
          horizontal: isWideScreen ? 32 : 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: isWideScreen ? 2 : 0,
      ),
      child: isWideScreen
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isWideScreen ? 16 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isWideScreen ? 16 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }
}

class UserProfile {
  final String name;
  final String id;
  List<CompletedUserHour> completedHours;
  final bool hasPaidDues; // New field

  UserProfile({
    required this.name,
    required this.completedHours,
    required this.id,
    this.hasPaidDues = false, // Default to false
  });

  bool hasCompletedHours() {
    int serviceHours = 0;
    int tutoringHours = 0;
    int meetingHours = 0;

    for (final hour in completedHours) {
      if (hour.type == 'Service') {
        serviceHours += hour.hours.round();
      } else if (hour.type == 'Tutoring') {
        tutoringHours += hour.hours.round();
      } else if (hour.type == 'Meeting') {
        meetingHours += hour.hours.round();
      }
    }

    return serviceHours >= 14 && tutoringHours >= 6 && meetingHours >= 5;
  }
}

class CompletedUserHour {
  final String eventName;
  final double hours;
  final String type;

  CompletedUserHour({
    required this.eventName,
    required this.hours,
    required this.type,
  });

  factory CompletedUserHour.fromJson(Map<String, dynamic> json) {
    final dynamic hoursValue = json['hours'];
    final double hours;
    if (hoursValue is int) {
      hours = hoursValue.toDouble();
    } else if (hoursValue is double) {
      hours = hoursValue;
    } else {
      throw FormatException('Invalid hours value: $hoursValue');
    }

    return CompletedUserHour(
      eventName: json['event_name'] ?? '',
      hours: hours,
      type: json['type'] ?? '',
    );
  }
}

class Attendee {
  final int id;
  final int timeSlotId;
  final String userId;
  final String name;
  bool isPresent;
  bool formsCompleted;

  Attendee({
    required this.id,
    required this.timeSlotId,
    required this.userId,
    required this.name,
    this.isPresent = false,
    this.formsCompleted = false,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) {
    return Attendee(
      id: json['id'],
      timeSlotId: json['timeslot_id'],
      userId: json['user_id'],
      name: json['name'] ?? 'Unknown',
      isPresent: json['is_present'] ?? false,
      formsCompleted: json['forms_completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timeslot_id': timeSlotId,
      'user_id': userId,
      'name': name,
      'is_present': isPresent,
      'forms_completed': formsCompleted,
    };
  }

  Attendee copyWith({
    int? id,
    int? timeSlotId,
    String? userId,
    String? name,
    bool? isPresent,
    bool? formsCompleted,
  }) {
    return Attendee(
      id: id ?? this.id,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      isPresent: isPresent ?? this.isPresent,
      formsCompleted: formsCompleted ?? this.formsCompleted,
    );
  }
}

class BarcodeScannerPage extends StatefulWidget {
  final List<Attendee> attendees;

  const BarcodeScannerPage({super.key, required this.attendees});

  @override
  _BarcodeScannerPageState createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _foundBarcode,
          ),
          // ...
        ],
      ),
    );
  }

  /// Processes scanned barcode data and updates attendance.
  ///
  /// Parameters:
  /// - capture: BarcodeCapture - Captured barcode data
  ///
  /// Returns:
  /// - void
  void _foundBarcode(BarcodeCapture capture) {
    final barcode = capture.barcodes.first;
    final userId = barcode.rawValue;

    final attendeeIndex =
        widget.attendees.indexWhere((attendee) => attendee.userId == userId);
    if (attendeeIndex != -1) {
      Navigator.pop(context, userId);
    }
  }
}

class PillShapedTitle extends StatelessWidget {
  final String title;

  const PillShapedTitle({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class SwapRequest {
  final int id;
  final String requesterId;
  final String currentAttendeeId;
  final int eventId;
  final int timeSlotId;
  final String status;
  final DateTime startTime;
  final DateTime endTime;

  SwapRequest({
    required this.id,
    required this.requesterId,
    required this.currentAttendeeId,
    required this.eventId,
    required this.timeSlotId,
    required this.status,
    required this.startTime,
    required this.endTime,
  });

  factory SwapRequest.fromJson(Map<String, dynamic> json) {
    return SwapRequest(
      id: json['id'],
      requesterId: json['requester_id'],
      currentAttendeeId: json['target_id'],
      eventId: json['event_id'],
      timeSlotId: json['timeslot_id'],
      status: json['status'],
      startTime: DateTime.parse(json['Time slots']['start_time']),
      endTime: DateTime.parse(json['Time slots']['end_time']),
    );
  }
}

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  _ActivityLogPageState createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  DateTime _selectedDate = DateTime.now();
  List<ActivityLog> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final societyId = Provider.of<SocietyProvider>(context, listen: false)
          .currentSociety
          ?.id;
      if (societyId == null) {
        setState(() {
          _logs = [];
          _isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('activity_logs')
          .select('*, profiles:user_id(name)')
          .eq('society_id', societyId) // Filter by current society
          .gte(
              'created_at',
              DateTime(_selectedDate.year, _selectedDate.month,
                      _selectedDate.day)
                  .toIso8601String())
          .lte(
              'created_at',
              DateTime(_selectedDate.year, _selectedDate.month,
                      _selectedDate.day, 23, 59, 59)
                  .toIso8601String())
          .order('created_at', ascending: false);

      setState(() {
        _logs = response
            .map<ActivityLog>((log) => ActivityLog.fromJson(log))
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching logs: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Previous Day Button
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedDate =
                              _selectedDate.subtract(const Duration(days: 1));
                        });
                        _fetchLogs();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2025),
                        );
                        if (picked != null && picked != _selectedDate) {
                          setState(() {
                            _selectedDate = picked;
                          });
                          _fetchLogs();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMMM d, y').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    // Next Day Button
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _selectedDate.year == DateTime.now().year &&
                              _selectedDate.month == DateTime.now().month &&
                              _selectedDate.day == DateTime.now().day
                          ? null
                          : () {
                              setState(() {
                                _selectedDate =
                                    _selectedDate.add(const Duration(days: 1));
                              });
                              _fetchLogs();
                            },
                      // Gray out the icon when on current day
                      color: _selectedDate.year == DateTime.now().year &&
                              _selectedDate.month == DateTime.now().month &&
                              _selectedDate.day == DateTime.now().day
                          ? Colors.grey
                          : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Text(
                          'No activity for this date',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return _buildLogCard(log);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// Creates a card widget displaying activity log entry.
  ///
  /// Parameters:
  /// - log: ActivityLog - Log entry to display
  ///
  /// Returns:
  /// - Widget
  Widget _buildLogCard(ActivityLog log) {
    IconData iconData;
    Color iconColor;
    String actionText;

    switch (log.actionType) {
      case 'signup':
        iconData = Icons.person_add;
        iconColor = Colors.green;
        actionText = 'signed up for';
        break;
      case 'unsignup':
        iconData = Icons.person_remove;
        iconColor = Colors.red;
        actionText = 'removed from';
        break;
      case 'swap':
        iconData = Icons.swap_horiz;
        iconColor = Colors.orange;
        actionText = 'swapped for';
        break;
      case 'attendance_marked':
        iconData = Icons.check_box;
        iconColor = const Color.fromARGB(255, 53, 99, 1);
        actionText = 'marked attended for';
        break;
      case 'attendance_removed':
        iconData = Icons.check_box_outline_blank;
        iconColor = Color.fromARGB(255, 99, 24, 1);
        actionText = 'attendance removed for';
        break;
      case 'manual_addition':
        iconData = Icons.add_box;
        iconColor = Colors.purple;
        actionText = 'marked for manual event:';
        break;
      case 'manual_deletion':
        iconData = Icons.disabled_by_default;
        iconColor = Colors.red;
        actionText = 'removed from manual event:';
        break;

      default:
        iconData = Icons.info;
        iconColor = Colors.grey;
        actionText = 'modified';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(iconData, color: iconColor),
        ),
        title: RichText(
          text: textspan.TextSpan(
            style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSecondaryContainer),
            children: [
              textspan.TextSpan(
                text: log.userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              textspan.TextSpan(text: ' $actionText '),
              textspan.TextSpan(
                text: log.eventName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: ${log.timeslot}'),
            Text('Hours: ${log.hours}'),
            if (log.actionType == 'swap')
              Text('Swapped with: ${log.newUserName ?? 'Unknown'}'),
            Text('Time: ${DateFormat('h:mm a').format(log.createdAt)}'),
          ],
        ),
      ),
    );
  }
}

class ActivityLog {
  final int id;
  final String eventName;
  final String timeslot;
  final double hours;
  final String actionType;
  final String userId;
  final String userName;
  final DateTime createdAt;
  final String? oldUserId;
  final String? newUserId;
  final String? oldUserName;
  final String? newUserName;

  ActivityLog({
    required this.id,
    required this.eventName,
    required this.timeslot,
    required this.hours,
    required this.actionType,
    required this.userId,
    required this.userName,
    required this.createdAt,
    this.oldUserId,
    this.newUserId,
    this.oldUserName,
    this.newUserName,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'],
      eventName: json['event_name'],
      timeslot: json['timeslot'],
      hours: json['hours'].toDouble(),
      actionType: json['action_type'],
      userId: json['user_id'],
      userName: json['profiles']['name'],
      createdAt: DateTime.parse(json['created_at']),
      oldUserId: json['old_user_id'],
      newUserId: json['new_user_id'],
      oldUserName: json['old_user_name'],
      newUserName: json['new_user_name'],
    );
  }
}

/// Records user activity in the system for auditing purposes.
///
/// Parameters:
/// - eventName: String - Name of event
/// - timeslot: String - Time slot information
/// - hours: double - Hours involved
/// - actionType: String - Type of action
/// - userId: String - User performing action
/// - oldUserId: String? - Previous user (for swaps)
/// - newUserId: String? - New user (for swaps)
///
/// Returns:
/// - Future<void>
Future<void> _logActivity(
  String eventName,
  String timeslot,
  double hours,
  String actionType,
  String userId, {
  String? oldUserId,
  String? newUserId,
  int? societyId,
}) async {
  try {
    await supabase.from('activity_logs').insert({
      'event_name': eventName,
      'timeslot': timeslot,
      'hours': hours,
      'action_type': actionType,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
      'old_user_id': oldUserId,
      'new_user_id': newUserId,
      'society_id': societyId,
    });
  } catch (e) {
    print('Error logging activity: $e');
  }
}

class HourRequirementsPage extends StatefulWidget {
  final HonorSociety society;

  const HourRequirementsPage({Key? key, required this.society})
      : super(key: key);

  @override
  _HourRequirementsPageState createState() => _HourRequirementsPageState();
}

class _HourRequirementsPageState extends State<HourRequirementsPage> {
  List<HourRequirement> _requirements = [];
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _requirements = List.from(widget.society.hourRequirements);
  }

  void _showEditRequirementDialog(HourRequirement requirement) {
    String type = requirement.type;
    String description = requirement.description;
    double hours = requirement.hoursNeeded;
    bool isActive = requirement.isActive;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Hour Requirement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Type Name',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: type),
                onChanged: (value) => type = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: description),
                maxLines: 2,
                onChanged: (value) => description = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Hours Required',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: hours.toString()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => hours = double.tryParse(value) ?? hours,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text(
                    'Inactive requirements won\'t be counted or displayed'),
                value: isActive,
                onChanged: (value) => setState(() => isActive = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _showDeleteConfirmation(requirement);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (type.isNotEmpty && hours > 0) {
                setState(() => _isLoading = true);
                try {
                  await supabase.from('hour_requirements').update({
                    'type': type,
                    'description': description,
                    'hours_needed': hours,
                    'is_active': isActive,
                  }).eq('id', requirement.id);

                  setState(() {
                    final index =
                        _requirements.indexWhere((r) => r.id == requirement.id);
                    if (index != -1) {
                      _requirements[index] = HourRequirement(
                        id: requirement.id,
                        type: type,
                        description: description,
                        hoursNeeded: hours,
                        isActive: isActive,
                      );
                    }
                    _hasChanges = true;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Requirement updated successfully')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating requirement: $e')),
                    );
                  }
                } finally {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(HourRequirement requirement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Requirement'),
        content: Text(
          'Are you sure you want to delete the ${requirement.type} requirement? '
          'This will affect all historical records using this type.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                await supabase
                    .from('hour_requirements')
                    .delete()
                    .eq('id', requirement.id);

                setState(() {
                  _requirements.removeWhere((r) => r.id == requirement.id);
                  _hasChanges = true;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Requirement deleted successfully')),
                  );
                  Navigator.pop(context); // Close delete confirmation
                  Navigator.pop(context); // Close edit dialog
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting requirement: $e')),
                  );
                }
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddRequirementDialog() {
    String type = '';
    String description = '';
    double hours = 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Hour Requirement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Type Name',
                  hintText: 'E.g., Service, Tutoring, Leadership',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => type = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe what counts for this requirement',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (value) => description = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Hours Required',
                  hintText: 'E.g., 10.0',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => hours = double.tryParse(value) ?? 0,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (type.isNotEmpty && hours > 0) {
                setState(() => _isLoading = true);
                try {
                  final response = await supabase
                      .from('hour_requirements')
                      .insert({
                        'society_id': widget.society.id,
                        'type': type,
                        'description': description,
                        'hours_needed': hours,
                        'is_active': true,
                      })
                      .select()
                      .single();

                  setState(() {
                    _requirements.add(HourRequirement.fromJson(response));
                    _hasChanges = true;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Requirement added successfully')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding requirement: $e')),
                    );
                  }
                } finally {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                // Refresh requirements from the database
                final requirementsResponse = await supabase
                    .from('hour_requirements')
                    .select()
                    .eq('society_id', widget.society.id);

                setState(() {
                  _requirements = requirementsResponse
                      .map<HourRequirement>(
                          (json) => HourRequirement.fromJson(json))
                      .toList();
                });
              },
              child: _requirements.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.playlist_add,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No requirements defined',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the + button to add requirements',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _requirements.length,
                      itemBuilder: (context, index) {
                        final requirement = _requirements[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: requirement.isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                              foregroundColor: Colors.white,
                              child: const Icon(Icons.access_time),
                            ),
                            title: Text(
                              requirement.type,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    requirement.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(requirement.description),
                                const SizedBox(height: 4),
                                Text(
                                  '${requirement.hoursNeeded} hours required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: requirement.isActive
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _showEditRequirementDialog(requirement),
                            ),
                            onTap: () =>
                                _showEditRequirementDialog(requirement),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRequirementDialog,
        tooltip: 'Add Requirement',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    // Notify parent if changes were made
    if (_hasChanges && ModalRoute.of(context)?.isCurrent == false) {
      // This would typically trigger a refresh of the parent's data
      // You could use callbacks or state management here
    }
    super.dispose();
  }
}

class SocietyJoinRequestPage extends StatefulWidget {
  const SocietyJoinRequestPage({super.key});

  @override
  _SocietyJoinRequestPageState createState() => _SocietyJoinRequestPageState();
}

class _SocietyJoinRequestPageState extends State<SocietyJoinRequestPage> {
  List<HonorSociety> _availableSocieties = [];
  Map<int, String> _requestStatuses =
      {}; // Track status: 'pending', 'approved', 'rejected'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAvailableSocieties();
    _fetchAllRequestStatuses();
  }

  Future<void> _fetchAvailableSocieties() async {
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get societies user is already a member of
      final memberships = await supabase
          .from('user_society_memberships')
          .select('society_id')
          .eq('user_id', userId);

      final memberSocietyIds = memberships.map((m) => m['society_id']).toList();

      // Fetch all societies (not just ones they're not a member of)
      // We'll filter the display based on membership and request status
      final societies = await supabase.from('honor_societies').select('''
            id,
            name,
            description,
            image_url,
            meeting_requirement,
            created_at,
            hour_requirements(
              id,
              type,
              description,
              hours_needed,
              is_active
            )
          ''');

      setState(() {
        _availableSocieties = societies.map<HonorSociety>((societyData) {
          final hourRequirements = (societyData['hour_requirements'] as List)
              .map((req) => HourRequirement.fromJson(req))
              .toList();

          return HonorSociety(
            id: societyData['id'],
            name: societyData['name'],
            description: societyData['description'],
            imageUrl: societyData['image_url'],
            hourRequirements: hourRequirements,
            meetingRequirement: societyData['meeting_requirement'],
            createdAt: DateTime.parse(societyData['created_at']),
          );
        }).toList();

        // Filter out societies the user is already a member of
        _availableSocieties = _availableSocieties
            .where((society) => !memberSocietyIds.contains(society.id))
            .toList();
      });
    } catch (e) {
      print('Error loading societies: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading societies: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Fetch all request statuses (pending, approved, rejected)
  Future<void> _fetchAllRequestStatuses() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get all requests for the current user with their status
      final requestsResponse = await supabase
          .from('society_join_requests')
          .select('society_id, status')
          .eq('user_id', userId);

      // Create a map of society_id -> status for quick lookup
      final Map<int, String> statusMap = {};
      for (final req in requestsResponse) {
        statusMap[req['society_id']] = req['status'];
      }

      setState(() {
        _requestStatuses = statusMap;
      });
    } catch (e) {
      print('Error fetching request statuses: $e');
    }
  }

  Future<void> _requestJoin(HonorSociety society) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // First check if a request already exists
      final existingRequest = await supabase
          .from('society_join_requests')
          .select()
          .eq('user_id', userId)
          .eq('society_id', society.id)
          .maybeSingle();

      if (existingRequest != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have a request for this society'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // Create the join request
      await supabase.from('society_join_requests').insert({
        'user_id': userId,
        'society_id': society.id,
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
      });

      // Update local state
      setState(() {
        _requestStatuses[society.id] = 'pending';
      });

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Request Sent'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                    'Your request to join ${society.name} has been sent successfully.'),
                const SizedBox(height: 8),
                const Text(
                  'An administrator will review your request soon.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending request: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Allow resubmitting after a rejection
  Future<void> _resubmitRequest(HonorSociety society) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // Update the existing request
      await supabase
          .from('society_join_requests')
          .update({
            'status': 'pending',
            'requested_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('society_id', society.id);

      // Update local state
      setState(() {
        _requestStatuses[society.id] = 'pending';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request resubmitted for ${society.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resubmitting request: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join an Honor Society'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availableSocieties.isEmpty
              ? const Center(
                  child: Text('No available societies to join'),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      _fetchAvailableSocieties(),
                      _fetchAllRequestStatuses(),
                    ]);
                  },
                  child: ListView.builder(
                    itemCount: _availableSocieties.length,
                    itemBuilder: (context, index) {
                      final society = _availableSocieties[index];
                      final status = _requestStatuses[society.id];
                      final hasPendingRequest = status == 'pending';
                      final hasRejectedRequest = status == 'rejected';

                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          leading: society.imageUrl != null
                              ? CircleAvatar(
                                  backgroundImage:
                                      NetworkImage(society.imageUrl!),
                                )
                              : CircleAvatar(
                                  child: Text(society.name[0]),
                                ),
                          title: Text(society.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(society.description),
                              if (hasRejectedRequest)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Your previous request was rejected',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: hasPendingRequest
                              ? Chip(
                                  label: const Text('Request Pending'),
                                  backgroundColor: Colors.amber[100],
                                  labelStyle: TextStyle(
                                    color: Colors.amber[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                  avatar: Icon(
                                    Icons.hourglass_top,
                                    color: Colors.amber[800],
                                    size: 18,
                                  ),
                                )
                              : hasRejectedRequest
                                  ? ElevatedButton(
                                      onPressed: () =>
                                          _resubmitRequest(society),
                                      child: const Text('Resubmit Request'),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _requestJoin(society),
                                      child: const Text('Request Join'),
                                    ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class SocietySelectionPage extends StatelessWidget {
  const SocietySelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Honor Society'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: Consumer<SocietyProvider>(
        builder: (context, societyProvider, _) {
          if (societyProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final societies = societyProvider.userSocieties;

          if (societies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_off,
                    size: 80,
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'You are not a member of any honor societies',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SocietyJoinRequestPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Request to Join'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Use ResponsiveGridView for better layout on different screen sizes
          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: societies.length,
              itemBuilder: (context, index) {
                final society = societies[index];
                // Get a different but subtle color for each card based on index
                return _buildSocietyCard(context, society, index);
              },
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SocietyJoinRequestPage(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Join Another Society'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(double.infinity, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocietyCard(
      BuildContext context, HonorSociety society, int index) {
    // Use a list of complementary but subtle colors for each card
    final List<Color> cardColors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.amber,
      Colors.teal,
      Colors.indigo,
      Colors.purple,
      Colors.green,
    ];

    // Use a matching but slightly deeper color for the image placeholder background
    final List<Color> imageColors = [
      Theme.of(context).colorScheme.primary.withOpacity(0.2),
      Theme.of(context).colorScheme.secondary.withOpacity(0.2),
      Theme.of(context).colorScheme.tertiary.withOpacity(0.2),
      Colors.amber.withOpacity(0.2),
      Colors.teal.withOpacity(0.2),
      Colors.indigo.withOpacity(0.2),
      Colors.purple.withOpacity(0.2),
      Colors.green.withOpacity(0.2),
    ];

    // Get the color for this card based on index, cycling through the list
    final cardColor = cardColors[index % cardColors.length];
    final imageColor = imageColors[index % imageColors.length];

    // Also vary the border slightly based on index for a subtle effect
    final borderColor = (index % 3 == 0)
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor,
        ),
      ),
      color: cardColor.withOpacity(0.5),
      child: InkWell(
        onTap: () {
          _selectSociety(context, society);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: society.imageUrl != null
                  ? Image.network(
                      society.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: imageColor,
                        child: Center(
                          child: Icon(
                            Icons.school,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: imageColor,
                      child: Center(
                        child: Icon(
                          Icons.school,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4),
                        ),
                      ),
                    ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          child: Text(
                            society.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Select button
                        Container(
                          decoration: BoxDecoration(
                            color: cardColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              weight: 10,
                            ),
                            color: cardColor,
                            onPressed: () => _selectSociety(context, society),
                            tooltip: 'Select',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectSociety(BuildContext context, HonorSociety society) async {
    final provider = Provider.of<SocietyProvider>(context, listen: false);

    // Save the navigator state before any async operations
    final NavigatorState navigator = Navigator.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Set the current society
      await provider.setCurrentSociety(society.id);

      // We can use the saved navigator regardless of if the original context is mounted
      // First close the dialog
      navigator.pop();

      // Then navigate to MainScreen
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false, // This removes all previous routes
      );
    } catch (e) {
      // Make sure to close loading dialog on error
      try {
        navigator.pop(); // Close the dialog

        // Show error message if possible
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting society: $e')),
        );
      } catch (dialogError) {
        // If even this fails, log the error
        print('Error handling society selection failure: $dialogError');
        print('Original error: $e');
      }
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog

                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                // Sign out the user
                await _signOut(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final navigatorState = Navigator.of(context);

    // Clear any cached data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionData');

    // Sign out from Supabase
    await supabase.auth.signOut();

    // Navigate to login page and remove all routes
    navigatorState.pushNamedAndRemoveUntil('/', (route) => false);
  }
}

// Helper method to normalize type strings for consistent matching
String normalizeType(String type) {
    // Convert to title case for consistent comparison
    return type.trim().split(' ').map((word) => 
      word.isNotEmpty ? 
        word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '') : 
        ''
    ).join(' ');
  }

/// Gets the appropriate icon name for an event type based on society requirements
/// 
/// This function looks up the matching requirement in the honor society
/// and returns its configured icon name. Falls back to defaults if no match is found.
/// 
/// Parameters:
/// - context: BuildContext - Required for provider access
/// - eventType: String - The type of event to find an icon for
/// 
/// Returns:
/// - String - The icon name to use
String getIconNameForEventType(BuildContext context, String eventType) {
  // Early exit if no event type provided
  if (eventType.isEmpty) return 'workspaces';
  // Get the current society from provider
  final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
  if (society == null) {
    // Fallback if no society is available
    return _getDefaultIconNameForType(eventType);
  }
  
  // Special case for Meeting type (often doesn't have a requirement object)
  if (eventType.toLowerCase() == 'meeting') {
    // Check if there's a custom Meeting requirement first
    final meetingReq = society.hourRequirements.firstWhere(
      (req) => req.type.toLowerCase() == 'meeting',
      orElse: () => HourRequirement(
        id: -1, 
        type: 'Meeting', 
        hoursNeeded: 0, 
        description: '',
        iconName: 'leadership', // Default meeting icon
      ),
    );
    return meetingReq.iconName;
  }
  
  // Find the requirement that matches this event type (case-insensitive)
  // Use normalizeType extension for consistent matching
  final normalizedEventType = normalizeType(eventType);
  
  // First try exact match
  for (final req in society.hourRequirements) {
    if (normalizeType(req.type) == normalizedEventType && req.isActive) {
      return req.iconName;
    }
  }
  
  // Try partial match if no exact match found
  for (final req in society.hourRequirements) {
    if (req.isActive && 
        (normalizedEventType.contains(normalizeType(req.type)) || 
         normalizeType(req.type).contains(normalizedEventType))) {
      return req.iconName;
    }
  }
  
  // No matching requirement found, fall back to default
  return _getDefaultIconNameForType(eventType);
}

IconData getIconForType(String type, BuildContext context) {
  final iconName = getIconNameForEventType(context, type);
 return getIconDataByName(iconName);
}

class NhsFormatUtils {
  static String formatTimeSlot(TimeSlot timeSlot, BuildContext context) {
    return '${formatTimeOfDay(timeSlot.time, context)} - ${formatTimeOfDay(timeSlot.endTime, context)}';
  }
  
  static String formatTimeOfDay(TimeOfDay time, BuildContext context) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dateTime);
  }
  
  static double calculateDuration(TimeOfDay startTime, TimeOfDay endTime) {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final difference = endMinutes - startMinutes;
    return difference / 60.0;
  }
}

/// Helper function to get a default icon name based on event type
/// Used as fallback when no matching requirement is found
String _getDefaultIconNameForType(String eventType) {
  final lowerType = eventType.toLowerCase();
  
  if (lowerType.contains('service') || lowerType.contains('volunteer')) {
    return 'volunteer_activism';
  }
  if (lowerType.contains('tutor') || lowerType.contains('teach')) {
    return 'school';
  }
  if (lowerType.contains('meeting')) {
    return 'groups';
  }
  if (lowerType.contains('leader') || lowerType.contains('officer')) {
    return 'emoji_people';
  }
  if (lowerType.contains('fundrais') || lowerType.contains('donat')) {
    return 'attach_money';
  }
  if (lowerType.contains('communit')) {
    return 'public';
  }
  if (lowerType.contains('environment') || lowerType.contains('garden')) {
    return 'nature';
  }
  if (lowerType.contains('health') || lowerType.contains('medical')) {
    return 'health_and_safety';
  }
  if (lowerType.contains('tech') || lowerType.contains('computer')) {
    return 'computer';
  }
  if (lowerType.contains('art')) {
    return 'palette';
  }
  if (lowerType.contains('music')) {
    return 'music_note';
  }
  if (lowerType.contains('sport') || lowerType.contains('athletic')) {
    return 'sports';
  }
  if (lowerType.contains('research') || lowerType.contains('science')) {
    return 'science';
  }
  if (lowerType.contains('writing') || lowerType.contains('essay')) {
    return 'edit_note';
  }
  if (lowerType.contains('mentor')) {
    return 'psychology';
  }
  
  // Default icon if no match
  return 'workspaces';
}