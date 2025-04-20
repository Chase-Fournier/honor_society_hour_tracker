import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bottom_navy_bar/bottom_navy_bar.dart';
import '../providers/societyprovider.dart';
import 'societyadmindashboard.dart';
import 'adminattendencepage.dart';
import 'completedhourspage.dart';
import 'admineventspage.dart';
import 'homescreenpage.dart';
import 'settingspage.dart';
import 'adminlistspage.dart';

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
}
