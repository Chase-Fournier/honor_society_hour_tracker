import 'dart:async';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../snake.dart';
import 'societyadminpage.dart';
import 'accountsettingspage.dart';
import 'appearancepage.dart';
import 'notificationsettingspage.dart';
import '../common/app_design.dart';
import '../models/hourrequirement.dart';
import '../models/honorsociety.dart';
import '../providers/themeprovider.dart' as themeprovider;
import 'societyselectionpage.dart';
import '../providers/societyprovider.dart';
import '../providers/hapticsprovider.dart';

final supabase = Supabase.instance.client;

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
    _fetchUserSocieties();
    if (widget.society != null) {
      _checkAdminStatus(widget.society!.id);
    }
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
      debugPrint('Error loading societies: $e');
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
      debugPrint('Error checking admin status: $e');
    }
  }

  void _openSocietyAdmin() {
    final hapticsProvider =
        Provider.of<HapticsProvider>(context, listen: false);
    hapticsProvider.selection(); // Add haptic feedback

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
    final hapticsProvider =
        Provider.of<HapticsProvider>(context, listen: false);
    hapticsProvider.selection(); // Add haptic feedback

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AccountSettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if we're on a wide screen
    final bool isWideScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
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
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _fetchUserProfile();
                await _fetchUserSocieties();
              },
              child: isWideScreen
                  ? _buildWideScreenLayout()
                  : _buildMobileLayout(),
            ),
    );
  }

  // Layout for desktop/web
  Widget _buildWideScreenLayout() {
    return SingleChildScrollView(
      padding: AppDesign.paddingLarge,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column - profile info and society
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSocietyCard(),

                    const SizedBox(height: 24),

                    // User profile card
                    _buildUserProfileCard(),

                    const SizedBox(height: 24),

                    // Account settings card
                    _buildAccountSettingsCard(),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // Right column - theme and other settings
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Appearance settings card
                    _buildAppearanceCard(),

                    const SizedBox(height: 24),

                    // Games section - only show on web
                    _buildGamesSection(),
                  ],
                ),
              ),
            ],
          ),

          // About / report-issue footer
          _buildFooter(),
        ],
      ),
    );
  }

  // Layout for mobile
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: AppDesign.paddingMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Society Card
          _buildSocietyCard(),

          const SizedBox(height: 16),

          // User profile card
          _buildUserProfileCard(),

          const SizedBox(height: 24),

          // Account settings card
          _buildAccountSettingsCard(),

          const SizedBox(height: 24),

          // Appearance settings card
          _buildAppearanceCard(),

          const SizedBox(height: 24),

          // Snake game button
          ElevatedButton.icon(
            onPressed: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SnakePage()),
              );
            },
            icon: const Icon(Icons.games),
            label: const Text('Play Snake'),
          ),

          // About / report-issue footer
          _buildFooter(),
        ],
      ),
    );
  }

  // Neutral grouping card matching the dashboard's card styling: the default
  // card surface (slightly gray) with a hairline outline and no secondary tint.
  Widget _buildProfileCard({
    required Widget child,
    EdgeInsetsGeometry padding = AppDesign.paddingLarge,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.borderLarge,
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  // Society Card Widget
  Widget _buildSocietyCard() {
    final societyProvider =
        Provider.of<SocietyProvider>(context, listen: false);
    final currentSociety = societyProvider.currentSociety;

    if (currentSociety == null)
      return const SizedBox.shrink(); // Handle null case

    return _buildProfileCard(
      padding: AppDesign.paddingMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center, // Align items vertically
            children: [
              if (currentSociety.imageUrl != null)
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(currentSociety.imageUrl!),
                )
              else
                CircleAvatar(
                  radius: 28,
                  child: Text(
                    currentSociety.name.isNotEmpty
                        ? currentSociety.name[0]
                        : '?',
                    style: const TextStyle(fontSize: 24),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentSociety.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    if (_isAdmin)
                      Chip(
                        label: const Text('Admin'),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        padding: EdgeInsets.symmetric(
                            horizontal: 6, vertical: 0), // Make chip smaller
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.switch_account),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SocietySelectionPage()),
                    (route) => false,
                  );
                },
                tooltip: 'switch Society',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // User Profile Card Widget
  Widget _buildUserProfileCard() {
    return _buildProfileCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.person,
                        size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Name: $_name',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.email,
                        size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Email: $_email',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.school,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Graduation Year: $_graduationYear',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            color: Theme.of(context).colorScheme.primary,
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
    );
  }

  // Account Settings Card
  Widget _buildAccountSettingsCard() {
    return _buildProfileCard(
      padding: AppDesign.paddingMedium,
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.account_circle,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            title: const Text('Account Settings'),
            subtitle: const Text('Update email and password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _navigateToAccountSettings,
          ),
          // Push notifications are only supported on mobile (Android/iOS).
          // Hide the entry on web and desktop.
          if (_supportsPushNotifications) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.notifications_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              title: const Text('Notifications'),
              subtitle:
                  const Text('Reminders, meeting notes, hours, swap requests'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Provider.of<HapticsProvider>(context, listen: false)
                    .selection();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NotificationSettingsPage()),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// True only on mobile platforms, where FCM push is available. Excludes web
  /// and desktop (macOS/Windows/Linux).
  static bool get _supportsPushNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Appearance Settings Card
  Widget _buildAppearanceCard() {
    return _buildProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Appearance — opens dedicated page with mode, color, and themes
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: AppDesign.borderSmall,
              ),
              child: Icon(
                Icons.palette_outlined,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: const Text('Appearance'),
            subtitle: Text(
              _appearanceSummary(),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AppearancePage()),
              );
            },
          ),

          const Divider(),

          // Haptics Toggle
          Consumer<HapticsProvider>(
            builder: (context, hapticsProvider, child) {
              return SwitchListTile(
                title: const Text('Haptic Feedback'),
                subtitle: const Text('Vibrate on interactions'),
                secondary: Icon(
                  Icons.vibration,
                  color: Theme.of(context).colorScheme.primary,
                ),
                value: hapticsProvider.isHapticsEnabled,
                onChanged: (bool value) {
                  hapticsProvider.toggleHaptics(value);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _appearanceSummary() {
    final themeProvider =
        Provider.of<themeprovider.ThemeProvider>(context, listen: true);
    return themeProvider.getThemeName(themeProvider.themeMode);
  }

  // Games Section
  Widget _buildGamesSection() {
    return _buildProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Games & Activities',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildGameCard(
                'Snake',
                Icons.videogame_asset,
                Theme.of(context).colorScheme.tertiary,
                () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SnakePage()),
                  );
                },
              ),
              // Add more game cards in the future
              _buildGameCard('Coming Soon', Icons.airplanemode_active,
                  Theme.of(context).colorScheme.secondary, () {},
                  enabled: false),
              _buildGameCard(
                'Coming Soon',
                Icons.pending,
                Theme.of(context).colorScheme.secondary,
                () {},
                enabled: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(
      String title, IconData icon, Color color, VoidCallback onPressed,
      {bool enabled = true}) {
    return Card(
      elevation: enabled ? 2 : 0,
      color: enabled
          ? Theme.of(context).cardColor
          : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.borderMedium,
      ),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: AppDesign.borderMedium,
        child: Padding(
          padding: AppDesign.paddingMedium,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: enabled ? color : color.withOpacity(0.5),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: enabled
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens an external [url] in the device browser, with haptic feedback.
  Future<void> _launchUrl(String url) async {
    context.read<HapticsProvider>().selection();
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  /// A small footer with an "about the app" blurb and links to report an
  /// issue or read more on GitHub.
  Widget _buildFooter() {
    final colorScheme = Theme.of(context).colorScheme;
    const repoUrl = 'https://github.com/Chase-Fournier/wheeler_nhs';
    const issuesUrl = '$repoUrl/issues';
    const readmeUrl = '$repoUrl#readme';

    return Padding(
      padding: const EdgeInsets.only(
        top: AppDesign.spacingXL,
        bottom: AppDesign.spacingL,
      ),
      child: Column(
        children: [
          Text(
            'Honor Society Tracker is a free, open-source app for tracking '
            'volunteer hours.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppDesign.spacingM),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppDesign.spacingL,
            runSpacing: AppDesign.spacingS,
            children: [
              _buildFooterLink(
                icon: Icons.bug_report_outlined,
                label: 'Report an issue',
                onTap: () => _launchUrl(issuesUrl),
              ),
              _buildFooterLink(
                icon: Icons.info_outline,
                label: 'About the app',
                onTap: () => _launchUrl(readmeUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A single tappable footer link with a leading [icon] and [label].
  Widget _buildFooterLink({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spacingS,
          vertical: AppDesign.spacingXS,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: AppDesign.spacingXS),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final navigationState = Navigator.of(context);
    final hapticsProvider =
        Provider.of<HapticsProvider>(context, listen: false);
    hapticsProvider.warning();

    try {
      // Clear provider data
      Provider.of<SocietyProvider>(context, listen: false).handleLogout();

      // Clear preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sessionData');
      await prefs.remove('lastSocietyId');

      // Sign out from Supabase
      await supabase.auth.signOut();
      hapticsProvider.success();

      // Navigate to login page
      navigationState.pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      debugPrint('Error during logout: $e');
      hapticsProvider.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during logout: $e')),
      );
    }
  }
}
