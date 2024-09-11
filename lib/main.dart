import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:bottom_navy_bar/bottom_navy_bar.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:toastification/toastification.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:barcode/barcode.dart' as barcodeGen;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hcuygigxjucxutavjvsc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhjdXlnaWd4anVjeHV0YXZqdnNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTI4NzU1NjgsImV4cCI6MjAyODQ1MTU2OH0.0x6jIeOANj6_Y5s7EQ9tuU3GhZLZblobDAt_W2dOLJA',
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

  const MyApp({Key? key, required this.themeNotifier}) : super(key: key);

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
            return MaterialApp(
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
                      '/': (context) => LoginPage(),
                      '/main': (context) => MainScreen(),
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

  Future<void> _fetchUserThemeColor(ThemeNotifier themeNotifier) async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('themeColor');
    final color = colorValue != null ? Color(colorValue) : Colors.blue;
    themeNotifier.updateThemeColor(color);
  }
}
class MainScreen extends StatefulWidget {
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

  Future<void> _fetchUserAdminStatus() async {
  final User? user = supabase.auth.currentUser;
  final userId = user?.id;

  if (userId != null) {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('admin')
        .eq('user_id', userId);

    if (response != null && response.length > 0) {
      if (mounted){
      setState(() {
        _isAdmin = response[0]['admin'] ?? false;
      });
      }
    }
  }
}

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
          title: Text('Total Hours'),
          icon: Icon(Icons.home),
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.onSurface,
        ),
        BottomNavyBarItem(
          title: Text('Add'),
          icon: Icon(Icons.add_circle),
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.onSurface,
        ),
        BottomNavyBarItem(
          title: Text('Attendance'),
          icon: Icon(Icons.check_circle),
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.onSurface,
        ),
        BottomNavyBarItem(
          title: Text('List'),
          icon: Icon(Icons.view_list),
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.onSurface,
        ),
         BottomNavyBarItem(
          title: Text('Profile'),
          icon: Icon(Icons.account_circle),
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.onSurface,
        ),
      ] else ...[
        BottomNavyBarItem(
        title: Text('Home'),
        icon: Icon(Icons.home),
        activeColor: Theme.of(context).colorScheme.primary,
        inactiveColor: Theme.of(context).colorScheme.onSurface,
        ),
        BottomNavyBarItem(
        title: Text('Hours'),
        icon: Icon(Icons.watch_later),
        activeColor: Theme.of(context).colorScheme.primary,
        inactiveColor: Theme.of(context).colorScheme.onSurface,
      ),
        BottomNavyBarItem(
          title: Text('Profile'),
          icon: Icon(Icons.account_circle),
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
                    MaterialPageRoute(builder: (context) => const WaitingPage()),
                  );
                },
                
                redirectTo: kIsWeb ? null : 'com.wheelermun.nhs://callback',
                onSignInComplete: (AuthResponse response) {
                  if (response.session != null) {
                    // Navigate to the main screen on successful sign-in
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => MainScreen()),
                    );
                  }
                },
              ),
              SupaSocialsAuth(
                socialProviders: const [
                ],
                colored: true,
                onSuccess: (Session response) {
                  // Navigate to the home page on successful social sign-in
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => MainScreen()),
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
            Text(
              'Thank you for signing up!',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            Text(
              'Please check your email to verify your account.',
              style: const TextStyle(fontSize: 18.0),
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
  double  _meetingPotentialHours = 0;

  List<Event> _events = [];
  String _selectedEventType = 'All';

  @override
void initState() {
  super.initState();
  _fetchEvents();
}

   Future<void> _fetchEvents() async {
    final response = await Supabase.instance.client
        .from('Events')
        .select('*')
        .gt('date', DateTime.now().subtract(Duration(days: 1)).toIso8601String())
        .order('date');

    final List<dynamic> data = response;
    if (this.mounted) {
      setState(() {
        _events = data.map((json) => Event.fromJson(json)).toList();
        // Sort events from closest to furthest date
        _events.sort((a, b) => a.date.compareTo(b.date));
      });
      _fetchCompletedHours();
    }
  }

  List<Widget> _buildEventTypeChips() {
    return [
      FilterChip(
        label: Text('All'),
        selected: _selectedEventType == 'All',
        onSelected: (selected) {
          setState(() {
            _selectedEventType = 'All';
          });
        },
      ),
      FilterChip(
        label: Text('Service'),
        selected: _selectedEventType == 'Service',
        onSelected: (selected) {
          setState(() {
            _selectedEventType = 'Service';
          });
        },
      ),
      FilterChip(
        label: Text('Tutoring'),
        selected: _selectedEventType == 'Tutoring',
        onSelected: (selected) {
          setState(() {
            _selectedEventType = 'Tutoring';
          });
        },
      ),
      FilterChip(
        label: Text('Meeting'),
        selected: _selectedEventType == 'Meeting',
        onSelected: (selected) {
          setState(() {
            _selectedEventType = 'Meeting';
          });
        },
      ),
    ];
  }

  List<Event> _getFilteredEvents() {
    if (_selectedEventType == 'All') {
      return _events;
    } else {
      return _events.where((event) => event.type == _selectedEventType).toList();
    }
  }


 Future<void> _fetchCompletedHours() async {
  final User? user = supabase.auth.currentUser;
  final userId = user?.id;

  if (userId != null) {
    final response = await Supabase.instance.client
        .from('Service hours')
        .select('hours, type')
        .eq('user_id', userId as String);

    if (response != null && _events != null) {
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
          final isSignedUp = timeSlot.attendees.any((attendee) => attendee.name == userId);
          final isNotPresent = timeSlot.attendees.any((attendee) => attendee.name == userId && !attendee.isPresent);

          if (isSignedUp && isNotPresent) {
            final duration = _calculateDuration(timeSlot.time, timeSlot.endTime);
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

      if (this.mounted) {
        setState(() {
          _servicePotentialHours = serviceHours;
          _tutoringPotentialHours = tutoringHours;
          _meetingPotentialHours = meetingHours;
          _serviceHoursCompleted = serviceHoursC;
          _tutoringHoursCompleted = tutoringHoursC;
          _meetingHoursCompleted = meetingHoursC;
        });
      } else {
        // Handle the error case
        print('Error fetching completed hours: ${response}');
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

Widget _buildDoubleProgressBar(context, String title, double completedHours, double potentialHours, int hoursNeeded) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Completed: ${completedHours.toStringAsFixed(2)} hours',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Stack(
          children: [
            LinearProgressIndicator(
              value: potentialHours / hoursNeeded,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.5)),
              minHeight: 10,
              borderRadius: BorderRadius.all(Radius.circular(33)),
            ),
            LinearProgressIndicator(
              value: completedHours / hoursNeeded,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              minHeight: 10,
              borderRadius: BorderRadius.all(Radius.circular(33)),
            ),
          ],
        ),
        SizedBox(height: 5),
        Text(
          'Potential $title: ${potentialHours.toStringAsFixed(2)} hours',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    ),
  );
}

Widget _buildMeetingProgressBar(BuildContext context, double completedHours, int hoursNeeded) {
    final meetingsAttended = completedHours.floor();
    final meetingsLeft = _events.where((event) => event.type == 'Meeting').length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meetings Attended: $meetingsAttended',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          LinearProgressIndicator(
            value: completedHours / hoursNeeded,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            minHeight: 10,
            borderRadius: BorderRadius.all(Radius.circular(33)),
          ),
          SizedBox(height: 5),
          Text(
            'Meetings Left: $meetingsLeft',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    final bool isNew = event.createdAt.isAfter(DateTime.now().subtract(Duration(days: 7)));
    final bool isMandatory = event.isMandatory;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [

          if (isMandatory)
            Positioned(
              left: 255,
              top: 32,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
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
              left:250,
              top: 32,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                event.name + " - " + event.date.month.toString() + "/" + event.date.day.toString() + "/" + event.date.year.toString(),
                style: TextStyle(
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
        final isSignedUp = timeSlot.attendees.any((attendee) => attendee.name == supabase.auth.currentUser?.id);
        final isEventInFuture = event.date.isAfter(DateTime.now().add(Duration(days: 1)));
        final isMandatory = event.isMandatory;
        final isMeeting = event.type == 'Meeting';

        return ListTile(
          title: Text(
              event.type == 'Meeting'
                  ? 'Time: ${timeSlot.time.format(context)}'
                  : 'Time: ${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
            style: TextStyle(
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
                        icon: Icon(Icons.calendar_today),
                        onPressed: () {
                          _addEventToCalendar(event, timeSlot);
                        },
                      ),
                      if (isEventInFuture && !isMandatory && !isMeeting)
                        IconButton(
                          icon: Icon(Icons.cancel),
                          onPressed: () {
                            _removeAttendee(event, timeSlot);
                          },
                        ),
                    ],
                  )
                : isMandatory || isMeeting
                    ? Text('Automatically Signed Up')
                    : ElevatedButton(
                        child: Text('  Sign Up  '),
                        onPressed: () {
                          _showSignUpForm(event, timeSlot);
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
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
  return Scaffold(
    appBar: AppBar(
      elevation: 15,
      shadowColor: Theme.of(context).colorScheme.shadow,
      title: Text(
        'Home',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24.0,
          color: Theme.of(context).colorScheme.onPrimary
        ),
      ),
      centerTitle: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(13),
        ),
      ),
    ),
    body: SingleChildScrollView(
      child: Column(
        children: [
          _buildDoubleProgressBar(context, 'Service Hours', _serviceHoursCompleted, _servicePotentialHours, 14),
          _buildDoubleProgressBar(context, 'Tutoring Hours', _tutoringHoursCompleted, _tutoringPotentialHours, 6),
          _buildMeetingProgressBar(context, _meetingHoursCompleted, 5),
          SizedBox(height: 20),
          Wrap(
              spacing: 8,
              children: _buildEventTypeChips(),
            ),
            SizedBox(height: 20),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: filteredEvents.length,
              itemBuilder: (context, index) {
                final event = filteredEvents[index];
                return _buildEventCard(event);
              },
            ),
          ],
        ),
      ),
      
  );
}

  void _showSignUpForm(Event event, TimeSlot timeSlot) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Sign Up'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Event: ${event.name}'),
            SizedBox(height: 8),
            Text('Time: ${timeSlot.time.format(context)}'),
            SizedBox(height: 8),
            Text('Number of People: ${timeSlot.numberOfPeople}'),
          ],
        ),
        actions: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                SizedBox(width: 3),
                ElevatedButton(
                  child: Text('Sign Up'),
                  onPressed: () {
                    _signUpForTimeSlot(event, timeSlot);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              icon: Icon(Icons.calendar_today),
              label: Text('Add to Calendar'),
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
  void _removeAttendee(Event event, TimeSlot timeSlot) async {
    final userId = supabase.auth.currentUser?.id;

    if (userId != null) {
      await Supabase.instance.client.from('Events').update({
        'timeSlots': event.timeSlots.map((slot) {
          if (slot == timeSlot) {
            return {
              'time': '${slot.time.hour}:${slot.time.minute}',
              'endTime': '${slot.endTime.hour}:${slot.endTime.minute}',
              'numberOfPeople': slot.numberOfPeople + 1,
              'attendees': slot.attendees
                  .where((attendee) => attendee.name != userId)
                  .map((attendee) => {
                        'name': attendee.userId,
                        'isPresent': attendee.isPresent,
                      })
                  .toList(),
            };
          } else {
            return {
              'time': '${slot.time.hour}:${slot.time.minute}',
              'endTime': '${slot.endTime.hour}:${slot.endTime.minute}',
              'numberOfPeople': slot.numberOfPeople,
              'attendees': slot.attendees.map((attendee) => {
                    'name': attendee.userId,
                    'isPresent': attendee.isPresent,
                  }).toList(),
            };
          }
        }).toList(),
      }).eq('name', event.name);

      _fetchEvents();
    }
  }
  void _signUpForTimeSlot(Event pEvent, TimeSlot timeSlot) async {
  // Get the current user's UUID
  final User? user = supabase.auth.currentUser;
  final userId = user?.id;
  print(pEvent.name);
  if (userId != null) {
    // Fetch the latest event data from Supabase
    final eventData = await Supabase.instance.client
        .from('Events')
        .select()
        .eq('name', pEvent.name)
        .single();
    if (eventData != null) {
      final event = Event.fromJson(eventData);
      // Find the time slot index
      final timeSlotIndex = event.timeSlots.indexWhere((slot) =>
          slot.time == timeSlot.time && slot.endTime == timeSlot.endTime);

      if (timeSlotIndex != -1) {
        final slot = event.timeSlots[timeSlotIndex];
        if (slot.numberOfPeople > 0 &&
            !slot.attendees.any((attendee) => attendee.name == userId)) {
          final updatedAttendees = List<Attendee>.from(slot.attendees)
            ..add(Attendee(name: userId, isPresent: false, userId: userId));
          final updatedNumberOfPeople = slot.numberOfPeople - 1;

          // Update the time slot with the user signed up
          final updatedTimeSlot = {
            'time': '${slot.time.hour}:${slot.time.minute}',
            'endTime': '${slot.endTime.hour}:${slot.endTime.minute}',
            'numberOfPeople': updatedNumberOfPeople,
            'attendees': updatedAttendees.map((attendee) => {
                  'name': attendee.userId,
                  'isPresent': attendee.isPresent,
                }).toList(),
          };
          // Update the event in the Supabase database
 await Supabase.instance.client.from('Events').update({
    'timeSlots': event.timeSlots.map((slot) {
        // Keep the other time slots unchanged
        return {
          'time': '${slot.time.hour}:${slot.time.minute}',
            'endTime': '${slot.endTime.hour}:${slot.endTime.minute}',
            'numberOfPeople': updatedNumberOfPeople,
            'attendees': updatedAttendees.map((attendee) => {
                  'name': attendee.userId,
                  'isPresent': attendee.isPresent,
                }).toList(),
        };
    }).toList(),
  }).eq('name', event.name);
          _fetchEvents();
        }
      }
    }
  }
}
  void _addEventToCalendar(Event event, TimeSlot timeSlot) {
  final calendarEvent = addEvent(
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
    iosParams: IOSParams(
      reminder: Duration(minutes: 10),
    ),
    androidParams: AndroidParams(
      emailInvites: [],
    ),
  );

  Add2Calendar.addEvent2Cal(calendarEvent);
}
  void _openWebsite() async {
      final Uri url = Uri.parse('https://docs.google.com/forms/d/1ZcXKKctcGjxJYi5KXuqmZ8u1BQP-825KSFJmP-rcKtA/viewform?edit_requested=true');
    if (!await launchUrl(url)) {
          throw Exception('Could not launch url');
      }
    }

}

Future<String> _getUserName(String? userId) async {
  if (userId != null) {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('name')
        .eq('user_id', userId)
        .single();

    if (response != null) {
      return response['name'] ?? 'Unknown User';
    }
  }
  return 'Unknown User';
}

Widget _buildProgressBar(context, String title, double completedHours, int hoursNeeded,) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ${completedHours.toStringAsFixed(2)} hours',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          LinearProgressIndicator(
            value: completedHours / hoursNeeded,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            minHeight: 10,
            borderRadius: BorderRadius.all(Radius.circular(33)),
          ),
        ],
      ),
    );
  }

