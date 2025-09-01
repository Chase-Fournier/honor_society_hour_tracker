import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../common/app_design.dart';
import '../common/app_widgets.dart';
import 'societyselectionpage.dart';
import 'waitingpage.dart';
import '../providers/hapticsprovider.dart';

final supabase = Supabase.instance.client;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppDesign.animationMedium,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Responsive design adjustments
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;
    final isTabletScreen = screenWidth > 600 && screenWidth <= 900;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
       
            constraints: BoxConstraints(
              maxWidth: isWideScreen
                  ? 1200
                  : isTabletScreen
                      ? 600
                      : double.infinity,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isWideScreen ? 0 : AppDesign.spacingL,
              vertical: AppDesign.spacingL,
            ),
            child: isWideScreen ? _buildWideLayout() : _buildMobileLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: const EdgeInsets.all(AppDesign.spacingL),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDesign.radiusXLarge),
                  bottomLeft: Radius.circular(AppDesign.radiusXLarge),
                ),
              ),
              child: _buildMarketingContent(),
            ),
          ),
        ),

        // Right section with auth form
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(AppDesign.spacingL),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(AppDesign.radiusXLarge),
                bottomRight: Radius.circular(AppDesign.radiusXLarge),
              ),
              boxShadow: AppDesign.shadowSmall(context),
            ),
            child: _buildAuthForm(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return AppCard(
      
      elevation: AppDesign.elevationSmall,
      borderRadius: AppDesign.borderXLarge,
      padding: AppDesign.paddingLarge,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildCompactHeader(),
          ),
          _buildAuthForm(),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Column(
      children: [
        Icon(
          Icons.school,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppDesign.spacingM),
        Center(
          child: Text(
            'Society Hour Tracking',
            style: TextStyle(
              fontSize: 28.0,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppDesign.spacingXS),
        Text(
          'Sign in to your account',
          style: TextStyle(
            fontSize: 16.0,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDesign.spacingL),
      ],
    );
  }

  Widget _buildMarketingContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.school,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppDesign.spacingL),
        Text(
          'Society Hour Tracking',
          style: TextStyle(
            fontSize: 32.0,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: AppDesign.spacingM),
        Text(
          'Track service hours, manage events, and connect with your honor society - all in one place.',
          style: TextStyle(
            fontSize: 18.0,
            color: Theme.of(context)
                .colorScheme
                .onPrimaryContainer
                .withOpacity(0.8),
          ),
        ),
        const SizedBox(height: AppDesign.spacingL),
        // Feature bullets
        _buildFeatureRow(
            Icons.volunteer_activism, 'Record community service hours'),
        const SizedBox(height: AppDesign.spacingS),
        _buildFeatureRow(Icons.event_available, 'Sign up for upcoming events'),
        const SizedBox(height: AppDesign.spacingS),
        _buildFeatureRow(
            Icons.insights, 'Track your progress towards requirements'),
        const SizedBox(height: AppDesign.spacingS),
        _buildFeatureRow(Icons.people, 'Connect with your honor society'),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDesign.spacingS),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: AppDesign.borderSmall,
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: AppDesign.spacingS),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  elevation: 4,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDesign.borderMedium,
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSecondary
                          .withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            child: SupaEmailAuth(
              onSignUpComplete: (response) {
                // Navigate to a waiting page after sign-up
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const WaitingPage()),
                );
              },
              redirectTo: kIsWeb
                  ? null
                  : 'com.wheelermun.nhs://callback', // For email confirmation
              resetPasswordRedirectTo: kIsWeb
                  ? 'https://nhs.wheelermun.com/reset-password-handler'
                  : 'com.wheelermun.nhs://reset-password', // For password reset
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
              metadataFields: [
                MetaDataField(
                  prefixIcon: const Icon(Icons.person),
                  label: 'Name',
                  key: 'name',
                  validator: (val) {
                    return val == null || val.isEmpty
                        ? 'Please enter your name'
                        : null;
                  },
                ),
                MetaDataField(
                  prefixIcon: const Icon(Icons.school),
                  label: 'Graduation Year',
                  key: 'graduation_year',
                  validator: (val) {
                    return val == null || val.isEmpty
                        ? 'Please enter your graduation year'
                        : null;
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDesign.spacingM),

          // Optional social login section
          SupaSocialsAuth(
            socialProviders: const [],
            colored: true,
            onSuccess: (Session response) {
              // Navigate to the home page on successful social sign-in
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SocietySelectionPage()),
              );
            },
            onError: (error) {
              // Handle the error
              print('Social sign-in error: $error');
            },
          ),
        ],
      ),
    );
  }
}
