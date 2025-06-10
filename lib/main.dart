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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hcuygigxjucxutavjvsc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhjdXlnaWd4anVjeHV0YXZqdnNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTI4NzU1NjgsImV4cCI6MjAyODQ1MTU2OH0.0x6jIeOANj6_Y5s7EQ9tuU3GhZLZblobDAt_W2dOLJA',
  );

  final themeNotifier = ThemeNotifier();
  final themeProvider = ThemeProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeNotifier),
        ChangeNotifierProvider(create: (_) => themeProvider),
      ],
      child: MyApp(themeNotifier: themeNotifier),
    ),
  );
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  final ThemeNotifier themeNotifier;

  const MyApp({super.key, required this.themeNotifier});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeNotifier),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: FutureBuilder<void>(
        future: _fetchUserThemeColor(themeNotifier),
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
                animation: themeNotifier,
                builder: (context, _) {
                  return MaterialApp(
                    title: 'NHS Hour Tracking',
                    debugShowCheckedModeBanner: false,
                    theme: themeProvider.isDarkMode
                        ? ThemeData.dark().copyWith(
                            colorScheme: ColorScheme.fromSeed(
                              seedColor: themeNotifier.themeColor,
                              brightness: Brightness.dark,
                            ),
                          )
                        : ThemeData(
                            colorSchemeSeed: themeNotifier.themeColor,
                            useMaterial3: true,
                          ),
                    initialRoute: '/',
                    routes: {
                      '/': (context) => const LoginPage(),
                      '/admin/events': (context) => AdminEventsPage(),
                      '/admin/attendance': (context) => AdminAttendancePage(),
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

class MainScreen extends StatefulWidget {
  final HonorSociety society;
  
  const MainScreen({
    super.key, 
    required this.society
  });

   @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  PageController _pageController = PageController();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchUserAdminStatus();
  }

  /// Checks if current user has admin privileges.
  /// Updates UI state based on admin status.
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _fetchUserAdminStatus() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;

    if (userId != null) {
      final response = await Supabase.instance.client
          .from('user_society_memberships')
          .select('is_admin')
          .eq('user_id', userId)
          .eq('society_id', widget.society.id)
          .single();

      if (mounted) {
        setState(() {
          _isAdmin = response['is_admin'] ?? false;
        });
      }
    }
  }

  /// Cleans up resources when main screen is disposed.
  /// Disposes of page controller to prevent memory leaks.
  ///
  /// Returns:
  /// - void
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width >= 600;
    final List<Widget> pages = [
      if (_isAdmin) ...[
        AdminTotalHoursPage(),
        AdminEventsPage(),
        AdminAttendancePage(),
        AdminListPage(),
        SettingsPage(),
      ] else ...[
        HomePage(),
        CompletedHoursPage(),
        SettingsPage(),
      ],
    ];

    final List<BottomNavyBarItem> navItems = [
      if (_isAdmin) ...[
        BottomNavyBarItem(
          title: const Text('Total Hours'),
          icon: const Icon(Icons.home),
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.onSurface,
        ),
        BottomNavyBarItem(
          title: const Text('Add'),
          icon: const Icon(Icons.add_circle),
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
          title: const Text('List'),
          icon: const Icon(Icons.view_list),
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.onSurface,
        ),
        BottomNavyBarItem(
          title: const Text('Profile'),
          icon: const Icon(Icons.account_circle),
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
          title: const Text('Hours'),
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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              selectedIndex: _currentIndex,
              onItemSelected: (index) {
                setState(() => _currentIndex = index);
                _pageController.jumpToPage(index);
              },
              items: navItems,
     ),
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
                    // Navigate to the main screen on successful sign-in
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => SocietySelectionPage()),
                    );
                  }
                },
              ),
              // SupaSocialsAuth(
              //   socialProviders: const [],
              //   colored: true,
              //   onSuccess: (Session response) {
              //     // Navigate to the home page on successful social sign-in
              //     Navigator.pushReplacement(
              //       context,
              //       MaterialPageRoute(builder: (context) => SocietySelectionPage()),
              //     );
              //   },
              //   onError: (error) {
              //     // Handle the error
              //     print('Social sign-in error: $error');
              //   },
              // ),
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
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentPageIndex = 0;
  double _serviceHoursCompleted = 0;
  double _tutoringHoursCompleted = 0;
  double _meetingHoursCompleted = 0;
  double _servicePotentialHours = 0;
  double _tutoringPotentialHours = 0;
  double _meetingPotentialHours = 0;
  List<Collection> _collections = [];
  List<Event> _events = [];
  String _selectedEventType = 'All';
  final Set<int> _renderedCollections = Set<int>();
  final DateFormat formatter = DateFormat('jm');

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _fetchCollections();
    _checkPendingSwapRequests();
  }

  Future<void> _fetchEvents() async {
    final eventResponse = await Supabase.instance.client
        .from('Events')
        .select()
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
      _fetchCompletedHours();
    }
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

  /// Creates filter chips for event type selection.
  /// Handles filter state and updates event list.
  ///
  /// Returns:
  /// - List<Widget>
  List<Widget> _buildEventTypeChips() {
    return [
      FilterChip(
        label: const Text('All'),
        selected: _selectedEventType == 'All',
        onSelected: (selected) {
          setState(() {
            _selectedEventType = 'All';
          });
        },
      ),
      FilterChip(
        label: const Text('Service'),
        selected: _selectedEventType == 'Service',
        onSelected: (selected) {
          setState(() {
            _selectedEventType = 'Service';
          });
        },
      ),
      FilterChip(
        label: const Text('Tutoring'),
        selected: _selectedEventType == 'Tutoring',
        onSelected: (selected) {
          setState(() {
            _selectedEventType = 'Tutoring';
          });
        },
      ),
      FilterChip(
        label: const Text('Meeting'),
        selected: _selectedEventType == 'Meeting',
        onSelected: (selected) {
          setState(() {
            _selectedEventType = 'Meeting';
          });
        },
      ),
    ];
  }

  /// Filters events based on selected event type.
  ///
  /// Returns:
  /// - List<Event> - Filtered list of events
  List<Event> _getFilteredEvents() {
    if (_selectedEventType == 'All') {
      return _events;
    } else {
      return _events
          .where((event) => event.type == _selectedEventType)
          .toList();
    }
  }

  /// Retrieves and calculates completed service hours for the current user.
  /// Separates hours by type (Service/Tutoring/Meeting).
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _fetchCompletedHours() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;

    if (userId != null) {
      final response = await Supabase.instance.client
          .from('Service hours')
          .select('hours, type')
          .eq('user_id', userId);

      if (_events != null) {
        final data = response;
        double serviceHours = 0;
        double tutoringHours = 0;
        double meetingHours = 0;
        double serviceHoursC = 0;
        double tutoringHoursC = 0;
        double meetingHoursC = 0;

        for (final entry in data) {
          final hours = entry['hours'];
          final eventType = entry['type'] as String;

          if (eventType == 'service' || eventType == 'Service') {
            serviceHours += hours;
            serviceHoursC += hours;
          } else if (eventType == 'tutoring' || eventType == 'Tutoring') {
            tutoringHours += hours;
            tutoringHoursC += hours;
          } else if (eventType == 'meeting' || eventType == 'Meeting') {
            meetingHours += hours;
            meetingHoursC += hours;
          }
        }

        for (final event in _events) {
          for (final timeSlot in event.timeSlots) {
            final isSignedUp =
                timeSlot.attendees.any((attendee) => attendee.userId == userId);
            final isNotPresent = timeSlot.attendees.any(
                (attendee) => attendee.userId == userId && !attendee.isPresent);

            if (isSignedUp && isNotPresent) {
              final duration =
                  _calculateDuration(timeSlot.time, timeSlot.endTime);
              if (event.type == 'Service') {
                serviceHours += duration;
              } else if (event.type == 'Tutoring') {
                tutoringHours += duration;
              } else if (event.type == 'Meeting') {
                meetingHours += duration;
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _servicePotentialHours = serviceHours;
            _tutoringPotentialHours = tutoringHours;
            _meetingPotentialHours = meetingHours;
            _serviceHoursCompleted = serviceHoursC;
            _tutoringHoursCompleted = tutoringHoursC;
            _meetingHoursCompleted = meetingHoursC;
          });
        }
      }
    }
  }

  double _calculateDuration(TimeOfDay startTime, TimeOfDay endTime) {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final duration = (endMinutes - startMinutes) / 60;
    return duration;
  }

  /// Creates a double progress bar showing completed and potential hours.
  ///
  /// Parameters:
  /// - context: BuildContext - Current build context
  /// - title: String - Progress bar title
  /// - completedHours: double - Actual completed hours
  /// - potentialHours: double - Possible hours including pending events
  /// - hoursNeeded: int - Required hours target
  ///
  /// Returns:
  /// - Widget
  Widget _buildDoubleProgressBar(BuildContext context, String title,
      double completedHours, double potentialHours, int hoursNeeded) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completed: ${completedHours.toStringAsFixed(2)} hours',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              LinearProgressIndicator(
                value: potentialHours / hoursNeeded,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer
                    .withOpacity(0.5)),
                minHeight: 10,
                borderRadius: const BorderRadius.all(Radius.circular(33)),
              ),
              LinearProgressIndicator(
                value: completedHours / hoursNeeded,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary),
                minHeight: 10,
                borderRadius: const BorderRadius.all(Radius.circular(33)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Potential $title: ${potentialHours.toStringAsFixed(2)} hours',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// Creates a progress bar specifically for meeting attendance.
  /// Shows meetings attended and remaining meetings.
  ///
  /// Parameters:
  /// - context: BuildContext - Current build context
  /// - completedHours: double - Number of meetings attended
  /// - hoursNeeded: int - Required number of meetings
  ///
  /// Returns:
  /// - Widget
  Widget _buildMeetingProgressBar(
      BuildContext context, double completedHours, int hoursNeeded) {
    final meetingsAttended = completedHours.floor();
    final meetingsLeft =
        _events.where((event) => event.type == 'Meeting').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meetings Attended: $meetingsAttended',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: completedHours / hoursNeeded,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary),
            minHeight: 10,
            borderRadius: const BorderRadius.all(Radius.circular(33)),
          ),
          const SizedBox(height: 5),
          Text(
            'Meetings Left: $meetingsLeft',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
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

    // Check forms completion at event level
    final bool formsCompleted = event.timeSlots.any((timeSlot) =>
        timeSlot.attendees.any((attendee) =>
            attendee.userId == currentUserId && attendee.formsCompleted));

    final bool showRequiredFormsStickerprogram =
        event.requiresForms && !formsCompleted && event.timeSlots.any((timeSlot) =>
            timeSlot.attendees.any((attendee) => attendee.userId == currentUserId));

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          if (showRequiredFormsStickerprogram)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Required Forms',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else if (isMandatory)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Mandatory',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else if (isNew)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
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
              // Get timeslot-specific status
              final isSignedUpForTimeSlot = timeSlot.attendees
                  .any((attendee) => attendee.userId == currentUserId);
              final hasCompletedRequirements = event.type == 'Service' ? 
                _serviceHoursCompleted >= 14 :
                event.type == 'Tutoring' ? 
                _tutoringHoursCompleted >= 6 :
                _meetingHoursCompleted >= 5;
              // Check if signup is delayed
              final canSignUp = !hasCompletedRequirements || !event.hasDelay || event.canSignUpForTimeSlot(timeSlot);
        
                  
              // Check if we can show the cancel button
              final isTimeSlotInFuture = DateTime(
                event.date.year,
                event.date.month,
                event.date.day,
                timeSlot.time.hour,
                timeSlot.time.minute,
              ).isAfter(DateTime.now());

              // Check if we can show the swap button
              final canRequestSwap = isSignedUpForTimeSlot &&
                  DateTime.now().isAfter(event.date.subtract(event.swapRequestDeadline)) &&
                  DateTime.now().isBefore(DateTime(
                    event.date.year,
                    event.date.month,
                    event.date.day,
                    timeSlot.time.hour,
                    timeSlot.time.minute,
                  ));

              // Get forms status for this timeslot
              final timeSlotFormsCompleted = isSignedUpForTimeSlot
                  ? timeSlot.attendees
                      .firstWhere((attendee) => attendee.userId == currentUserId)
                      .formsCompleted
                  : false;

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
                    if (!(event.type == 'Meeting'))
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
                trailing: isSignedUpForTimeSlot
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () {
                              _addEventToCalendar(event, timeSlot);
                            },
                          ),
                          if (canRequestSwap && event.type != 'Meeting' && !isMandatory)
                            IconButton(
                              icon: const Icon(Icons.swap_horiz),
                              onPressed: () {
                                _showSwapRequestDialog(event, timeSlot);
                              },
                            ),
                          if (isTimeSlotInFuture &&
                              !isMandatory &&
                              event.type != 'Meeting' &&
                              !canRequestSwap)
                            IconButton(
                              icon: const Icon(Icons.cancel),
                              onPressed: () {
                                _removeAttendee(event, timeSlot);
                              },
                            ),
                          if (event.requiresForms)
                            IconButton(
                              icon: Icon(timeSlotFormsCompleted
                                  ? Icons.inventory
                                  : Icons.pending_actions),
                              onPressed: () {
                                _showUploadFormsDialog(
                                    event, timeSlot, timeSlotFormsCompleted);
                              },
                            ),
                        ],
                      )
                    : isMandatory || event.type == 'Meeting'
                        ? const Text('Automatically Signed Up')
                        : !canSignUp
                            ? Tooltip(
                                message: 'Signup available ${event.delayHours} hours before event',
                                child: Icon(Icons.timer, color: Colors.orange),
                              )
                            : ElevatedButton(
                            onPressed: () {
                              _showSignUpForm(event, timeSlot);
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('  Sign Up  '),
                          ),
              );
            }).toList(),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _getFilteredEvents();
    final collections = _getUniqueCollections(filteredEvents);
    final combinedList = <dynamic>[
      ...collections,
      ...filteredEvents.where((event) => event.collectionId == null)
    ];

    combinedList.sort((a, b) {
      final dateA = a is Collection ? _getClosestEventDate(a) : a.date;
      final dateB = b is Collection ? _getClosestEventDate(b) : b.date;
      return dateA.compareTo(dateB);
    });

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context)
            .bannerTheme
            .backgroundColor,
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildDoubleProgressBar(context, 'Service Hours',
                _serviceHoursCompleted, _servicePotentialHours, 14),
            _buildDoubleProgressBar(context, 'Tutoring Hours',
                _tutoringHoursCompleted, _tutoringPotentialHours, 6),
            _buildMeetingProgressBar(context, _meetingHoursCompleted, 5),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              children: _buildEventTypeChips(),
            ),
            const SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: combinedList.length,
              itemBuilder: (context, index) {
                final item = combinedList[index];
                if (item is Collection) {
                  return _buildCollectionCard(item);
                } else {
                  return _buildEventCard(item as Event);
                }
              },
            ),
          ],
        ),
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
        _calculateDuration(timeSlot.time, timeSlot.endTime),
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
    final hasCompletedRequirements = event.type == 'Service' ? 
      _serviceHoursCompleted >= 14 :
      event.type == 'Tutoring' ? 
      _tutoringHoursCompleted >= 6 :
      _meetingHoursCompleted >= 5;
    final canSignUp = !hasCompletedRequirements || !event.hasDelay || event.canSignUpForTimeSlot(timeSlot);

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
          _calculateDuration(timeSlot.time, timeSlot.endTime),
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
      )
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
        _calculateDuration(TimeOfDay.fromDateTime(swapRequest.startTime),
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

Future<void> exportToExcel(BuildContext context, List<UserProfile> users) async {
  try {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Members'];

    int maxEvents = 0;

    final userIds = users.map((u) => u.id).toList();
    final emailsResponse = await Supabase.instance.client
        .from('profiles')
        .select('user_id, email')
        .inFilter('user_id', userIds);

    final emailMap = {
      for (var item in emailsResponse)
        item['user_id'] as String: item['email'] as String
    };

    final hoursResponse = await Supabase.instance.client
        .from('Service hours')
        .select('user_id, event_name, hours, type, date, timeslot')
        .inFilter('user_id', userIds)
        .order('date');

    Map<String, UserServiceData> userServiceData = {};

    for (final entry in hoursResponse) {
      try {
        final userId = entry['user_id']?.toString() ?? '';
        if (userId.isEmpty) continue;

        final hours = (entry['hours'] as num?)?.toDouble() ?? 0.0;
        final type = entry['type']?.toString() ?? 'Service';
        final eventName = entry['event_name']?.toString() ?? 'Unnamed Event';

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
          userServiceData.putIfAbsent(userId, () => UserServiceData());
          final userData = userServiceData[userId]!;

          // Update totals based on type
          if (type == 'Service') {
            userData.serviceHours += hours;
          } else if (type == 'Tutoring') {
            userData.tutoringHours += hours;
          } else if (type == 'Meeting') {
            userData.meetingsAttended++;
          }

          // Format and add event detail to ordered list
          final formattedDate = '${date.month}/${date.day}/${date.year}';
          final eventDetail =
              '$eventName ($formattedDate - $timeSlot): $hours hours';
          userData.eventsList.add(eventDetail);

          // Update max events count
          maxEvents = userData.eventsList.length > maxEvents
              ? userData.eventsList.length
              : maxEvents;
        }
      } catch (e) {
        print('Error processing entry: $e');
        continue;
      }
   }

    final baseHeaders = [
      'Name',
      'Email',
      'Dues Paid',
      'Meetings Attended',
      'Service Hours',
      'Tutoring Hours'
    ];
    final eventHeaders = List.generate(maxEvents, (i) => 'Event ${i + 1}');
    final allHeaders = [...baseHeaders, ...eventHeaders];

    // Write headers
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
      final userData = userServiceData[user.id] ?? UserServiceData();

      // Write base data
      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
          .value = TextCellValue(user.name);

      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
          .value = TextCellValue(emailMap[user.id] ?? '');

      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
          .value = TextCellValue(user.hasPaidDues ? 'Yes' : 'No');

      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
          .value = IntCellValue(userData.meetingsAttended);

      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
          .value = DoubleCellValue(userData.serviceHours);

      sheetObject
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
          .value = DoubleCellValue(userData.tutoringHours);

      // Write events in sequential columns
      for (var i = 0; i < userData.eventsList.length; i++) {
        sheetObject
            .cell(CellIndex.indexByColumnRow(
                columnIndex: i + 6, rowIndex: rowIndex))
            .value = TextCellValue(userData.eventsList[i]);
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
        if(Platform.isAndroid){
        final file = File('storage/emulated/0/Download/NHS_Members_Report.xlsx');
        await file.writeAsBytes(fileBytes);
        }
        else if (Platform.isIOS) {
        final Directory Dir = await getApplicationDocumentsDirectory();
        final file = File('${Dir.path}}/NHS_Members_Report.xlsx');
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

class LeaderboardPage extends StatefulWidget {
  final String currentUserId;

  const LeaderboardPage({Key? key, required this.currentUserId}) : super(key: key);

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
      final profilesResponse = await supabase.from('profiles').select('user_id, name');

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

        if (userName == 'Unknown User'){
          print(userId);
        }

        
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
        backgroundColor: Theme.of(context)
            .bannerTheme
            .backgroundColor,
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
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).colorScheme.primaryContainer,
                            Theme.of(context).colorScheme.surface,
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Top Contributors',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_rankings.isNotEmpty) _buildTopThree(),
                        ],
                      ),
                    ),
                    if (_rankings.length > 3) ...[
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Runner Ups',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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
                    if (_currentUserRanking != null && _currentUserRanking!.rank > 10)
                      Column(
                        children: [
                          const Divider(),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _buildRankingTile(_currentUserRanking!),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

class UserRanking {
  final String userId;
  final String name;
  double totalHours; // Removed final
  int rank;

  UserRanking({
    required this.userId,
    required this.name,
    this.totalHours = 0, // Added default value
    required this.rank,
  });
}

/// Creates a progress bar widget for displaying hour completion status.
///
/// Parameters:
/// - context: BuildContext
/// - title: String - Progress bar label
/// - completedHours: double - Current hours
/// - hoursNeeded: int - Target hours
///
/// Returns:
/// - Widget
Widget _buildProgressBar(
  context,
  String title,
  double completedHours,
  int hoursNeeded,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title: ${completedHours.toStringAsFixed(2)} hours',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: completedHours / hoursNeeded,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary),
          minHeight: 10,
          borderRadius: const BorderRadius.all(Radius.circular(33)),
        ),
      ],
    ),
  );
}