class CompletedHoursPage extends StatefulWidget {
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
          title: Text('Meeting Notes'),
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
              child: Text('Close'),
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
          title: Text(note.title),
          content: Text(note.text),
          actions: [
            TextButton(
              child: Text('Close'),
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

  if (response != null) {
    final data = response;
    double serviceHours = 0;
    double tutoringHours = 0;
    double meetingHours = 0;
    List<CompletedHour> serviceHoursList = [];
    List<CompletedHour> tutoringHoursList = [];
    List<CompletedHour> meetingHoursList = [];

    for (final entry in data) {
      final hours = entry['hours'] + 0.0 ?? 0.0 ;
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
  } else {
    // Handle the error case
    print('Error fetching completed hours: ${response}');
  }
}
      
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 15,
        shadowColor: Theme.of(context).colorScheme.shadow,
        title: Text(
          'Completed Hours',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                leading: Icon(Icons.notes),
                title: Text('Meeting Notes'),
                onTap: _showMeetingNotesDialog,
              ),
            ),
            _buildProgressBar(context, 'Service Hours', _serviceHoursCompleted, 14),
            _buildCompletedHoursList(_completedServiceHours),
            SizedBox(height: 20),
            _buildProgressBar(context, 'Tutoring Hours', _tutoringHoursCompleted, 6),
            _buildCompletedHoursList( _completedTutoringHours),
            SizedBox(height: 20),
            _buildProgressBar(context, 'Meeting Hours', _meetingHoursCompleted, 5),
            _buildCompletedHoursList( _completedMeetingHours),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Open the website when the button is pressed
          _openWebsite();
        },
        child: Icon(Icons.report_problem),
      ),
    );
  }

  

  Widget _buildCompletedHoursList( List<CompletedHour> hours) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),

    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          shrinkWrap: true,
          itemCount: hours.length,
          itemBuilder: (context, index) {
            final hour = hours[index];
            if (hour.date.year == 0){
              return Card(
              child: ListTile(
              title: Text(hour.title),
              subtitle:
              Text('${hour.hours.round()} hours'),
            )
              );
            }else {
              return Card(
              child: ListTile(
              title: Text(hour.title),
              subtitle:
              Text('${hour.date.month}-${hour.date.day}-${hour.date.year} - ${hour.hours.round()} hours'),
              )
              );
            }
          },
        ),
      ],
    )
    );
  }

  void _openWebsite() async {
    final Uri url = Uri.parse('https://docs.google.com/forms/d/e/1FAIpQLSeXg0ctE8Lg3r4aLhUSZYWj8GlvxwxM4aTRhf3axEQRljeRtw/viewform');
   if (!await launchUrl(url)) {
        throw Exception('Could not launch url');
    }
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

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    saveThemePreference();
    notifyListeners();
  }

  Future<void> loadThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> saveThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }
}

