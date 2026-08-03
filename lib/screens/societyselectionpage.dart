import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import '../models/honorsociety.dart';
import 'societyjoinrequestpage.dart';
import 'mainscreen.dart';
import '../providers/hapticsprovider.dart';
import '../data/supabase_client.dart';


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
            onPressed: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              _confirmLogout(context);
            },
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
                      final hapticsProvider =
                          Provider.of<HapticsProvider>(context, listen: false);
                      hapticsProvider.selection();
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
                        borderRadius: AppDesign.borderMedium,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Use ResponsiveGridView for better layout on different screen sizes
          return Padding(
            padding: AppDesign.paddingMedium,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                childAspectRatio: 0.9, // More square aspect ratio
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: societies.length,
              itemBuilder: (context, index) {
                final society = societies[index];
                return _buildSocietyCard(context, society, index);
              },
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(context),
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
        borderRadius: AppDesign.borderLarge,
        side: BorderSide(
          color: borderColor,
          width: 1.0,
        ),
      ),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () {
          final hapticsProvider =
              Provider.of<HapticsProvider>(context, listen: false);
          hapticsProvider.selection();
          _selectSociety(context, society);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image section - takes most of the card space
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Society image or placeholder
                  society.imageUrl != null
                      ? Image.network(
                          society.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: imageColor,
                            child: Center(
                              child: Icon(
                                Icons.school,
                                size: 48,
                                color: cardColor.withOpacity(0.7),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: imageColor,
                          child: Center(
                            child: Icon(
                              Icons.school,
                              size: 48,
                              color: cardColor.withOpacity(0.7),
                            ),
                          ),
                        ),

                ],
              ),
            ),

            // Society name and select button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppDesign.radiusLarge),
                  bottomRight: Radius.circular(AppDesign.radiusLarge),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Society name with constrained width
                  Expanded(
                    child: Text(
                      society.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Select button
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          _selectSociety(context, society);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 20,
                            color: cardColor,
                          ),
                        ),
                      ),
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

  void _selectSociety(BuildContext context, HonorSociety society) async {
    final provider = Provider.of<SocietyProvider>(context, listen: false);

    // Capture navigator/messenger before any async gaps.
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // No manual loading dialog here: setCurrentSociety() flips
    // SocietyProvider.isLoading, which the Consumer body already renders as a
    // single spinner. Showing a dialog on top produced two overlapping
    // loading circles.
    try {
      await provider.setCurrentSociety(society.id);

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false, // This removes all previous routes
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error selecting society: $e')),
      );
    }
  }

  Widget _buildBottomBar(BuildContext context) {
    // Check if we're on a wide screen
    final bool isWideScreen = MediaQuery.of(context).size.width > 600;

    // Colors based on theme
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    if (isWideScreen) {
      // Web layout - horizontal arrangement
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Join society button
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ElevatedButton.icon(
                onPressed: () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  backgroundColor: primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDesign.borderMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Log out button
            Container(
              constraints: const BoxConstraints(maxWidth: 200),
              child: OutlinedButton.icon(
                onPressed: () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();
                  _confirmLogout(context);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  side: BorderSide(color: primaryColor),
                  foregroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDesign.borderMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile layout - vertical arrangement
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDesign.radiusMedium),
          ),
          border: Border(
            top: BorderSide(
              color: primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Join society button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDesign.borderMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Log out button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();
                  _confirmLogout(context);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: primaryColor),
                  foregroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDesign.borderMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
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
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