class CompletedHoursPage extends StatefulWidget {
  const CompletedHoursPage({super.key});

  @override
  _CompletedHoursPageState createState() => _CompletedHoursPageState();
}

class _CompletedHoursPageState extends State<CompletedHoursPage> {
  double _serviceHoursCompleted = 0;
  double _tutoringHoursCompleted = 0;
  double _meetingHoursCompleted = 0;
  List<CompletedHour> _completedServiceHours = [];
  List<CompletedHour> _completedTutoringHours = [];
  List<CompletedHour> _completedMeetingHours = [];

  List<MeetingNote> _meetingNotes = [];

  @override
  void initState() {
    super.initState();
    _fetchCompletedHours();
    _fetchMeetingNotes();
  }

  /// Retrieves all meeting notes from the database.
  /// Orders notes by creation date.
  ///
  /// Returns:
  /// - Future<void>
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

  Future<void> _fetchCompletedHours() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;

    final response = await Supabase.instance.client
        .from('Service hours')
        .select('hours, type, event_name, date')
        .eq('user_id', userId as String);

    final data = response;
    double serviceHours = 0;
    double tutoringHours = 0;
    double meetingHours = 0;
    List<CompletedHour> serviceHoursList = [];
    List<CompletedHour> tutoringHoursList = [];
    List<CompletedHour> meetingHoursList = [];

