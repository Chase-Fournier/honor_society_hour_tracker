import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/societyprovider.dart';
import '../services/notification_service.dart';
import 'societyadmindashboard.dart';
import 'adminattendencepage.dart';
import 'completedhourspage.dart';
import 'admineventspage.dart';
import 'homescreenpage.dart';
import 'settingspage.dart';
import 'adminlistspage.dart';
import '../common/customnavigationbar.dart';
import '../logic/notification_routing.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  PageController _pageController = PageController();

  /// Tracks the last rendered shell type so we can reset navigation when an
  /// admin flips between the admin and member views.
  bool? _lastIsAdmin;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Route to the relevant tab when a notification is tapped (including a
    // tap that cold-started the app, whose payload is already waiting).
    NotificationService.instance.tappedNotification
        .addListener(_handleNotificationTap);
    _handleNotificationTap();
  }

  @override
  void dispose() {
    NotificationService.instance.tappedNotification
        .removeListener(_handleNotificationTap);
    _pageController.dispose();
    super.dispose();
  }

  void _handleNotificationTap() {
    final data = NotificationService.instance.tappedNotification.value;
    if (data == null) return;
    // Consume it so it isn't re-handled on the next rebuild/listener fire.
    NotificationService.instance.tappedNotification.value = null;

    // Must match the shell actually on screen, which build() derives from
    // showAdminView. Using raw isAdmin here sent an admin who was previewing
    // the member view to admin tab indices -- a 'hours' notification landed on
    // Settings instead of Completed Hours.
    final showAdminView = context.read<SocietyProvider>().showAdminView;
    final target = tabForNotificationType(
      data['type']?.toString(),
      isAdmin: showAdminView,
    );
    if (target == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      setState(() => _currentIndex = target);
      _pageController.jumpToPage(target);
    });
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

        final isAdmin = societyProvider.showAdminView;
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

        final List<NavigationTabData> navTabs = [
          if (isAdmin) ...[
            NavigationTabData(
              title: 'Dashboard',
              icon: Icons.dashboard,
              shortText: 'Dash',
            ),
            NavigationTabData(
              title: 'Events',
              icon: Icons.event,
              shortText: 'Events',
            ),
            NavigationTabData(
              title: 'Attendance',
              icon: Icons.check_circle,
              shortText: 'Attend',
            ),
            NavigationTabData(
              title: 'Members',
              icon: Icons.people,
              shortText: 'Members',
            ),
            NavigationTabData(
              title: 'Settings',
              icon: Icons.settings,
              shortText: 'Settings',
            ),
          ] else ...[
            NavigationTabData(
              title: 'Home',
              icon: Icons.home,
              shortText: 'Home',
            ),
            NavigationTabData(
              title: 'Details',
              icon: Icons.watch_later,
              shortText: 'Details',
            ),
            NavigationTabData(
              title: 'Profile',
              icon: Icons.account_circle,
              shortText: 'Profile',
            ),
          ],
        ];

        // When an admin flips between the admin and member shells the tab
        // count changes, so reset navigation to the Settings/Profile tab (the
        // last tab in both shells, where the view switcher lives) and rebuild
        // the PageController to avoid an out-of-range page.
        if (_lastIsAdmin != null && _lastIsAdmin != isAdmin) {
          _currentIndex = pages.length - 1;
          final oldController = _pageController;
          _pageController = PageController(initialPage: _currentIndex);
          WidgetsBinding.instance
              .addPostFrameCallback((_) => oldController.dispose());
        }
        _lastIsAdmin = isAdmin;

       if (isWideScreen) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                    _pageController.jumpToPage(index);
                  },
                  labelType: NavigationRailLabelType.selected,
                  destinations: navTabs.map((tab) {
                    return NavigationRailDestination(
                      icon: Icon(tab.icon),
                      label: Text(tab.title),
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
          );
        }

        // Mobile layout with custom navigation
         return CustomNavigationBar(
          selectedIndex: _currentIndex,
          onTabChanged: (index) {
            setState(() => _currentIndex = index);
            _pageController.jumpToPage(index);
          },
          tabs: navTabs,
          isAdmin: isAdmin,
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            children: pages,
          ),
        );
      },
    );
  }
}