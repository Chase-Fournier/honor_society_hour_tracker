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
import '../providers/hapticsprovider.dart';
import '../providers/navigationprovider.dart';
import '../common/customnavigationbar.dart';

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