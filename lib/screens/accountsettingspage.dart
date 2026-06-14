import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../common/app_design.dart';
import '../common/app_widgets.dart';
import 'package:provider/provider.dart';
import '../providers/hapticsprovider.dart';

// Import your shared constants/styles
final supabase = Supabase.instance.client;
final lowModeShadow = [
  BoxShadow(
    color: Colors.black.withOpacity(0.1),
    blurRadius: 8,
    offset: const Offset(0, 4),
  )
];

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({Key? key}) : super(key: key);

  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  // State variables
  final _emailFormKey = GlobalKey<FormState>();

  final _passwordFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _graduationYearController = TextEditingController();

  String _currentEmail = '';
  bool _isLoadingEmail = false;
  bool _isLoadingPassword = false;
  bool _isLoadingProfile = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserEmail();
    _fetchUserProfileDetails();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newEmailController.dispose();
    _graduationYearController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserEmail() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    String email = '';

    // First try to get from profiles table (prioritized)
    try {
      final profileResponse = await supabase
          .from('profiles')
          .select('email')
          .eq('user_id', user.id)
          .single();

      email = profileResponse['email'] ?? '';
    } catch (profileError) {
      debugPrint('Error fetching email from profiles table: $profileError');
      // Fallback to auth email if profiles table fails
      email = user.email ?? '';
    }

    // If profiles table email is empty, fallback to auth email
    if (email.isEmpty) {
      email = user.email ?? '';
    }

    setState(() {
      _currentEmail = email;
      _newEmailController.text = email;
    });
  }

  Future<void> _fetchUserProfileDetails() async {
    setState(() => _isLoadingProfile = true);

    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      String graduationYear = '';

      // First try to get from profiles table (prioritized)
      try {
        final profileResponse = await supabase
            .from('profiles')
            .select('graduation_year, name, email')
            .eq('user_id', user.id)
            .single();

        graduationYear = profileResponse['graduation_year']?.toString() ?? '';
      } catch (profileError) {
        debugPrint('Error fetching from profiles table: $profileError');

        // Fallback to auth metadata if profiles table fails
        final userMetadata = user.userMetadata;
        graduationYear = userMetadata?['graduation_year']?.toString() ?? '';
      }

      if (mounted) {
        
        setState(() {
          _graduationYearController.text = graduationYear;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showToast('Error fetching profile details');
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> updateProfileDetails() async {
    
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _isLoadingProfile = true);

    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final gradYear = int.tryParse(_graduationYearController.text.trim());
      // Update profiles table first (prioritized)
      try {
        await supabase.from('profiles').update({
          'graduation_year': gradYear,
        }).eq('user_id', user.id);
      } catch (profileError) {
        debugPrint('Error updating profiles table: $profileError');
        // Continue to update auth metadata even if profiles table update fails
      }

      // Also update user metadata for consistency
      try {
        await supabase.auth.updateUser(
          UserAttributes(
            data: {
              ...user.userMetadata ?? {}, // Preserve existing metadata
              'graduation_year': gradYear
            },
          ),
        );
      } catch (authError) {
        debugPrint('Error updating auth metadata: $authError');
        // Continue since profiles table is prioritized
      }

      if (mounted) {
        _showToast('Profile Updated Successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showToast('Profile Update Failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  /// Updates the user's email address
  Future<void> _updateEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final newEmail = _newEmailController.text.trim();
    if (newEmail == _currentEmail) {
      _showToast(
        'No change',
      );
      return;
    }

    final user = supabase.auth.currentUser;

    setState(() => _isLoadingEmail = true);

    try {
      await supabase.from('profiles').update({
        'email': newEmail,
      }).eq('user_id', user!.id);

      await supabase.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      _showToast(
        'Verification Email Sent, Please check your new email address to confirm the change.',
      );
    } catch (e) {
      _showToast(
        'Email Update Failed',
      );
    } finally {
      setState(() => _isLoadingEmail = false);
    }
  }

  /// Updates the user's password
  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    final newPassword = _newPasswordController.text;

    setState(() => _isLoadingPassword = true);

    try {
      // First verify current password by signing in
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Update password
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // Clear the form
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showToast(
        'Password Updated',
      );
    } catch (e) {
      _showToast(
        'Password Update Failed',
      );
    } finally {
      setState(() => _isLoadingPassword = false);
    }
  }

  /// Shows a toast notification
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we're on a larger screen
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 900;
    final bool isMediumScreen = screenWidth > 600 && screenWidth <= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Account Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: AppDesign.elevationNone,
        scrolledUnderElevation: AppDesign.elevationSmall,
      ),
      body: SafeArea(
        child: Center(
          // Constrain max width on larger screens for better readability
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isWideScreen
                  ? 1200
                  : isMediumScreen
                      ? 700
                      : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal:
                    isWideScreen ? AppDesign.spacingL : AppDesign.spacingL,
                vertical: AppDesign.spacingL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section
                  _buildHeader(isWideScreen),

                  SizedBox(
                      height: isWideScreen
                          ? AppDesign.spacingXXL
                          : AppDesign.spacingL),

                  // Content area - responsive layout
                  if (isWideScreen)
                    // Wide screen layout (side by side)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildProfileSection()),
                        const SizedBox(width: AppDesign.spacingL),
                        Expanded(child: _buildEmailSection()),
                        const SizedBox(width: AppDesign.spacingL),
                        Expanded(child: _buildPasswordSection()),
                      ],
                    )
                  else if (isMediumScreen)
                    // Medium screen layout (more padding, sequential)
                    Column(
                      children: [
                        Container(
                          width: 550, // Fixed width for medium screens
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppDesign.spacingL,
                          ),
                          child: _buildProfileSection(),
                        ),
                        Container(
                          width: 550, // Fixed width for medium screens
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppDesign.spacingL,
                          ),
                          child: _buildEmailSection(),
                        ),
                        const SizedBox(height: AppDesign.spacingL),
                        Container(
                          width: 550, // Fixed width for medium screens
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppDesign.spacingL,
                          ),
                          child: _buildPasswordSection(),
                        ),
                      ],
                    )
                  else
                    // Mobile layout (full width, sequential)
                    Column(
                      children: [
                        const SizedBox(width: AppDesign.spacingL),
                        _buildProfileSection(),
                        const SizedBox(width: AppDesign.spacingL),
                        _buildEmailSection(),
                        const SizedBox(height: AppDesign.spacingL),
                        _buildPasswordSection(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    final currentYear = DateTime.now().year;
    final List<String> graduationYears =
        List.generate(7, (i) => (currentYear - 2 + i).toString());
    final storedYear = _graduationYearController.text;
    final dropdownValue = graduationYears.contains(storedYear) ? storedYear : null;
    return AppSurfaceCard(
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            const AppSectionHeader(
              icon: Icons.person_outline,
              title: 'Profile Details',
              subtitle: 'Update your graduation year',
            ),
            const SizedBox(height: AppDesign.spacingL),

            DropdownButtonFormField<String>(
              value: dropdownValue,
              decoration: const InputDecoration(
                labelText: 'Graduation Year',
                prefixIcon: Icon(Icons.school),
                border: OutlineInputBorder(),
              ),
              items: graduationYears
                  .map((year) => DropdownMenuItem(
                        value: year,
                        child: Text(year),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _graduationYearController.text = value ?? '';
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your graduation year';
                }
                return null;
              },
            ),
            const SizedBox(height: AppDesign.spacingL),

            // Save Button

            SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoadingProfile ? null : updateProfileDetails,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoadingPassword
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Center(
                                  child: CircularProgressIndicator(),
                                ),
                                SizedBox(width: 16),
                                Text('Processing...'),
                              ],
                            )
                          : const Text('Update Profile'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWideScreen) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: isWideScreen ? 50 : 40,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: isWideScreen ? 50 : 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppDesign.spacingM),
          Text(
            'Account Security',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppDesign.spacingXS),
          Text(
            'Update your email address and password',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailSection() {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          const AppSectionHeader(
            icon: Icons.email_outlined,
            title: 'Email Address',
            subtitle: 'Change the email address associated with your account',
          ),
          const SizedBox(height: AppDesign.spacingL),

          // Current Email
          Row(
            children: [
              Text(
                'Current Email:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppDesign.spacingXS),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDesign.spacingS,
                    horizontal: AppDesign.spacingM,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: AppDesign.borderSmall,
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    _currentEmail,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.spacingL),

          // New Email Form
          Form(
            key: _emailFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'New Email Address',
                  prefixIcon: Icons.email,
                  controller: _newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your new email address';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDesign.spacingL),

                // Save Button

                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoadingEmail ? null : _updateEmail,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoadingPassword
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Center(
                                  child: CircularProgressIndicator(),
                                ),
                                SizedBox(width: 16),
                                Text('Processing...'),
                              ],
                            )
                          : const Text('Update Email'),
                    ),
                  ),

                const SizedBox(height: AppDesign.spacingS),

                Center(
                  child: Text(
                    'A verification email will be sent to your new address',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Password',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Change your account password',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),

            // Password Form
            Form(
              key: _passwordFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // New Password
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoadingPassword ? null : _updatePassword,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoadingPassword
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Center(
                                  child: CircularProgressIndicator(),
                                ),
                                SizedBox(width: 16),
                                Text('Processing...'),
                              ],
                            )
                          : const Text('Update Password'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Password Requirements
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password Requirements:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRequirementRow('At least 8 characters long'),
                        _buildRequirementRow(
                            'Include upper and lowercase letters'),
                        _buildRequirementRow('Include at least one number'),
                        _buildRequirementRow(
                            'Include at least one special character'),
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

  Widget _buildRequirementRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