class SettingsPage extends StatefulWidget {
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


  Future<void> _fetchUserProfile() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;

    if (userId != null) {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .single();

      if (response != null) {
        if (this.mounted) {
        setState(() {
          _name = response['name'] ?? '';
          _email = response['email'] ?? '';
          _graduationYear = response['graduation_year']?.toString() ?? '';
        });
      }
      }
    }
  }

   Future<void> _updateUserProfile() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;

    if (userId != null) {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'graduation_year': int.tryParse(_graduationYear) ?? 0,
          })
          .eq('user_id', userId);
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

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 15,
        shadowColor: Theme.of(context).colorScheme.shadow,
        title: Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onPrimary
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Account Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Name: $_name'),
                      Text('Email: $_email'),
                      Text('Graduation Year: $_graduationYear'),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.logout),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    onPressed: _signOut,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    initialValue: _graduationYear,
                    decoration: InputDecoration(labelText: 'Graduation Year'),
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
                  SizedBox(height: 24.0),
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
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        );
                      }
                    },
                    child: Text('Update'),
                  ),
                  SizedBox(height: 24.0),
                  ListTile(
                    leading: Icon(Icons.color_lens),
                    title: Text('Theme Color'),
                    trailing: CircleAvatar(
                      backgroundColor: _selectedColor,
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Select Theme Color'),
                            content: SingleChildScrollView(
                              child: SlidePicker(
                                pickerColor: _selectedColor,
                                onColorChanged: _handleColorChange,
                              ),
                            ),
                            actions: [
                              TextButton(
                                child: Text('OK'),
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
                    title: Text('Dark Mode'),
                    value: Provider.of<ThemeProvider>(context).isDarkMode,
                    onChanged: (_) {
                      Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                    },
                  ),
                ],
              ),
            ),
              SizedBox(height: 24.0),
              BarcodeWidget(
                barcode: barcodeGen.Barcode.qrCode(),
                data: supabase.auth.currentUser?.id ?? '',
                width: 200,
                height: 200,
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
// admin_events_page.dart
class AdminEventsPage extends StatefulWidget {
  @override
  _AdminEventsPageState createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  final _formKey = GlobalKey<FormState>();
  late String _eventName;
  late String _eventDescription;
  late DateTime _eventDate;
  List<TimeSlot> _timeSlots = [];
  bool _isMandatory = false;

  List<Event> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    final response = await Supabase.instance.client
        .from('Events')
        .select('*')
        .order('date');

    final List<dynamic> data = response;
    setState(() {
      _events = data.map((json) => Event.fromJson(json)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 10,
        shadowColor: Theme.of(context).colorScheme.shadow,
        title: Text(
          'Events',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: 
      ListView.separated(
        scrollDirection: Axis.vertical,
        itemCount: _events.length,
        separatorBuilder: (context, index) => SizedBox(height: 8),
        itemBuilder: (context, index) {
          final event = _events[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 2,
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CustomExpansionTile(
              title: ListTile(
                title: Text(
                  event.name + " - " + event.date.month.toString() + "/" + event.date.day.toString() + "/" + event.date.year.toString(),
                  style: TextStyle(
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
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      _showEditEventDialog(event);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete),
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
                  icon: Icon(Icons.notes),
                  onPressed: () {
                    _showEditNotesDialog(event, timeSlot);
                  },
                ),
                );
              }).toList(),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        child: Icon(Icons.add),
      ),
    );
  }

  String? _selectedEventType;
void _showEditNotesDialog(Event event, TimeSlot timeSlot) {
  String notes = timeSlot.notes;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Edit Notes'),
        content: TextField(
          decoration: InputDecoration(
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
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: Text('Save'),
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

void _updateNotes(Event event, TimeSlot timeSlot, String notes) async {
  final index = event.timeSlots.indexOf(timeSlot);
  if (index != -1) {
    event.timeSlots[index].notes = notes;
    await Supabase.instance.client
        .from('Events')
        .update({
          'timeSlots': event.timeSlots.map((slot) => {
                'time': '${slot.time.hour}:${slot.time.minute}',
                'endTime': '${slot.endTime.hour}:${slot.endTime.minute}',
                'numberOfPeople': slot.numberOfPeople,
                'attendees': slot.attendees.map((attendee) => {
                      'name': attendee.userId,
                      'isPresent': attendee.isPresent,
                    }).toList(),
                'notes': slot.notes,
              }).toList(),
        })
        .eq('name', event.name);
  }
}

void _showAddEventDialog() async {
  _eventDate = DateTime.now();
  _timeSlots = [];
  _selectedEventType = null;
  setState(() {
  _isMandatory = false;
  });
  final result = await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text('Add Event'),
            content: SingleChildScrollView(
              child: Container(
                width: double.maxFinite,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Event Name',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the event name';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _eventName = value!;
                  },
                ),
                SizedBox(height: 16.0),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Event Description',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the event description';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _eventDescription = value!;
                  },
                ),
                    SizedBox(height: 16.0),
            
                    InkWell(
                      onTap: () => _selectDate(setState),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Event Date',
                        ),
                        child: Text(
                          '${_eventDate.year}/${_eventDate.month}/${_eventDate.day}',
                        ),
                      ),
                    ),
                    SwitchListTile(
                        title: Text('Mandatory'),
                        value: _isMandatory,
                        onChanged: (value) {
                          setState(() {
                            _isMandatory = value;
                          });
                        },
                      ),
                 DropdownButtonFormField<String>(
                    value: _selectedEventType,
                    onChanged: (value) {
                      setState(() {
                        _selectedEventType = value;
                      });
                    },
                    borderRadius: BorderRadius.circular(30),
                    dropdownColor: Theme.of(context).colorScheme.primaryContainer,
                    items: [
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
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select an event type';
                      }
                      return null;
                    },
                  ),

                SizedBox(height: 16.0),
                      Container(
                        constraints: BoxConstraints(maxHeight: 200),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < _timeSlots.length; i++)
                                ListTile(
                                  title: Text('${_timeSlots[i].time.format(context)} - ${_timeSlots[i].endTime.format(context)}'),
                                  subtitle: Text('Number of people: ${_timeSlots[i].numberOfPeople}'),
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete),
                                    onPressed: () {
                                      setState(() {
                                        _timeSlots.removeAt(i);
                                      });
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.0),
                      ElevatedButton(
                        child: Text('Add Time Slot'),
                        onPressed: () {
                          _addTimeSlot(setState);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                child: Text('Add'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    _addEvent();
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

void _removeTimeSlot(int index) {
  setState(() {
    _timeSlots.removeAt(index);
  });
}

void _addTimeSlot(StateSetter setState) async {
  final TimeOfDay? selectedStartTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );
  if (selectedStartTime != null) {
    final TimeOfDay? selectedEndTime = await showTimePicker(
      context: context,
      initialTime: selectedStartTime,
    );
    if (selectedEndTime != null) {
      int? numberOfPeople;
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Enter Number of People'),
            content: TextFormField(
              keyboardType: TextInputType.number,
              onChanged: (value) {
                numberOfPeople = int.tryParse(value);
              },
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      if (numberOfPeople != null) {
        setState(() {
          _timeSlots.add(TimeSlot(
            time: selectedStartTime,
            endTime: selectedEndTime,
            numberOfPeople: numberOfPeople!,
          ));
        });
      }
    }
  }
}

  void _showEditEventDialog(Event event) async {
  _eventName = event.name;
  _eventDescription = event.description;
  _eventDate = event.date;
  _timeSlots = List<TimeSlot>.from(event.timeSlots);
  _selectedEventType = event.type;

  final result = await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text('Edit Event'),
            content: SingleChildScrollView(
              child: Container(
                width: double.maxFinite,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    TextFormField(
                      initialValue: _eventName,
                      decoration: InputDecoration(
                        labelText: 'Event Name',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the event name';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _eventName = value!;
                      },
                    ),
                    SizedBox(height: 16.0),
                    TextFormField(
                      initialValue: _eventDescription,
                      decoration: InputDecoration(
                        labelText: 'Event Description',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the event description';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _eventDescription = value!;
                      },
                    ),
                    SizedBox(height: 16.0),
                    InkWell(
                      onTap: () => _selectDate(setState),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Event Date',
                        ),
                        child: Text(
                          '${_eventDate.year}/${_eventDate.month}/${_eventDate.day}',
                        ),
                      ),
                    ),
                    SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      value: _selectedEventType,
                      onChanged: (value) {
                        setState(() {
                          _selectedEventType = value;
                        });
                      },
                      items: [
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
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select an event type';
                        }
                        return null;
                      },
                    ),
                    Container(
                        constraints: BoxConstraints(maxHeight: 200),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < _timeSlots.length; i++)
                                ListTile(
                        title: Text('${_timeSlots[i].time.format(context)} - ${_timeSlots[i].endTime.format(context)}'),
                        subtitle: Text('Number of people: ${_timeSlots[i].numberOfPeople}'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              _timeSlots.removeAt(i);
                            });
                          },
                        ),
                      ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16.0),
                      ElevatedButton(
                        child: Text('Add Time Slot'),
                        onPressed: () {
                          _addTimeSlot(setState);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                child: Text('Save'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    _updateEvent(event);
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

void _updateEvent(Event event) async {
  final updatedEvent = Event(
    name: _eventName,
    description: _eventDescription,
    date: _eventDate,
    type: _selectedEventType!, // Add the updated event type
    timeSlots: _timeSlots,
    createdAt: DateTime.now(),
  );

  await Supabase.instance.client
      .from('Events')
      .update({
        'name': updatedEvent.name,
        'description': updatedEvent.description,
        'date': updatedEvent.date.toIso8601String(),
        'type': updatedEvent.type, // Update the event type in Supabase
        'timeSlots': updatedEvent.timeSlots.map((slot) => {
              'time': '${slot.time.hour}:${slot.time.minute}',
              'endTime': '${slot.endTime.hour}:${slot.endTime.minute}',
              'numberOfPeople': slot.numberOfPeople,
              'attendees': slot.attendees.map((attendee) => {
                    'name': attendee.name,
                    'isPresent': attendee.isPresent,
                  }).toList(),
            }).toList(),
      })
      .eq('name', event.name);

  setState(() {
    final index = _events.indexWhere((e) => e.name == event.name);
    if (index != -1) {
      _events[index] = updatedEvent;
    }
  });
}

void _addEvent() async {
  if (_formKey.currentState!.validate()) {
    _formKey.currentState!.save();
    final newEvent = Event(
      name: _eventName,
      description: _eventDescription,
      date: _eventDate,
      type: _selectedEventType!, // Add the selected event type
      timeSlots: _timeSlots.map((slot) => TimeSlot(
        time: slot.time,
        endTime: slot.endTime,
        numberOfPeople: slot.numberOfPeople,
        attendees: [],
      )).toList(),
      isMandatory: _isMandatory,
      createdAt: DateTime.now(),
      );
      setState(() {
        _events.add(newEvent);
      });
      Navigator.of(context).pop();

      if (newEvent.type == 'Meeting' || _isMandatory) {
        // Automatically sign up all users for mandatory meetings
        final profileResponse = await Supabase.instance.client.from('profiles').select('user_id');
        final List<dynamic> profileData = profileResponse;

        final attendees = profileData.map((profile) => profile['user_id'] as String).toList();

        final updatedTimeSlots = newEvent.timeSlots.map((slot) {
          final updatedAttendees = List<Attendee>.from(slot.attendees)
            ..addAll(attendees.map((userId) => Attendee(name: userId, isPresent: false, userId: userId)));
          final updatedNumberOfPeople = slot.numberOfPeople - attendees.length;

          return TimeSlot(
            time: slot.time,
            endTime: slot.endTime,
            numberOfPeople: updatedNumberOfPeople,
            attendees: updatedAttendees,
          );
        }).toList();

        newEvent.timeSlots = updatedTimeSlots;
      }

      // Save to Supabase
      await Supabase.instance.client.from('Events').insert({
      'name': newEvent.name,
      'description': newEvent.description,
      'date': newEvent.date.toIso8601String(),
      'type': newEvent.type, // Add the event type to the Supabase insert
      'timeSlots': newEvent.timeSlots.map((slot) => {
        'time': '${slot.time.hour}:${slot.time.minute}',
        'endTime': '${slot.endTime.hour}:${slot.endTime.minute}',
        'numberOfPeople': slot.numberOfPeople,
        'attendees': slot.attendees.map((attendee) => {
          'name': attendee.name,
          'isPresent': attendee.isPresent,
        }).toList(),
      }).toList(),
      'attendees': "Null",
      'isMandatory': newEvent.isMandatory,
    });
    
  }
}

  void _deleteEvent(Event event) async {
    setState(() {
      _events.remove(event);
    });
    await Supabase.instance.client.from('Events').delete().eq('name', event.name);
    
  }

  Future<void> _selectDate(StateSetter setState) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _eventDate,
    firstDate: DateTime(2023),
    lastDate: DateTime(2100),
  );
  if (picked != null && picked != _eventDate) {
    setState(() {
      _eventDate = picked;
    });
  }
}

}

class TimeSlot {
  final TimeOfDay time;
  final TimeOfDay endTime;
  final int numberOfPeople;
  final List<Attendee> attendees;
  String notes;

  TimeSlot({
    required this.time,
    required this.endTime,
    required this.numberOfPeople,
    this.attendees = const [],
    this.notes = '',
  });
}

class Event {
  final String name;
  final String description;
  final DateTime date;
  final String type;
  final bool isMandatory;
  final DateTime createdAt;
  List<TimeSlot> timeSlots;

  Event({
    required this.name,
    required this.description,
    required this.date,
    required this.type,
    required this.timeSlots,
    this.isMandatory = false,
    required this.createdAt,
  });

  Event.fromJson(Map<String, dynamic> json)
    : name = json['name'] ?? '',
      description = json['description'] ?? '',
      date = json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      type = json['type'] ?? '',
      isMandatory = json['isMandatory'] ?? false,
      createdAt = json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      timeSlots = json['timeSlots'] != null
          ? (json['timeSlots'] as List<dynamic>)
              .map((slot) => TimeSlot(
                    time: TimeOfDay(
                      hour: int.parse(slot['time'].split(':')[0]),
                      minute: int.parse(slot['time'].split(':')[1]),
                    ),
                    endTime: slot['endTime'] != null
                        ? TimeOfDay(
                            hour: int.parse(slot['endTime'].split(':')[0]),
                            minute: int.parse(slot['endTime'].split(':')[1]),
                          )
                        : TimeOfDay.now(),
                    numberOfPeople: slot['numberOfPeople'] ?? 0,
                    attendees: slot['attendees'] != null
                        ? (slot['attendees'] as List<dynamic>)
                            .map((attendee) => Attendee(
                                  name: attendee['name'] ?? '',
                                  isPresent: attendee['isPresent'] ?? false,
                                  userId: attendee['name'] ?? '',
                                ))
                            .toList()
                        : [],
                    notes: slot['notes'] ?? '',
                  ))
              .toList()
          : [];
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

class CustomExpansionTile extends ExpansionTile {
  CustomExpansionTile({
    Key? key,
    required Widget title,
    required List<Widget> children,
    bool initiallyExpanded = false,
    EdgeInsetsGeometry? tilePadding,
  }) : super(
          key: key,
          title: title,
          children: children,
          initiallyExpanded: initiallyExpanded,
          tilePadding: tilePadding,
        );

  @override
  Widget _buildChildren(BuildContext context, Widget? child, AnimationController? controller, bool expanded) {
    return Container(
      child: Column(
        children: children,
      ),
    );
  }
}

// admin_attendance_page.dart
class AdminAttendancePage extends StatefulWidget {
  @override
  _AdminAttendancePageState createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  List<Event> _events = [];
  List<UserProfile> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    final response = await Supabase.instance.client
        .from('Events')
        .select('*')
        .order('date');

    final List<dynamic> data = response;
    setState(() {
      _events = data.map((json) => Event.fromJson(json)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 15,
        shadowColor: Theme.of(context).colorScheme.shadow,
        title: Text(
          'Attendance',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: ListView.separated(
        itemCount: _events.length,
        separatorBuilder: (context, index) => SizedBox(height: 8),
        itemBuilder: (context, index) {
          final event = _events[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 2,
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CustomExpansionTile(
              title: ListTile(
                title: Text(
                  event.name + " - " + event.date.month.toString() + "/" + event.date.day.toString() + "/" + event.date.year.toString(),
                  style: TextStyle(
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
                    'Time: ${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
                    style: TextStyle(
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
                          builder: (context) => AttendanceCheckPage(event: event, timeSlot: timeSlot),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _showAttendanceDialog(Event event, TimeSlot timeSlot) async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AttendanceCheckPage(event: event, timeSlot: timeSlot),
    ),
  );

  return result ?? true;
}

  void _showSwapDialog(Attendee currentAttendee, List<Attendee> updatedAttendees, StateSetter parentSetState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String searchQuery = '';
        List<UserProfile> filteredUsers = List.from(_allUsers);

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Swap Attendee'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        filteredUsers = _allUsers
                            .where((user) => user.name.toLowerCase().contains(searchQuery.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 300,
                    width: 300,
                    child: ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return ListTile(
                          title: Text(user.name),
                          onTap: () {
                            parentSetState(() {
                              int index = updatedAttendees.indexOf(currentAttendee);
                              updatedAttendees[index] = Attendee(
                                name: user.name,
                                isPresent: false,
                                userId: user.id,
                              );
                            });
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
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

  void _saveAttendance(Event event, TimeSlot timeSlot) async {
    final attendees = timeSlot.attendees
        .map((attendee) => {
              'name': attendee.userId,
              'isPresent': attendee.isPresent,
            })
        .toList();

    final serviceHoursToAdd = <Map<String, dynamic>>[];
    final serviceHoursToRemove = <Map<String, dynamic>>[];

    for (final attendee in timeSlot.attendees) {
      final existingServiceHour = await Supabase.instance.client
          .from('Service hours')
          .select()
          .eq('event_name', event.name)
          .eq('timeslot', '${timeSlot.time.hour}:${timeSlot.time.minute}')
          .eq('user_id', attendee.userId);

      if (attendee.isPresent) {
        if (existingServiceHour.isEmpty) {
          final duration = _calculateDuration(timeSlot.time, timeSlot.endTime);
          serviceHoursToAdd.add({
            'event_name': event.name,
            'event_description': event.description,
            'date': event.date.toIso8601String(),
            'timeslot': '${timeSlot.time.hour}:${timeSlot.time.minute}',
            'user_id': attendee.userId,
            'hours': duration,
            'type': event.type,
          });
        }
      } else {
        if (existingServiceHour.isNotEmpty) {
          serviceHoursToRemove.add({
            'event_name': event.name,
            'timeslot': '${timeSlot.time.hour}:${timeSlot.time.minute}',
            'user_id': attendee.userId,
          });
        }
      }
    }

    if (serviceHoursToAdd.isNotEmpty) {
      await Supabase.instance.client.from('Service hours').insert(serviceHoursToAdd);
    }

    if (serviceHoursToRemove.isNotEmpty) {
      for (final serviceHour in serviceHoursToRemove) {
        await Supabase.instance.client
            .from('Service hours')
            .delete()
            .eq('event_name', serviceHour['event_name'])
            .eq('timeslot', serviceHour['timeslot'])
            .eq('user_id', serviceHour['user_id']);
      }
    }

    await Supabase.instance.client.from('Events').update({
      'timeSlots': event.timeSlots
          .map((slot) => {
                'time': '${slot.time.hour}:${slot.time.minute}',
                'endTime': '${slot.endTime.hour}:${slot.endTime.minute}',
                'numberOfPeople': slot.numberOfPeople,
                'attendees': slot == timeSlot
                    ? attendees
                    : slot.attendees
                        .map((attendee) => {
                              'name': attendee.userId,
                              'isPresent': attendee.isPresent,
                            })
                        .toList(),
              })
          .toList(),
    }).eq('name', event.name);

    setState(() {
      final eventIndex = _events.indexWhere((e) => e.name == event.name);
      final timeSlotIndex = _events[eventIndex].timeSlots.indexOf(timeSlot);
      
      final updatedTimeSlot = TimeSlot(
        time: timeSlot.time,
        endTime: timeSlot.endTime,
        numberOfPeople: timeSlot.numberOfPeople,
        attendees: timeSlot.attendees,
      );
      
      _events[eventIndex].timeSlots[timeSlotIndex] = updatedTimeSlot;
    });
  }

  double _calculateDuration(TimeOfDay startTime, TimeOfDay endTime) {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final duration = (endMinutes - startMinutes) / 60;
    return duration;
  }
}

class AdminListPage extends StatefulWidget {
  @override
  _AdminListPageState createState() => _AdminListPageState();
}

class _AdminListPageState extends State<AdminListPage> {
  List<UserProfile> _users = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
     setState(() {
        _users.clear();
      });

    final profileResponse = await Supabase.instance.client.from('profiles').select('*');
    final List<dynamic> profileData = profileResponse;

    for (final profileJson in profileData) {
      final userId = profileJson['user_id'] as String;
      final userName = profileJson['name'] as String;

      final hoursResponse = await Supabase.instance.client
          .from('Service hours')
          .select('event_name, hours, type')
          .eq('user_id', userId);

      final List<dynamic> hoursData = hoursResponse;
      final List<CompletedUserHour> completedHours = hoursData
          .map((hourJson) => CompletedUserHour.fromJson(hourJson))
          .toList();

      final user = UserProfile(
        name: userName,
        completedHours: completedHours,
        id: userId,
      );

      if (this.mounted) {
      setState(() {
        _users.add(user);
      });
    }
    }
  }

  List<UserProfile> _getFilteredUsers() {
  if (_searchQuery.isEmpty) {
    return _users;
  }

  final lowercaseQuery = _searchQuery.toLowerCase();
  return _users.where((user) {
    final lowercaseName = user.name.toLowerCase();
    return lowercaseName.contains(lowercaseQuery);
  }).toList();
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
        title: Text('Add Custom Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: eventName,
              decoration: InputDecoration(labelText: 'Event Name'),
              onChanged: (value) {
                eventName = value;
              },
            ),
            Padding(padding: EdgeInsets.only(top: 20.0),
            child: ElevatedButton(
              child: Center(
                child: Text(selectedTime != null
                    ? '${selectedTime.format(context)}'
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
            )
            ),
            TextFormField(
              initialValue: hours.toString(),
              decoration: InputDecoration(labelText: 'Hours'),
              keyboardType: TextInputType.number,
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
                    items: [
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
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: Text('Save'),
            onPressed: () {
              if (selectedTime != null) {
                String timeSlot = '${selectedTime.hour}:${selectedTime.minute}';
                _saveCustomEvent(userId, eventName, timeSlot, hours.toDouble(), type); // Pass userId directly
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      );
    },
  );
}

Future<void> _saveCustomEvent(
  String userId,
  String eventName,
  String timeSlot,
  double hours,
  String type,
) async {
  await Supabase.instance.client.from('Service hours').insert({
    'user_id': userId,
    'event_name': eventName,
    'timeslot': timeSlot,
    'hours': hours.toDouble(),
    'type': type,
  });

  _fetchUsers(); // Refresh the user list after saving the custom event
}

Future<void> _deleteServiceHour(CompletedUserHour hour, String userId) async {
  await Supabase.instance.client
      .from('Service hours')
      .delete()
      .eq('event_name', hour.eventName)
      .eq('user_id', userId);

      _fetchUsers();
}


  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredUsers();
    return Scaffold(
      appBar: AppBar(
        elevation: 15,
        shadowColor: Theme.of(context).colorScheme.shadow,
        title: Text(
          'List',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: Column(
      children: [
        Padding(
            padding: EdgeInsets.all(16.0),
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
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.0),
                ElevatedButton.icon(
                  onPressed: () {
                    _openBulkCustomEventForm(context);
                  },
                  icon: Icon(Icons.add),
                  label: Text('Bulk'),
                ),
              ],
            ),
          ),
        Expanded(
            child: ListView.separated(
              itemCount: filteredUsers.length,
              separatorBuilder: (context, index) => SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 2,
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CustomExpansionTile(
              title: ListTile(
                title: Text(
                  user.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                  ),
                ),
                trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                 user.hasCompletedHours()
                    ? Icon(Icons.check, color: Colors.green)
                    : Icon(Icons.close, color: Theme.of(context).colorScheme.error),
                   IconButton(
                    icon: Icon(Icons.add),
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
                      style: TextStyle(
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
                      icon: Icon(Icons.delete),
                      color: Theme.of(context).colorScheme.onSurface,
                      onPressed: () {
                        _deleteServiceHour(hour, user.id);
                      },
                    ),
                  );
                }).toList(),
              
            ),
          );
            },
          ),
        ),
      ],
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

  AttendanceCheckPage({required this.event, required this.timeSlot});

  @override
  _AttendanceCheckPageState createState() => _AttendanceCheckPageState();
}

class _AttendanceCheckPageState extends State<AttendanceCheckPage> {
  List<Attendee> _attendees = [];
  String _searchQuery = '';
  List<UserProfile> _allUsers = [];
  StreamSubscription<dynamic>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _fetchAttendees();
    _fetchAllUsers();
    _subscribeToEventChanges();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToEventChanges() {
  _eventSubscription = Supabase.instance.client
      .from('Events')
      .stream(primaryKey: ['name'])
      .eq('name', widget.event.name)
      .listen((event) async {
    if (event != null && event.isNotEmpty) {
      final updatedEvent = Event.fromJson(event.first);
      final updatedTimeSlot = updatedEvent.timeSlots.firstWhere(
        (slot) => slot.time == widget.timeSlot.time,
        orElse: () => widget.timeSlot,
      );

      final updatedAttendees = await Future.wait(
        updatedTimeSlot.attendees.map((attendee) async {
          final userName = await _getUserName(attendee.userId);
          return Attendee(
            name: userName,
            isPresent: attendee.isPresent,
            userId: attendee.userId,
          );
        }),
      );

      if (mounted) {
        setState(() {
          _attendees = updatedAttendees;
        });
      }
    }
  });
}


  Future<void> _fetchAttendees() async {
    final updatedAttendees = await Future.wait(
      widget.timeSlot.attendees.map((attendee) async {
        final userId = attendee.name;
        final userName = await _getUserName(userId);
        return Attendee(
          name: userName,
          isPresent: attendee.isPresent,
          userId: userId,
        );
      }),
    );

    setState(() {
      _attendees = updatedAttendees;
    });
  }

  Future<void> _fetchAllUsers() async {
    final response = await Supabase.instance.client.from('profiles').select('*');

    final List<dynamic> data = response;
    setState(() {
      _allUsers = data.map((json) => UserProfile(
        name: json['name'] ?? 'Unknown',
        id: json['user_id'],
        completedHours: [],
      )).toList();
    });
  }

  List<Attendee> _getFilteredAttendees() {
    if (_searchQuery.isEmpty) {
      return _attendees;
    }

    final lowercaseQuery = _searchQuery.toLowerCase();
    return _attendees.where((attendee) {
      final lowercaseName = attendee.name.toLowerCase();
      return lowercaseName.contains(lowercaseQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAttendees = _getFilteredAttendees();

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Check'),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner),
            onPressed: _scanBarcode,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event: ${widget.event.name}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Time: ${widget.timeSlot.time.format(context)}',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Search Attendees',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredAttendees.length,
              itemBuilder: (context, index) {
                final attendee = filteredAttendees[index];
                return CheckboxListTile(
                  title: Text(attendee.name),
                  value: attendee.isPresent,
                  onChanged: (value) {
                    setState(() {
                      attendee.isPresent = value!;
                    });
                  },
                  secondary: IconButton(
                    icon: Icon(Icons.swap_horiz),
                    onPressed: () {
                      _showSwapDialog(attendee);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {

          _saveAttendance();
          Navigator.pop(context);
        },
        child: Icon(Icons.save),
      ),
    );
  }

    Future<void> _scanBarcode() async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerPage(attendees: _attendees),
        ),
      );

      if (result != null) {
        final attendeeIndex = _attendees.indexWhere((attendee) => attendee.userId == result);
        if (attendeeIndex != -1 && mounted) {
          setState(() {
            _attendees[attendeeIndex].isPresent = true;
          });
          await _saveAttendance();
          _showToastNotification('Scanned in: ${_attendees[attendeeIndex].name}');
        }
      }
    }

    void _showToastNotification(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: 2),
    ),
  );
}


  void _showSwapDialog(Attendee currentAttendee) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String searchQuery = '';
        List<UserProfile> filteredUsers = List.from(_allUsers);

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Swap Attendee'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        filteredUsers = _allUsers
                            .where((user) => user.name.toLowerCase().contains(searchQuery.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 300,
                    width: 300,
                    child: ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return ListTile(
                          title: Text(user.name),
                          onTap: () {
                            setState(() {
                              int index = _attendees.indexOf(currentAttendee);
                              _attendees[index] = Attendee(
                                name: user.name,
                                isPresent: false,
                                userId: user.id,
                              );
                            });
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
             actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    },
  ).then((_) {
    setState(() {});
  });
}

 Future<void> _saveAttendance() async {
  final attendees = _attendees
      .map((attendee) => {
            'name': attendee.userId,
            'isPresent': attendee.isPresent,
          })
      .toList();

  final serviceHoursToAdd = <Map<String, dynamic>>[];
  final serviceHoursToRemove = <Map<String, dynamic>>[];

  for (final attendee in _attendees) {
    final existingServiceHour = await Supabase.instance.client
        .from('Service hours')
        .select()
        .eq('event_name', widget.event.name)
        .eq('timeslot', '${widget.timeSlot.time.hour}:${widget.timeSlot.time.minute}')
        .eq('user_id', attendee.userId);

    if (attendee.isPresent) {
      if (existingServiceHour.isEmpty) {
        final duration = _calculateDuration(widget.timeSlot.time, widget.timeSlot.endTime);
        serviceHoursToAdd.add({
          'event_name': widget.event.name,
          'event_description': widget.event.description,
          'date': widget.event.date.toIso8601String(),
          'timeslot': '${widget.timeSlot.time.hour}:${widget.timeSlot.time.minute}',
          'user_id': attendee.userId,
          'hours': duration,
          'type': widget.event.type,
        });
      }
    } else {
      if (existingServiceHour.isNotEmpty) {
        serviceHoursToRemove.add({
          'event_name': widget.event.name,
          'timeslot': '${widget.timeSlot.time.hour}:${widget.timeSlot.time.minute}',
          'user_id': attendee.userId,
        });
      }
    }
  }

  if (serviceHoursToAdd.isNotEmpty) {
    await Supabase.instance.client.from('Service hours').insert(serviceHoursToAdd);
  }

  if (serviceHoursToRemove.isNotEmpty) {
    for (final serviceHour in serviceHoursToRemove) {
      await Supabase.instance.client
          .from('Service hours')
          .delete()
          .eq('event_name', serviceHour['event_name'])
          .eq('timeslot', serviceHour['timeslot'])
          .eq('user_id', serviceHour['user_id']);
    }
  }

  await Supabase.instance.client.from('Events').update({
    'timeSlots': widget.event.timeSlots
        .map((slot) => {
              'time': '${slot.time.hour}:${slot.time.minute}',
              'endTime': '${slot.endTime.hour}:${slot.endTime.minute}',
              'numberOfPeople': slot.numberOfPeople,
              'attendees': slot == widget.timeSlot
                  ? attendees
                  : slot.attendees
                      .map((attendee) => {
                            'name': attendee.userId,
                            'isPresent': attendee.isPresent,
                          })
                      .toList(),
            })
        .toList(),
  }).eq('name', widget.event.name);

  // Fetch the latest event data from Supabase
    final eventData = await Supabase.instance.client
      .from('Events')
      .select()
      .eq('name', widget.event.name)
      .single();
  
  final updatedEvent = Event.fromJson(eventData);
  final updatedTimeSlotIndex = updatedEvent.timeSlots.indexWhere((slot) => slot.time == widget.timeSlot.time);

  if (updatedTimeSlotIndex != -1 && mounted) {
    final updatedTimeSlot = updatedEvent.timeSlots[updatedTimeSlotIndex];
    final updatedAttendees = updatedTimeSlot.attendees.map((attendee) => Attendee(
      name: attendee.name,
      isPresent: attendee.isPresent,
      userId: attendee.userId,
    )).toList();

    setState(() {
      _attendees = updatedAttendees;
    });
  }
}

  double _calculateDuration(TimeOfDay startTime, TimeOfDay endTime) {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final duration = (endMinutes - startMinutes) / 60;
    return duration;
  }
}



class BulkCustomEventFormPage extends StatefulWidget {
  final List<UserProfile> users;

  BulkCustomEventFormPage({required this.users});

  @override
  _BulkCustomEventFormPageState createState() => _BulkCustomEventFormPageState();
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
        title: Text('Add Bulk Custom Event'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(15),
              ),
              padding: EdgeInsets.all(16.0),
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
                  SizedBox(height: 16.0),
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
                          items: [
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
                      SizedBox(width: 16.0),
                      Expanded(
                        child: ElevatedButton(
                          child: Text(selectedTime != null
                              ? selectedTime!.format(context)
                              : 'Select Time'),
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
                        ),
                      ),
                      SizedBox(width: 16.0),
                      Expanded(
                        child: TextFormField(
                          initialValue: hours.toString(),
                          decoration: InputDecoration(
                            labelText: 'Hours',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          keyboardType: TextInputType.number,
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
            SizedBox(height: 16.0),
            TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'Search Members',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            SizedBox(height: 16.0),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  final isSelected = selectedUserIds.contains(user.id);

                  bool isFirstItem = index == 0;
                  bool isLastItem = index == filteredUsers.length - 1;
                  bool isPrevSelected = isFirstItem ? false : selectedUserIds.contains(filteredUsers[index - 1].id);
                  bool isNextSelected = isLastItem ? false : selectedUserIds.contains(filteredUsers[index + 1].id);

                  BorderRadius borderRadius = BorderRadius.zero;
                  if(!isSelected){

                  }
                  else if (isSelected && isNextSelected) {
                    if (isPrevSelected) {
                      borderRadius = BorderRadius.all((Radius.circular(6)));
                    } else {
                      borderRadius = BorderRadius.vertical(top: Radius.circular(15), bottom: Radius.circular(6));
                    }
                  } else if (isSelected && isPrevSelected) {
                    borderRadius = BorderRadius.vertical(bottom: Radius.circular(15), top: Radius.circular(6));
                  }
                  else{
                    borderRadius = BorderRadius.all(Radius.circular(15));
                  }

                  return Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
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
                      SizedBox(height: 2.0),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: 16.0),
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
            child: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.surfaceContainerHighest),
          ),
          SizedBox(width: 16.0),
          FloatingActionButton(
            onPressed: () {
              if (selectedTime != null) {
                String timeSlot = '${selectedTime!.hour}:${selectedTime!.minute}';
                _saveBulkCustomEvent(
                  selectedUserIds,
                  eventName,
                  timeSlot,
                  hours,
                  type,
                );
              }
            },
            child: Icon(Icons.save, color: Theme.of(context).colorScheme.onSurfaceVariant,),
          ),
        ],
      ),
    );
    
  }
  
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

// ... existing code ...
class AdminTotalHoursPage extends StatefulWidget {
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
          title: Text('Add Meeting Notes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Title',
                ),
                onChanged: (value) {
                  setState(() {
                    _notesTitle = value;
                  });
                },
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
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
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Save'),
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
          title: Text('Meeting Notes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _meetingNotes.map((note) {
                return ListTile(
                  title: Text(note.title),
                  trailing: IconButton(
                    icon: Icon(Icons.edit),
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
              child: Text('Close'),
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
          title: Text('Edit Meeting Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Title',
                ),
                controller: TextEditingController(text: note.title),
                onChanged: (value) {
                  updatedTitle = value;
                },
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
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
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Save'),
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
    await Supabase.instance.client
        .from('Notes')
        .update({
          'title': title,
          'text': text,
        })
        .eq('id', noteId);

    _fetchMeetingNotes();
  }

 Future<void> _fetchMeetingNotes() async {
    final response = await Supabase.instance.client
        .from('Notes')
        .select('*')
        .order('created_at', ascending: false);

    final List<dynamic> data = response;
    if(mounted){
      setState(() {
      _meetingNotes = data.map((json) => MeetingNote.fromJson(json)).toList();
    });
    }
    
  }

  

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

    if (response != null) {
      final data = response as List<dynamic>;
      double serviceHours = 0;
      double tutoringHours = 0;
      double meetingHours = 0;

      print(response);
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
  }

  @override
  Widget build(BuildContext context) {
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: _totalHours / 2000,
                    strokeWidth: 16,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                  ),
                  Center(
                    child: Text(
                      '${_totalHours.toStringAsFixed(2)}\nHours',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHoursCard('Service', _totalServiceHours, Theme.of(context).colorScheme.primary),
                _buildHoursCard('Tutoring', _totalTutoringHours, Theme.of(context).colorScheme.secondary),
                _buildHoursCard('Meeting', _totalMeetingHours, Theme.of(context).colorScheme.tertiary),
              ],
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _showAddNotesDialog,
                  child: Icon(Icons.notes),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _showMeetingNotesDialog,
                  child: Icon(Icons.edit),
                ),
          ],
        ),
          ],
      ),
      ),
    );
  }

  Widget _buildHoursCard(String title, double hours, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${hours.toStringAsFixed(2)} hours',
              style: TextStyle(
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class UserProfile {
  final String name;
  final String id;
  final List<CompletedUserHour> completedHours;

  UserProfile({
    required this.name,
    required this.completedHours,
    required this.id,
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
  final String name;
  bool isPresent;
  final String userId;

  Attendee({
    required this.name,
    required this.isPresent,
    required this.userId,
  });
}

class BarcodeScannerPage extends StatefulWidget {
  final List<Attendee> attendees;

  const BarcodeScannerPage({required this.attendees});

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
        title: Text('Scan QR Code'),
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

      void _foundBarcode(BarcodeCapture capture) {
      final barcode = capture.barcodes.first;
      final userId = barcode.rawValue;

      final attendeeIndex = widget.attendees.indexWhere((attendee) => attendee.userId == userId);
      if (attendeeIndex != -1) {
        Navigator.pop(context, userId);
      }
    }
}