import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../snake.dart';
import 'societyadminpage.dart';
import 'accountsettingspage.dart';
import '../common/app_design.dart';
import '../models/hourrequirement.dart';
import '../models/honorsociety.dart';
import '../providers/themeprovider.dart' as themeprovider;
import '../providers/themenotifier.dart';
import 'societyselectionpage.dart';
import '../common/app_widgets.dart';
import '../providers/societyprovider.dart';
import '../providers/hapticsprovider.dart';
import '../providers/navigationprovider.dart';

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

  void _handleColorChange(Color color) {
    final hapticsProvider =
        Provider.of<HapticsProvider>(context, listen: false);
    hapticsProvider.selection(); // Add haptic feedback

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
      child: Row(
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
        ],
      ),
    );
  }

  // Society Card Widget
  Widget _buildSocietyCard() {
    final societyProvider =
        Provider.of<SocietyProvider>(context, listen: false);
    final currentSociety = societyProvider.currentSociety;

    if (currentSociety == null)
      return const SizedBox.shrink(); // Handle null case

    return AppCard(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
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
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.borderLarge,
      ),
      child: Padding(
        padding: AppDesign.paddingLarge,
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
                       Icon(Icons.person, size: 18, color: Theme.of(context).colorScheme.primary),
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
                      Icon(Icons.email, size: 18, color: Theme.of(context).colorScheme.primary),
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
                      Icon(Icons.school, size: 18, color: Theme.of(context).colorScheme.primary,),
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
      ),
    );
  }

  // Account Settings Card
  Widget _buildAccountSettingsCard() {
    return AppCard(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
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
    );
  }

  // Appearance Settings Card
    Widget _buildAppearanceCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.borderLarge,
      ),
      child: Padding(
        padding: AppDesign.paddingLarge,
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
                            final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
                            hapticsProvider.selection();
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

            // Navigation Bar Style Selection
            _buildNavigationBarSelector(),

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

            const Divider(),

            // Theme Mode Selection
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text('Theme Mode'),
                ),
                
                // Basic themes
                RadioListTile<themeprovider.ThemeMode>(
                  title: const Text('Light'),
                  subtitle: const Text('Clean and bright'),
                  value: themeprovider.ThemeMode.light,
                  groupValue: Provider.of<themeprovider.ThemeProvider>(context)
                      .themeMode,
                  onChanged: (value) {
                    final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection(); 
                    Provider.of<themeprovider.ThemeProvider>(context,
                            listen: false)
                        .setThemeMode(themeprovider.ThemeMode.light);
                  },
                  secondary: Icon(Icons.light_mode),
                ),
                RadioListTile<themeprovider.ThemeMode>(
                  title: const Text('Dark'),
                  subtitle: const Text('Easy on the eyes'),
                  value: themeprovider.ThemeMode.dark,
                  groupValue: Provider.of<themeprovider.ThemeProvider>(context)
                      .themeMode,
                  onChanged: (value) {
                    final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    Provider.of<themeprovider.ThemeProvider>(context,
                            listen: false)
                        .setThemeMode(themeprovider.ThemeMode.dark);
                  },
                  secondary: Icon(Icons.dark_mode),
                ),
                RadioListTile<themeprovider.ThemeMode>(
                  title: const Text('Midnight'),
                  subtitle: const Text('Pure black background'),
                  value: themeprovider.ThemeMode.midnight,
                  groupValue: Provider.of<themeprovider.ThemeProvider>(context)
                      .themeMode,
                  onChanged: (value) {
                    final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    Provider.of<themeprovider.ThemeProvider>(context,
                            listen: false)
                        .setThemeMode(themeprovider.ThemeMode.midnight);
                  },
                  secondary: Icon(Icons.nightlight_round),
                ),

                const Divider(),

                // More themes section
                _buildMoreThemesSection(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreThemesSection() {
    final themeProvider = Provider.of<themeprovider.ThemeProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    final customThemes = [
      themeprovider.ThemeMode.sunset,
      themeprovider.ThemeMode.sunrise,
      themeprovider.ThemeMode.fullMoon,
      themeprovider.ThemeMode.forest,
      themeprovider.ThemeMode.ocean,
      themeprovider.ThemeMode.reef,
      themeprovider.ThemeMode.cherry,
      themeprovider.ThemeMode.lavender,
      themeprovider.ThemeMode.autumn,
      themeprovider.ThemeMode.winter,
      themeprovider.ThemeMode.desert,
      themeprovider.ThemeMode.galaxy,
      themeprovider.ThemeMode.emerald,
      themeprovider.ThemeMode.ruby,
      themeprovider.ThemeMode.sapphire,
      themeprovider.ThemeMode.amber,
    ];

    // Responsive grid columns based on screen width
    final crossAxisCount = screenWidth > 600 ? 3 : 2;
    final childAspectRatio = screenWidth > 600 ? 3.2 : (screenWidth > 400 ? 3.0 : 2.8);
    
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          'More Themes',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: screenWidth > 400 ? 16 : 15,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        subtitle: Text(
          'Beautiful custom themes',
          style: TextStyle(
            fontSize: screenWidth > 400 ? 14 : 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        leading: Icon(
          Icons.palette,
          color: Theme.of(context).colorScheme.primary,
          size: screenWidth > 400 ? 24 : 22,
        ),
        tilePadding: EdgeInsets.symmetric(
          horizontal: screenWidth > 400 ? 16 : 12,
          vertical: 4,
        ),
        childrenPadding: EdgeInsets.symmetric(
          horizontal: screenWidth > 400 ? 16 : 12,
          vertical: 8,
        ),
        children: [
          Container(
            constraints: BoxConstraints(
              maxHeight: screenWidth > 600 ? 400 : 350,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: screenWidth > 400 ? 10 : 8,
                mainAxisSpacing: screenWidth > 400 ? 10 : 8,
              ),
              itemCount: customThemes.length,
              itemBuilder: (context, index) {
                final theme = customThemes[index];
                final isSelected = themeProvider.themeMode == theme;
                
                return InkWell(
                  onTap: () {
                    final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    themeProvider.setThemeMode(theme);
                  },
                  borderRadius: BorderRadius.circular(screenWidth > 400 ? 14 : 12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(screenWidth > 400 ? 14 : 12),
                      border: Border.all(
                        color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: isSelected ? 2.5 : 1,
                      ),
                      color: isSelected 
                        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                        : Theme.of(context).colorScheme.surface,
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    padding: EdgeInsets.all(screenWidth > 400 ? 12 : 10),
                    child: Row(
                      children: [
                        // Theme preview circle
                        Container(
                          width: screenWidth > 400 ? 34 : 30,
                          height: screenWidth > 400 ? 34 : 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(screenWidth > 400 ? 10 : 8),
                            color: _getThemePreviewColor(theme),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _getThemePreviewColor(theme).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            themeProvider.getThemeIcon(theme),
                            color: Colors.white,
                            size: screenWidth > 400 ? 18 : 16,
                          ),
                        ),
                        SizedBox(width: screenWidth > 400 ? 14 : 12),
                        
                        // Theme name and description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                themeProvider.getThemeName(theme),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: screenWidth > 400 ? 14 : 13,
                                  color: isSelected 
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        // Selection indicator
                        if (isSelected)
                          Container(
                            width: screenWidth > 400 ? 20 : 18,
                            height: screenWidth > 400 ? 20 : 18,
                            margin: EdgeInsets.only(left: screenWidth > 400 ? 8 : 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: screenWidth > 400 ? 14 : 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // Get preview color for theme tiles
  Color _getThemePreviewColor(themeprovider.ThemeMode theme) {
    switch (theme) {
      case themeprovider.ThemeMode.sunset:
        return const Color(0xFFFF6B35);
      case themeprovider.ThemeMode.sunrise:
        return const Color(0xFFFFB74D);
      case themeprovider.ThemeMode.fullMoon:
        return const Color(0xFF90CAF9);
      case themeprovider.ThemeMode.forest:
        return const Color(0xFF2E7D32);
      case themeprovider.ThemeMode.ocean:
        return const Color(0xFF0277BD);
      case themeprovider.ThemeMode.reef:
        return const Color(0xFFFF7043);
      case themeprovider.ThemeMode.cherry:
        return const Color(0xFFE91E63);
      case themeprovider.ThemeMode.lavender:
        return const Color(0xFF9C27B0);
      case themeprovider.ThemeMode.autumn:
        return const Color(0xFFD84315);
      case themeprovider.ThemeMode.winter:
        return const Color(0xFF1976D2);
      case themeprovider.ThemeMode.desert:
        return const Color(0xFFD7CCC8);
      case themeprovider.ThemeMode.galaxy:
        return const Color(0xFF7C4DFF);
      case themeprovider.ThemeMode.emerald:
        return const Color(0xFF00695C);
      case themeprovider.ThemeMode.ruby:
        return const Color(0xFFC62828);
      case themeprovider.ThemeMode.sapphire:
        return const Color(0xFF1565C0);
      case themeprovider.ThemeMode.amber:
        return const Color(0xFFFF8F00);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }


  // Navigation Bar Selector Widget
  Widget _buildNavigationBarSelector() {
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Icon(
                    Icons.navigation,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Navigation Style',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            RadioListTile<NavigationBarType>(
              title: const Text('Google Nav Bar'),
              subtitle: const Text('Modern pill-shaped navigation'),
              value: NavigationBarType.google,
              groupValue: navigationProvider.navigationBarType,
              onChanged: (value) {
                final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                if (value != null) {
                  navigationProvider.setNavigationBarType(value);
                }
              },
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.rounded_corner,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
            RadioListTile<NavigationBarType>(
              title: const Text('Circle Nav Bar'),
              subtitle: const Text('Circular center button navigation'),
              value: NavigationBarType.circle,
              groupValue: navigationProvider.navigationBarType,
              onChanged: (value) {
                final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                if (value != null) {
                  navigationProvider.setNavigationBarType(value);
                }
              },
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.circle,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
              ),
            ),
            RadioListTile<NavigationBarType>(
              title: const Text('Floating Nav Bar'),
              subtitle: const Text('Disappears when scrolling up'),
              value: NavigationBarType.floating,
              groupValue: navigationProvider.navigationBarType,
              onChanged: (value) {
                final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                if (value != null) {
                  navigationProvider.setNavigationBarType(value);
                }
              },
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.keyboard_arrow_up,
                  color: Theme.of(context).colorScheme.tertiary,
                  size: 20,
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  // Games Section
  Widget _buildGamesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.borderLarge,
      ),
      child: Padding(
        padding: AppDesign.paddingLarge,
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
                  Colors.green,
                  () {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SnakePage()),
                    );
                  },
                ),
                // Add more game cards in the future
                _buildGameCard('Coming Soon', Icons.airplanemode_active,
                    Colors.amber, () {},
                    enabled: false),
                _buildGameCard(
                  'Coming Soon',
                  Icons.pending,
                  Colors.purple,
                  () {},
                  enabled: false,
                ),
              ],
            ),
          ],
        ),
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
      print('Error during logout: $e');
      hapticsProvider.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during logout: $e')),
      );
    }
  }

  
}