    for (final entry in data) {
      final hours = entry['hours'] + 0.0 ?? 0.0;
      final eventType = entry['type'] as String?;
      final eventName = entry['event_name'] as String?;
      final dateString = entry['date'] as String?;
      final date = DateTime(0);

      if (dateString != null) {
        final date = DateTime.parse(dateString);
      }

      if (eventType == 'Service' || eventType == 'Service') {
        serviceHours += hours;
        serviceHoursList.add(CompletedHour(
          title: eventName ?? 'Unknown Event',
          date: date,
          hours: hours,
        ));
      } else if (eventType == 'Tutoring' || eventType == 'tutoring') {
        tutoringHours += hours;
        tutoringHoursList.add(CompletedHour(
          title: eventName ?? 'Unknown Event',
          date: date,
          hours: hours,
        ));
      } else if (eventType == 'Meeting' || eventType == 'meeting') {
        meetingHours += hours;
        meetingHoursList.add(CompletedHour(
          title: eventName ?? 'Unknown Event',
          date: date,
          hours: hours,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _serviceHoursCompleted = serviceHours;
        _tutoringHoursCompleted = tutoringHours;
        _meetingHoursCompleted = meetingHours;
        _completedServiceHours = serviceHoursList;
        _completedTutoringHours = tutoringHoursList;
        _completedMeetingHours = meetingHoursList;
      });
    }
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
        backgroundColor: Theme.of(context)
            .bannerTheme
            .backgroundColor,
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            onPressed: _openLeaderboard,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                leading: const Icon(Icons.notes),
                title: const Text('Meeting Notes'),
                onTap: _showMeetingNotesDialog,
              ),
            ),
            _buildProgressBar(
                context, 'Service Hours', _serviceHoursCompleted, 14),
            _buildCompletedHoursList(_completedServiceHours),
            const SizedBox(height: 20),
            _buildProgressBar(
                context, 'Tutoring Hours', _tutoringHoursCompleted, 6),
            _buildCompletedHoursList(_completedTutoringHours),
            const SizedBox(height: 20),
            _buildProgressBar(
                context, 'Meeting Hours', _meetingHoursCompleted, 5),
            _buildCompletedHoursList(_completedMeetingHours),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Open the website when the button is pressed
          _openWebsite();
        },
        child: const Icon(Icons.report_problem),
      ),
    );
  }

  Widget _buildCompletedHoursList(List<CompletedHour> hours) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListView.builder(
              shrinkWrap: true,
              itemCount: hours.length,
              itemBuilder: (context, index) {
                final hour = hours[index];
                if (hour.date.year == 0) {
                  return Card(
                      child: ListTile(
                    title: Text(hour.title),
                    subtitle: Text('${hour.hours.toStringAsFixed(2)} hours'),
                  ));
                } else {
                  return Card(
                      child: ListTile(
                    title: Text(hour.title),
                    subtitle: Text(
                        '${hour.date.month}-${hour.date.day}-${hour.date.year} - ${hour.hours.toStringAsFixed(2)} hours'),
                  ));
                }
              },
            ),
          ],
        ));
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

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    loadThemePreference();
  }

  /// Toggles between light and dark theme modes.
  /// Updates SharedPreferences and notifies listeners.
  ///
  /// Returns:
  /// - void
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
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
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  /// Persists current theme preference to SharedPreferences.
  ///
  /// Returns:
  /// - Future<void>
  Future<void> saveThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

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

  @override
  void initState() {
    super.initState();
    _name = '';
    _email = '';
    _graduationYear = '';
    _password = '';
    _fetchUserProfile();
    _fetchThemeColorFromPrefs();
  }

  Future<void> _fetchThemeColorFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('themeColor');
    setState(() {
      _selectedColor = colorValue != null ? Color(colorValue) : Colors.blue;
    });
  }

  /// Retrieves user profile information from database.
  /// Updates UI state with fetched data.
  ///
  /// Returns:
  /// - Future<void>
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

  /// Updates user profile information in database.
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _updateUserProfile() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;

    if (userId != null) {
      await Supabase.instance.client.from('profiles').update({
        'graduation_year': int.tryParse(_graduationYear) ?? 0,
      }).eq('user_id', userId);
    }
  }

  /// Updates app theme color and saves preference.
  ///
  /// Parameters:
  /// - color: Color - New theme color
  ///
  /// Returns:
  /// - void
  void _handleColorChange(Color color) {
    setState(() {
      _selectedColor = color;
    });
    _saveThemeColorToPrefs(color);
    Provider.of<ThemeNotifier>(context, listen: false).updateThemeColor(color);
  }

  /// Persists theme color choice to SharedPreferences.
  ///
  /// Parameters:
  /// - color: Color - Theme color to save
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _saveThemeColorToPrefs(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', color.value);
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
                MaterialPageRoute(builder: (context) => const SocietySelectionPage()),
                (route) => false,
              );
            },
          ),
        elevation: 0,
        backgroundColor: Theme.of(context)
            .bannerTheme
            .backgroundColor,
        title: Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    keyboardType:
                        const TextInputType.numberWithOptions(),
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
                  const SizedBox(height: 24.0),
                  ListTile(
                    leading: const Icon(Icons.color_lens),
                    title: const Text('Theme Color'),
                    trailing: CircleAvatar(
                      backgroundColor: _selectedColor,
                    ),
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
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: Provider.of<ThemeProvider>(context).isDarkMode,
                    onChanged: (_) {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .toggleTheme();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),
            BarcodeWidget(
              barcode: barcodeGen.Barcode.qrCode(),
              data: supabase.auth.currentUser?.id ?? '',
              width: 200,
              height: 200,
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

  /// Handles user sign-out process.
  /// Clears session data and navigates to login page.
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionData');
    await supabase.auth.signOut();
    Navigator.pushReplacementNamed(context, '/');
  }
}

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({Key? key}) : super(key: key);

  @override
  _AdminEventsPageState createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  final _formKey = GlobalKey<FormState>();
  List<Event> _events = [];
  List<Collection> _collections = [];
  Event? _draggedEvent;
  int? _hoveredCollectionIndex;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _fetchCollections();
  }

  Future<void> _fetchEvents() async {
  try {
    // 1. Fetch all events in a single query
    final eventResponse = await Supabase.instance.client
      .from('Events')
      .select('''
        *,
        time_slots:"Time slots" (
          *
        )
      ''')
      .order('date');

    // Create events map for quick lookups
    final Map<int, Event> eventsMap = {
      for (var json in eventResponse)
        json['id']: Event.fromJson(json)
    };

    // Create time slots map and event-to-timeslots map
    final Map<int, TimeSlot> timeSlotsMap = {};
    final Map<int, List<int>> eventToTimeSlots = {};

    // Process time slots from the nested response
    for (var eventJson in eventResponse) {
      final eventId = eventJson['id'] as int;
      final timeSlots = eventJson['time_slots'] as List<dynamic>;
      
      eventToTimeSlots[eventId] = [];
      
      for (var timeSlotJson in timeSlots) {
        final timeSlot = TimeSlot.fromJson(timeSlotJson);
        timeSlotsMap[timeSlot.id!] = timeSlot;
        eventToTimeSlots[eventId]!.add(timeSlot.id!);
      }
    }

    // 2. Fetch all attendees with their profiles in a single query
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
        event.timeSlots = timeSlotIds
          .map((id) => timeSlotsMap[id]!)
          .toList();
        assembledEvents.add(event);
      }
    }

    if (mounted) {
      setState(() {
        _events = assembledEvents;
      });
    }
  } catch (e) {
    print('Error fetching events: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading events: $e')),
      );
    }
  }
}


  Future<void> _fetchCollections() async {
    final response =
        await Supabase.instance.client.from('Collections').select('*');

    final List<dynamic> data = response;
    if (mounted){setState(() {
      _collections = data.map((json) => Collection.fromJson(json)).toList();
    });
    }
    
  }

  @override
  Widget build(BuildContext context) {
    final uncategorizedEvents =
        _events.where((event) => event.collectionId == null).toList();
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context)
            .bannerTheme
            .backgroundColor,
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
      body: ListView.builder(
        itemCount: _collections.length + uncategorizedEvents.length,
        itemBuilder: (context, index) {
          if (index < _collections.length) {
            final collection = _collections[index];
            return _buildCollectionCard(collection, index);
          } else {
            final event = uncategorizedEvents[index - _collections.length];
            return _buildEventCard(event);
          }
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _showAddEventDialog,
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: _showAddCollectionDialog,
            child: const Icon(Icons.create_new_folder),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(Collection collection, int index) {
  final isHovered = _hoveredCollectionIndex == index;

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isHovered ? Colors.grey[200] : null,
        child: ExpansionTile(
          leading: const Icon(Icons.folder),
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
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _showDeleteCollectionDialog(collection),
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ),
          children: _events
              .where((event) => event.collectionId == collection.id)
              .map((event) => _buildEventCard(event))
              .toList(),
        ),
      );
    },
  );
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
        .update({'collection_id': null})
        .eq('collection_id', collection.id);

    // Then delete the collection
    await supabase
        .from('Collections')
        .delete()
        .eq('id', collection.id);

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
  Widget _buildEventCard(Event event) {
    final bool isNew = event.createdAt
        .isAfter(DateTime.now().subtract(const Duration(days: 7)));
    final bool isMandatory = event.isMandatory;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Draggable<Event>(
        data: event,
        child: Stack(
          children: [
            if (isMandatory)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Mandatory',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else if (isNew)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
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
              title: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "${event.name} - ${event.date.month}/${event.date.day}/${event.date.year}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.0,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditEventDialog(event),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteEvent(event),
                        ),
                      ],
                    ),
                    Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              children: event.timeSlots.map((timeSlot) {
                return ListTile(
                  title: Text(
                    'Time: ${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
                    style: const TextStyle(fontSize: 16.0),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Number of People: ${timeSlot.numberOfPeople}',
                        style:
                            TextStyle(fontSize: 14.0, color: Colors.grey[600]),
                      ),
                      Text(
                        'Attendees: ${timeSlot.attendees.length}',
                        style:
                            TextStyle(fontSize: 14.0, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditTimeSlotDialog(event, timeSlot),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        feedback: Material(
          elevation: 4.0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              event.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      fontSize: 14.0,
                    ),
                  ),
                  subtitle: Text(
                    event.description,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _showEditEventDialog(event);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deleteEvent(event);
                        },
                      ),
                    ],
                  ),
                ),
                children: event.timeSlots.map((timeSlot) {
                  return ListTile(
                    title: Text(
                      'Time: ${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
                      style: const TextStyle(
                        fontSize: 16.0,
                      ),
                    ),
                    subtitle: Text(
                      'Number of People: ${timeSlot.numberOfPeople}',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.notes),
                      onPressed: () {
                        _showEditNotesDialog(event, timeSlot);
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        onDragStarted: () => _onEventDragStarted(event),
        onDragEnd: (details) {
          if (event.collectionId != null) {
            _onEventDropped(event, null);
          }
        },
      ),
    );
  }

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
                      DropdownButtonFormField<String>(
                        value: _selectedEventType,
                        items: ['Service', 'Tutoring', 'Meeting']
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
                      keyboardType:
                          const TextInputType.numberWithOptions(),
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
                        value: _selectedEventType,
                        items: ['Service', 'Tutoring', 'Meeting']
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
      },
    );
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
                  keyboardType:
                      const TextInputType.numberWithOptions(),
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

        // If the event is mandatory, add all users as attendees
        if (isMandatory || type == "Meeting") {
          final usersResponse =
              await Supabase.instance.client.from('profiles').select('user_id');

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
    this.swapRequestDeadline =
        const Duration(days: 1),
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
        hasDelay : hasDelay ?? this.hasDelay,
        delayHours : delayHours ?? this.delayHours,
        swapRequestDeadline: swapRequestDeadline ?? this.swapRequestDeadline);
        
  }
  
}

extension UserRequirementsCheck on UserProfile {
  bool hasMetRequirements(String eventType) {
    double serviceHours = 0;
    double tutoringHours = 0;
    double meetingHours = 0;

    for (final hour in completedHours) {
      if (hour.type == 'Service') {
        serviceHours += hour.hours;
      } else if (hour.type == 'Tutoring') {
        tutoringHours += hour.hours;
      } else if (hour.type == 'Meeting') {
        meetingHours += hour.hours;
      }
    }

    switch (eventType) {
      case 'Service':
        return serviceHours >= 14;
      case 'Tutoring':
        return tutoringHours >= 6;
      case 'Meeting':
        return meetingHours >= 5;
      default:
        return false;
    }
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
    } finally {
      if (mounted){
        setState(() {
        _isLoading = false;
      });
      }
    }
  }

  Future<void> _fetchEvents() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 1. Fetch all events in single query
      final eventResponse = await Supabase.instance.client
          .from('Events')
          .select()
          .order('date');
      
      // Create events map for quick lookups
      final Map<int, Event> eventsMap = {
        for (var json in eventResponse) 
          json['id']: Event.fromJson(json)
      };

      // 2. Fetch all time slots for these events in a single query
      final timeSlotResponse = await Supabase.instance.client
          .from('Time slots')
          .select()
          .inFilter('event_id', eventsMap.keys.toList());

      // Create time slots map for quick lookups
      final Map<int, TimeSlot> timeSlotsMap = {
        for (var json in timeSlotResponse) 
          json['id']: TimeSlot.fromJson(json)
      };

      // Create a map of event_id to list of time slot ids
      final Map<int, List<int>> eventToTimeSlots = {};
      for (var timeSlot in timeSlotResponse) {
        final eventId = timeSlot['event_id'] as int;
        eventToTimeSlots.putIfAbsent(eventId, () => []).add(timeSlot['id'] as int);
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
          event.timeSlots = timeSlotIds
              .map((id) => timeSlotsMap[id]!)
              .toList();
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
    final collectionsResponse =
        await Supabase.instance.client.from('Collections').select('*');

    setState(() {
      _collections = collectionsResponse
          .map<Collection>((json) => Collection.fromJson(json))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context)
            .bannerTheme
            .backgroundColor,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView.separated(
                itemCount: _events.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final event = _events[index];
                  return _buildEventCard(event);
                },
              ),
            ),
    );
  }

  /// Creates a card widget displaying event details.
  /// Includes event information, time slots, and action buttons.
  ///
  /// Parameters:
  /// - event: Event - Event to display
  ///
  /// Returns:
  /// - Widget
  Widget _buildEventCard(Event event) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CustomExpansionTile(
        title: ListTile(
          title: Text(
            "${event.name} - ${event.date.month}/${event.date.day}/${event.date.year}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.0,
            ),
          ),
          subtitle: Text(
            event.description,
            style: TextStyle(
              fontSize: 16.0,
              color: Colors.grey[600],
            ),
          ),
        ),
        children: event.timeSlots.map((timeSlot) {
          
          return ListTile(
            title: Text(
              'Time: ${_formatTimeOfDay(timeSlot.time)} - ${_formatTimeOfDay(timeSlot.endTime)}',
              style: const TextStyle(
                fontSize: 16.0,
              ),
            ),
            subtitle: Text(
              'Number of People: ${timeSlot.numberOfPeople}',
              style: TextStyle(
                fontSize: 14.0,
                color: Colors.grey[600],
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.checklist_outlined,
                color: Theme.of(context).colorScheme.secondary,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AttendanceCheckPage(event: event, timeSlot: timeSlot),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Creates a card widget displaying event details.
  /// Includes event information, time slots, and action buttons.
  ///
  /// Parameters:
  /// - event: Event - Event to display
  ///
  /// Returns:
  /// - Widget
  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dateTime =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return TimeOfDay.fromDateTime(dateTime).format(context);
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

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _users.clear();
    });

    try {
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .order('name');

      final hoursResponse = await Supabase.instance.client
          .from('Service hours')
          .select('user_id, event_name, hours, type');

      Map<String, List<CompletedUserHour>> userHoursMap = {};
      for (final hourData in hoursResponse) {
        final userId = (hourData['user_id'] ?? "{eventName: 'none', hours: 0, type: 'none'}") as String;
        final hour = CompletedUserHour.fromJson(hourData);
        userHoursMap.putIfAbsent(userId, () => []).add(hour);
      }

      if (mounted) {
        setState(() {
          _users.addAll(
            profileResponse.map<UserProfile>((profileJson) {
              final userId = profileJson['user_id'] as String;
              return UserProfile(
                name: (profileJson['name'] ?? "") as String,
                id: userId,
                completedHours: userHoursMap[userId] ?? [],
                hasPaidDues: profileJson['has_paid_dues'] ?? false,
              );
            }).toList(),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching users: $e')),
        );
      }
    }
  }

  Future<void> _toggleDuesStatus(UserProfile user) async {
  try {
    await Supabase.instance.client
        .from('profiles')
        .update({'has_paid_dues': !user.hasPaidDues})
        .eq('user_id', user.id);

    // Refresh the user list to reflect the change
    await _fetchUsers();

    
    if(mounted) { ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          user.hasPaidDues ? 'Dues marked as unpaid' : 'Dues marked as paid',
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

  List<UserProfile> _getFilteredAndSortedUsers() {
    List<UserProfile> filteredUsers = _users;

    if (_searchQuery.isNotEmpty) {
      final lowercaseQuery = _searchQuery.toLowerCase();
      filteredUsers = filteredUsers.where((user) {
        final lowercaseName = user.name.toLowerCase();
        return lowercaseName.contains(lowercaseQuery);
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
          comparison = _getHoursByType(a, 'Service')
              .compareTo(_getHoursByType(b, 'Service'));
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
        .where((hour) => hour.type == type)
        .fold(0.0, (sum, hour) => sum + hour.hours);
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
                        _buildSortChip(
                            SortField.tutoringHours, 'Tutoring Hours', setState),
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

  Widget _buildOrderChip(SortOrder order, String label, StateSetter setState) {
    return FilterChip(
      selected: _sortOrder == order,
      label: Text(label),
      onSelected: (selected) {
        if (selected) {
          setState(() => _sortOrder = order);
          this.setState(() {});
        }
      },
    );
  }

  void _openCustomEventForm(BuildContext context, String userId,
      {String eventName = '',
      TimeOfDay? selectedTime,
      double hours = 0,
      String type = 'Service'}) {
    showDialog(
      context: context,
      builder: (context) {
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
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true, decimal: true),
                onChanged: (value) {
                  hours = double.tryParse(value) ?? 0.0;
                },
              ),
              DropdownButtonFormField<String>(
                value: type,
                onChanged: (value) {
                  type = value ?? "Service";
                },
                borderRadius: BorderRadius.circular(30),
                dropdownColor: Theme.of(context).colorScheme.primaryContainer,
                items: const [
                  DropdownMenuItem(
                    value: 'Service',
                    child: Text('Service'),
                  ),
                  DropdownMenuItem(
                    value: 'Tutoring',
                    child: Text('Tutoring'),
                  ),
                  DropdownMenuItem(
                    value: 'Meeting',
                    child: Text('Meeting'),
                  ),
                ],
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
                if (selectedTime != null) {
                  String timeSlot =
                      '${selectedTime.hour}:${selectedTime.minute}';
                  _saveCustomEvent(userId, eventName, timeSlot,
                      hours.toDouble(), type); // Pass userId directly
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
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
  Future<void> _saveCustomEvent(
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

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredAndSortedUsers();
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context)
            .bannerTheme
            .backgroundColor,
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
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showSortOptions,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BulkEditEventsPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.file_download,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              exportToExcel(context, filteredUsers);
            },
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
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
                ),
                const SizedBox(width: 16.0),
                ElevatedButton.icon(
                  onPressed: () {
                    _openBulkCustomEventForm(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Bulk'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: filteredUsers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 0),
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                return _buildUserCard(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserProfile user) {
  final serviceHours = _getHoursByType(user, 'Service');
  final tutoringHours = _getHoursByType(user, 'Tutoring');
  final meetingHours = _getHoursByType(user, 'Meeting');

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
          '${_getTotalHours(user).toStringAsFixed(1)} ' +
          '(S: ${serviceHours.toStringAsFixed(1)}, ' +
          'T: ${tutoringHours.toStringAsFixed(1)}, ' +
          'M: ${meetingHours.toStringAsFixed(1)})',
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
      children: user.completedHours.map((hour) {
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
        backgroundColor: Theme.of(context)
            .bannerTheme
            .backgroundColor,
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

  List<UserProfile> get filteredUsers {
    return widget.users.where((user) {
      final lowercaseName = user.name.toLowerCase();
      final lowercaseQuery = searchQuery.toLowerCase();
      return lowercaseName.contains(lowercaseQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Bulk Custom Event'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Event Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        eventName = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: type,
                          onChanged: (value) {
                            setState(() {
                              type = value ?? "Service";
                            });
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'Service',
                              child: Text('Service'),
                            ),
                            DropdownMenuItem(
                              value: 'Tutoring',
                              child: Text('Tutoring'),
                            ),
                            DropdownMenuItem(
                              value: 'Meeting',
                              child: Text('Meeting'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Event Type',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                            );
                            if (pickedTime != null) {
                              setState(() {
                                selectedTime = pickedTime;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(selectedTime != null
                              ? selectedTime!.format(context)
                              : 'Time'),
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: TextFormField(
                          initialValue: hours.toString(),
                          decoration: InputDecoration(
                            labelText: 'Hours',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(signed: true,
                              decimal: true),
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
            const SizedBox(height: 16.0),
            TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'Search Members',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  final isSelected = selectedUserIds.contains(user.id);

                  bool isFirstItem = index == 0;
                  bool isLastItem = index == filteredUsers.length - 1;
                  bool isPrevSelected = isFirstItem
                      ? false
                      : selectedUserIds.contains(filteredUsers[index - 1].id);
                  bool isNextSelected = isLastItem
                      ? false
                      : selectedUserIds.contains(filteredUsers[index + 1].id);

                  BorderRadius borderRadius = BorderRadius.zero;
                  if (!isSelected) {
                  } else if (isSelected && isNextSelected) {
                    if (isPrevSelected) {
                      borderRadius =
                          const BorderRadius.all((Radius.circular(6)));
                    } else {
                      borderRadius = const BorderRadius.vertical(
                          top: Radius.circular(15), bottom: Radius.circular(6));
                    }
                  } else if (isSelected && isPrevSelected) {
                    borderRadius = const BorderRadius.vertical(
                        bottom: Radius.circular(15), top: Radius.circular(6));
                  } else {
                    borderRadius = const BorderRadius.all(Radius.circular(15));
                  }

                  return Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          borderRadius: borderRadius,
                        ),
                        child: CheckboxListTile(
                          title: Text(user.name),
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value!) {
                                selectedUserIds.add(user.id);
                              } else {
                                selectedUserIds.remove(user.id);
                              }
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2.0),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            backgroundColor: Theme.of(context).colorScheme.secondary,
            child: Icon(Icons.cancel_outlined,
                color: Theme.of(context).colorScheme.surfaceContainerHighest),
          ),
          const SizedBox(width: 16.0),
          FloatingActionButton(
            onPressed: () {
              if (selectedTime != null) {
                String timeSlot =
                    '${selectedTime!.hour}:${selectedTime!.minute}';
                _saveBulkCustomEvent(
                  selectedUserIds,
                  eventName,
                  timeSlot,
                  hours,
                  type,
                );
              }
            },
            child: Icon(
              Icons.save,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Creates multiple custom events for selected users.
  ///
  /// Parameters:
  /// - userIds: List<String> - Target users
  /// - eventName: String - Event name
  /// - timeSlot: String - Time slot
  /// - hours: double - Hours to credit
  /// - type: String - Event type
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _saveBulkCustomEvent(
    List<String> userIds,
    String eventName,
    String timeSlot,
    double hours,
    String type,
  ) async {
    try {
      final List<Map<String, dynamic>> bulkEvents = userIds.map((userId) {
        return {
          'user_id': userId,
          'event_name': eventName,
          'timeslot': timeSlot,
          'hours': hours.toDouble(),
          'type': type,
        };
      }).toList();

      await Supabase.instance.client.from('Service hours').insert(bulkEvents);

      // Show a success message using toastification
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.simple,
        title: const Text("Bulk custom event saved successfully"),
        description: const Text(""),
        alignment: Alignment.center,
        autoCloseDuration: const Duration(seconds: 3),
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: lowModeShadow,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      );

      // Return true to indicate successful saving
      Navigator.of(context).pop(true);
    } catch (error) {
      // Show an error message using toastification
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.simple,
        title: const Text("Failed to save bulk custom event"),
        description: const Text(""),
        alignment: Alignment.center,
        autoCloseDuration: const Duration(seconds: 3),
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: lowModeShadow,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      );
    }
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
      // Fetch all service hours in a single query with user profiles
      final response = await supabase
          .from('Service hours')
          .select('*, profiles:user_id(name)')
          .order('event_name');

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
      final List<CustomEventGroup> eventGroups = groupedEvents.entries.map((entry) {
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

      print('Fetched ${eventGroups.length} event groups'); // Debug print
    } catch (e) {
      print('Error fetching custom events: $e');
      setState(() => _isLoading = false);
    }
  }

  List<CustomEventGroup> get _filteredEventGroups {
    if (_searchQuery.isEmpty) return _eventGroups;
    
    final query = _searchQuery.toLowerCase();
    return _eventGroups.where((group) =>
      group.eventName.toLowerCase().contains(query) ||
      group.type.toLowerCase().contains(query)
    ).toList();
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

      // Format time for database
      String? formattedTime;
      if (_newStartTime != null) {
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

        // Update all records for this event
        await supabase
          .from('Service hours')
          .update(updateData)
          .match({
            'event_name': eventName
          });
      }

      // Hide loading indicator
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully updated ${_selectedEvents.length} events',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Log the bulk update activity
      final timeSlotDisplay = _newStartTime != null ? _newStartTime : 'Various Times';

      await _logActivity(
        _newEventName.isEmpty ? 'Multiple Events' : _newEventName,
        timeSlotDisplay,
        _newHours == 0 ? 0 : _newHours,
        'bulk_update',
        supabase.auth.currentUser?.id ?? '',
      );

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating events: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSelectedEvents() async {
    if (_selectedEvents.isEmpty) return;

    try {
      // Delete all selected events in a single query
      await supabase
          .from('Service hours')
          .delete()
          .inFilter('event_name', _selectedEvents.toList());

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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
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
                  _newStartTime = '${selectedTime!.hour}:${selectedTime!.minute}';
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
                        value: _selectedEvents.length == _filteredEventGroups.length && 
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
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
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

  HourRequirement({
    required this.id,
    required this.type,
    required this.hoursNeeded,
    required this.description,
    this.isActive = true,
  });

  factory HourRequirement.fromJson(Map<String, dynamic> json) {
    return HourRequirement(
      id: json['id'],
      type: json['type'],
      hoursNeeded: json['hours_needed'].toDouble(),
      description: json['description'],
      isActive: json['is_active'] ?? true,
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
              child: isWideScreen
                  ? _buildWideLayout()
                  : _buildCompactLayout(),
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

  Widget _buildCategoryCard(String title, double hours, IconData icon, Color color, {required bool isCompact}) {
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
                Expanded(child: _buildActionButton('Add Notes', Icons.note_add, _showAddNotesDialog)),
                const SizedBox(width: 16),
                Expanded(child: _buildActionButton('View Notes', Icons.notes, _showMeetingNotesDialog)),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    'Activity Log',
                    Icons.history,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ActivityLogPage()),
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
                      _buildActionButton('Add Notes', Icons.note_add, _showAddNotesDialog),
                      const SizedBox(height: 8),
                      _buildActionButton('View Notes', Icons.notes, _showMeetingNotesDialog),
                      const SizedBox(height: 8),
                      _buildActionButton(
                        'Activity Log',
                        Icons.history,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ActivityLogPage()),
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

Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
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
    child: isWideScreen ? Row(
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
    ) : Row(
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

Widget _buildCategoryCard(String title, double hours, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: border.Border.all(
          color: color.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${hours.toStringAsFixed(1)}h',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

class UserProfile {
  final String name;
  final String id;
  final List<CompletedUserHour> completedHours;
  final bool hasPaidDues;  // New field

  UserProfile({
    required this.name,
    required this.completedHours,
    required this.id,
    this.hasPaidDues = false,  // Default to false
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
      final response = await supabase
          .from('activity_logs')
          .select('*, profiles:user_id(name)')
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                            _selectedDate = _selectedDate.subtract(const Duration(days: 1));
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
                                  _selectedDate = _selectedDate.add(const Duration(days: 1));
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
            style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSecondaryContainer),
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
Future<void> _logActivity(String eventName, String timeslot, double hours,
    String actionType, String userId,
    {String? oldUserId, String? newUserId}) async {
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
    });
  } catch (e) {
    print('Error logging activity: $e');
  }
}

class HourRequirementsPage extends StatefulWidget {
  final HonorSociety society;

  const HourRequirementsPage({super.key, required this.society});

  @override
  _HourRequirementsPageState createState() => _HourRequirementsPageState();
}

class _HourRequirementsPageState extends State<HourRequirementsPage> {
  List<HourRequirement> _requirements = [];

  @override
  void initState() {
    super.initState();
    _requirements = List.from(widget.society.hourRequirements);
  }

  // Add this method to _HourRequirementsPageState
void _showEditRequirementDialog(HourRequirement requirement) {
  String type = requirement.type;
  String description = requirement.description;
  double hours = requirement.hoursNeeded;
  bool isActive = requirement.isActive;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Hour Requirement'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Type Name'),
            controller: TextEditingController(text: type),
            onChanged: (value) => type = value,
          ),
          TextField(
            decoration: const InputDecoration(labelText: 'Description'),
            controller: TextEditingController(text: description),
            onChanged: (value) => description = value,
          ),
          TextField(
            decoration: const InputDecoration(labelText: 'Hours Required'),
            controller: TextEditingController(text: hours.toString()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => hours = double.tryParse(value) ?? hours,
          ),
          SwitchListTile(
            title: const Text('Active'),
            value: isActive,
            onChanged: (value) => isActive = value,
          ),
        ],
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
              await supabase
                  .from('hour_requirements')
                  .update({
                    'type': type,
                    'description': description,
                    'hours_needed': hours,
                    'is_active': isActive,
                  })
                  .eq('id', requirement.id);

              setState(() {
                final index = _requirements.indexWhere((r) => r.id == requirement.id);
                if (index != -1) {
                  _requirements[index] = HourRequirement(
                    id: requirement.id,
                    type: type,
                    description: description,
                    hoursNeeded: hours,
                    isActive: isActive,
                  );
                }
              });
              Navigator.pop(context);
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
            await supabase
                .from('hour_requirements')
                .delete()
                .eq('id', requirement.id);

            setState(() {
              _requirements.removeWhere((r) => r.id == requirement.id);
            });
            Navigator.pop(context); // Close delete confirmation
            Navigator.pop(context); // Close edit dialog
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Type Name'),
              onChanged: (value) => type = value,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (value) => description = value,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Hours Required'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) => hours = double.tryParse(value) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (type.isNotEmpty && hours > 0) {
                final response = await supabase
                    .from('hour_requirements')
                    .insert({
                      'society_id': widget.society.id,
                      'type': type,
                      'description': description,
                      'hours_needed': hours,
                    })
                    .select()
                    .single();

                setState(() {
                  _requirements.add(HourRequirement.fromJson(response));
                });
                Navigator.pop(context);
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
      appBar: AppBar(
        title: const Text('Hour Requirements'),
      ),
      body: ListView.builder(
        itemCount: _requirements.length,
        itemBuilder: (context, index) {
          final requirement = _requirements[index];
          return ListTile(
            title: Text(requirement.type),
            subtitle: Text(requirement.description),
            trailing: Text('${requirement.hoursNeeded} hours'),
            onTap: () => _showEditRequirementDialog(requirement),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRequirementDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class SocietyJoinRequestPage extends StatefulWidget {
  const SocietyJoinRequestPage({super.key});

  @override
  _SocietyJoinRequestPageState createState() => _SocietyJoinRequestPageState();
}

class _SocietyJoinRequestPageState extends State<SocietyJoinRequestPage> {
  List<HonorSociety> _availableSocieties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAvailableSocieties();
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

    // Fetch societies user is not a member of, including their requirements
    final societies = await supabase
        .from('honor_societies')
        .select('''
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
        ''')
        .not('id', 'in', memberSocietyIds.isEmpty ? [''] : memberSocietyIds);

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

  Future<void> _requestJoin(HonorSociety society) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('society_join_requests').insert({
        'user_id': userId,
        'society_id': society.id,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Join request sent successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending request: $e')),
        );
      }
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
              : ListView.builder(
                  itemCount: _availableSocieties.length,
                  itemBuilder: (context, index) {
                    final society = _availableSocieties[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: society.imageUrl != null
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(society.imageUrl!),
                              )
                            : CircleAvatar(
                                child: Text(society.name[0]),
                              ),
                        title: Text(society.name),
                        subtitle: Text(society.description),
                        trailing: ElevatedButton(
                          onPressed: () => _requestJoin(society),
                          child: const Text('Request Join'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class SocietySelectionPage extends StatefulWidget {
  const SocietySelectionPage({super.key});

  @override
  _SocietySelectionPageState createState() => _SocietySelectionPageState();
}

class _SocietySelectionPageState extends State<SocietySelectionPage> {
  List<HonorSociety> _societies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserSocieties();
  }

  Future<void> _fetchUserSocieties() async {
  setState(() => _isLoading = true);

  try {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Fetch societies with their hour requirements in a single query
    final societies = await supabase
        .from('user_society_memberships')
        .select('''
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
        ''')
        .eq('user_id', userId);

    if (mounted) {
      setState(() {
        _societies = societies.map<HonorSociety>((membership) {
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
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Honor Society'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _societies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'You are not a member of any honor societies',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SocietyJoinRequestPage()),
                            );
                        },
                        child: const Text('Request to Join'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _societies.length,
                  itemBuilder: (context, index) {
                    final society = _societies[index];
                    return _buildSocietyCard(society);
                  },
                ),
    );
  }

  Widget _buildSocietyCard(HonorSociety society) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Store selected society in state management
          // and navigate to main screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(society: society),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: society.imageUrl != null
                  ? Image.network(
                      society.imageUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Center(
                        child: Icon(
                          Icons.school,
                          size: 48,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    society.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    society.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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