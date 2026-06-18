import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart' as supabase;
import '../main.dart';
import 'JoinRequestsAdmin.dart';
import '../providers/societyprovider.dart';
import 'package:provider/provider.dart';
import '../models/hourrequirement.dart';
import '../common/iconselector.dart';
import '../common/app_design.dart';
import '../common/app_widgets.dart';
import '../screens/adminleadershippage.dart';
import '../providers/hapticsprovider.dart';

class SocietyAdminPage extends StatefulWidget {
  const SocietyAdminPage({Key? key}) : super(key: key);

  @override
  _SocietyAdminPageState createState() => _SocietyAdminPageState();
}

class _SocietyAdminPageState extends State<SocietyAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _meetingRequirementController;
  late TextEditingController _errorFormUrlController;
  late TextEditingController _imageUrlController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Get society from provider
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;

    _nameController = TextEditingController(text: society?.name ?? '');
    _descriptionController =
        TextEditingController(text: society?.description ?? '');
    _errorFormUrlController =
        TextEditingController(text: society?.errorFormUrl ?? '');
    _meetingRequirementController = TextEditingController(
        text: society?.meetingRequirement.toString() ?? '5');
    _imageUrlController = TextEditingController(text: society?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _meetingRequirementController.dispose();
    _errorFormUrlController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveSocietyDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<SocietyProvider>(context, listen: false);
      final society = provider.currentSociety;

      if (society == null) {
        throw Exception('No society selected');
      }

      // Update society details
      await supabase.Supabase.instance.client.from('honor_societies').update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'meeting_requirement': int.parse(_meetingRequirementController.text),
        'image_url': _imageUrlController.text.trim().isNotEmpty
            ? _imageUrlController.text.trim()
            : null,
        'error_form_url': _errorFormUrlController.text.trim().isNotEmpty
            ? _errorFormUrlController.text.trim()
            : null,
      }).eq('id', society.id);

      // Refresh provider data
      await provider.refreshCurrentSociety();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Society details updated successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating society: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Consumer<SocietyProvider>(builder: (context, provider, _) {
      final society = provider.currentSociety;

      if (provider.isLoading || society == null) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Society Administration'),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
          scrolledUnderElevation: AppDesign.elevationSmall,
          title: Text(
            'Society Administration',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(
                icon: Icon(Icons.settings),
                text: 'Society Details',
              ),
              Tab(
                icon: Icon(Icons.assignment),
                text: 'Hour Requirements',
              ),
            ],
          ),
        ),
        body: Container(
          constraints: BoxConstraints(
            maxWidth: isWideScreen ? 1200 : double.infinity,
          ),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSocietyDetailsTab(isWideScreen),
              const HourRequirementsPage(),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSocietyDetailsTab(bool isWideScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(
          isWideScreen ? AppDesign.spacingXL : AppDesign.spacingL),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isWideScreen ? 800 : double.infinity,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Section
                _buildHeaderSection(),

                SizedBox(height: AppDesign.spacingXL),

                // Society Image Section
                _buildImageSection(),

                SizedBox(height: AppDesign.spacingXL),

                // Basic Information Section
                _buildBasicInfoSection(),

                SizedBox(height: AppDesign.spacingXL),

                // Configuration Section
                _buildConfigurationSection(),

                SizedBox(height: AppDesign.spacingXXL),

                // Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Container(
          padding: AppDesign.paddingLarge,
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: AppDesign.borderLarge,
          ),
          child: Row(
            children: [
              Container(
                padding: AppDesign.paddingMedium,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: AppDesign.borderMedium,
                ),
                child: Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 28,
                ),
              ),
              SizedBox(width: AppDesign.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Society Management',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    SizedBox(height: AppDesign.spacingXS),
                    Text(
                      'Configure your honor society settings and requirements',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.8),
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

  Widget _buildImageSection() {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            icon: Icons.image,
            title: 'Society Logo',
            subtitle: 'Add a logo to represent your honor society',
          ),
          SizedBox(height: AppDesign.spacingL),

          // Image Preview
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: AppDesign.borderXLarge,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: AppDesign.borderXLarge,
                child: _imageUrlController.text.trim().isNotEmpty
                    ? Image.network(
                        _imageUrlController.text.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        child: Icon(
                          Icons.school,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
          ),

          SizedBox(height: AppDesign.spacingL),

          // Image URL Input
          AppTextField(
            label: 'Image URL',
            hint: 'https://example.com/logo.png',
            controller: _imageUrlController,
            prefixIcon: Icons.link,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final uri = Uri.tryParse(value.trim());
                if (uri == null || !uri.hasScheme) {
                  return 'Please enter a valid URL';
                }
              }
              return null;
            },
            onChanged: (value) {
              // Trigger rebuild to update image preview
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            icon: Icons.info_outline,
            title: 'Basic Information',
            subtitle: 'Essential details about your honor society',
          ),
          SizedBox(height: AppDesign.spacingL),
          AppTextField(
            label: 'Society Name',
            hint: 'Enter the official name of your society',
            controller: _nameController,
            prefixIcon: Icons.school,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the society name';
              }
              return null;
            },
          ),
          SizedBox(height: AppDesign.spacingM),
          AppTextField(
            label: 'Description',
            hint: 'Describe your society\'s mission and goals',
            controller: _descriptionController,
            prefixIcon: Icons.description,
            keyboardType: TextInputType.multiline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationSection() {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            icon: Icons.tune,
            title: 'Configuration',
            subtitle: 'Set requirements and external links',
          ),
          SizedBox(height: AppDesign.spacingL),
          AppTextField(
            label: 'Meeting Requirement',
            hint: '5',
            controller: _meetingRequirementController,
            prefixIcon: Icons.groups,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the meeting requirement';
              }
              if (int.tryParse(value.trim()) == null) {
                return 'Please enter a valid number';
              }
              return null;
            },
          ),
          SizedBox(height: AppDesign.spacingM),
          AppTextField(
            label: 'Error/Issue Form URL',
            hint: 'https://forms.google.com/...',
            controller: _errorFormUrlController,
            prefixIcon: Icons.bug_report,
            keyboardType: TextInputType.url,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final uri = Uri.tryParse(value.trim());
                if (uri == null || !uri.hasScheme) {
                  return 'Please enter a valid URL (starting with http:// or https://)';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Join Requests Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const JoinRequestsAdminPage(),
                ),
              );
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Manage Join Requests'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDesign.spacingL,
                vertical: AppDesign.spacingM,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: AppDesign.borderMedium,
              ),
            ),
          ),
        ),

        SizedBox(height: AppDesign.spacingM),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminLeadershipPage(),
                ),
              );
            },
            icon: const Icon(Icons.groups_3),
            label: const Text('Manage Leadership'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDesign.spacingL,
                vertical: AppDesign.spacingM,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: AppDesign.borderMedium,
              ),
            ),
          ),
        ),

        SizedBox(height: AppDesign.spacingM),

        SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:   _isLoading ? null : _saveSocietyDetails,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:  _isLoading
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
                          : const Text('Save Society Details'),
                    ),
                  ),
      ],
    );
  }
}

/// Enhanced page for managing hour requirements
class HourRequirementsPage extends StatefulWidget {
  const HourRequirementsPage({Key? key}) : super(key: key);

  @override
  _HourRequirementsPageState createState() => _HourRequirementsPageState();
}

class _HourRequirementsPageState extends State<HourRequirementsPage> {
  List<HourRequirement> _requirements = [];
  bool _isLoading = false;

  // Shared by the add/edit dialogs. Owned by this State (not the dialog) so
  // they survive the dialog's dismiss animation and are disposed exactly once.
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRequirements();
  }

  @override
  void dispose() {
    _typeController.dispose();
    _descriptionController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  void _loadRequirements() {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society != null) {
      setState(() {
        _requirements = List.from(society.hourRequirements);
      });
    }
  }

  void _showEditRequirementDialog(HourRequirement requirement) {
    _typeController.text = requirement.type;
    _descriptionController.text = requirement.description;
    _hoursController.text = requirement.hoursNeeded.toString();
    String iconName = requirement.iconName;
    bool isActive = requirement.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Hour Requirement'),
          shape: RoundedRectangleBorder(
            borderRadius: AppDesign.borderLarge,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'Type Name',
                  controller: _typeController,
                  prefixIcon: Icons.label_outline,
                ),
                const SizedBox(height: AppDesign.spacingM),
                AppTextField(
                  label: 'Description',
                  controller: _descriptionController,
                  maxLines: 2,
                ),
                const SizedBox(height: AppDesign.spacingM),
                AppTextField(
                  label: 'Hours Required',
                  controller: _hoursController,
                  prefixIcon: Icons.timelapse,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppDesign.spacingM),
                IconSelector(
                  initialValue: iconName,
                  onChanged: (value) =>
                      setDialogState(() => iconName = value),
                ),
                const SizedBox(height: AppDesign.spacingM),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.3),
                    borderRadius: AppDesign.borderMedium,
                  ),
                  child: SwitchListTile(
                    title: const Text('Active'),
                    subtitle: const Text(
                        'Inactive requirements won\'t be counted or displayed'),
                    value: isActive,
                    onChanged: (value) =>
                        setDialogState(() => isActive = value),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Provider.of<HapticsProvider>(context, listen: false)
                    .selection();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<HapticsProvider>(context, listen: false)
                    .selection();
                _showDeleteConfirmation(requirement);
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
            FilledButton(
              onPressed: () => _saveEditedRequirement(
                requirement: requirement,
                type: _typeController.text.trim(),
                description: _descriptionController.text.trim(),
                hours: double.tryParse(_hoursController.text.trim()) ??
                    requirement.hoursNeeded,
                isActive: isActive,
                iconName: iconName,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEditedRequirement({
    required HourRequirement requirement,
    required String type,
    required String description,
    required double hours,
    required bool isActive,
    required String iconName,
  }) async {
    Provider.of<HapticsProvider>(context, listen: false).selection();

    if (type.isEmpty || hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter a type name and hours greater than 0'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.Supabase.instance.client
          .from('hour_requirements')
          .update({
        'type': type,
        'description': description,
        'hours_needed': hours,
        'is_active': isActive,
        'icon_name': iconName,
      }).eq('id', requirement.id);

      if (!mounted) return;
      setState(() {
        final index = _requirements.indexWhere((r) => r.id == requirement.id);
        if (index != -1) {
          _requirements[index] = HourRequirement(
            id: requirement.id,
            type: type,
            description: description,
            hoursNeeded: hours,
            isActive: isActive,
            iconName: iconName,
          );
        }
      });
      await Provider.of<SocietyProvider>(context, listen: false)
          .refreshCurrentSociety();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Requirement updated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating requirement: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDeleteConfirmation(HourRequirement requirement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Requirement'),
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderLarge,
        ),
        content: Text(
          'Are you sure you want to delete the ${requirement.type} requirement? '
          'This will affect all historical records using this type.',
        ),
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
          FilledButton(
            onPressed: () async {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              setState(() => _isLoading = true);
              try {
                await supabase.Supabase.instance.client
                    .from('hour_requirements')
                    .delete()
                    .eq('id', requirement.id);

                setState(() {
                  _requirements.removeWhere((r) => r.id == requirement.id);
                });

                await Provider.of<SocietyProvider>(context, listen: false)
                    .refreshCurrentSociety();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Requirement deleted successfully'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting requirement: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddRequirementDialog() {
    _typeController.clear();
    _descriptionController.clear();
    _hoursController.clear();
    String iconName = 'workspaces';
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Hour Requirement'),
          shape: RoundedRectangleBorder(
            borderRadius: AppDesign.borderLarge,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'Type Name',
                  hint: 'E.g., Service, Tutoring, Leadership',
                  controller: _typeController,
                  prefixIcon: Icons.label_outline,
                ),
                const SizedBox(height: AppDesign.spacingM),
                AppTextField(
                  label: 'Description',
                  hint: 'Describe what counts for this requirement',
                  controller: _descriptionController,
                  maxLines: 2,
                ),
                const SizedBox(height: AppDesign.spacingM),
                AppTextField(
                  label: 'Hours Required',
                  hint: 'E.g., 10.0',
                  controller: _hoursController,
                  prefixIcon: Icons.timelapse,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppDesign.spacingM),
                IconSelector(
                  initialValue: iconName,
                  onChanged: (value) =>
                      setDialogState(() => iconName = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Provider.of<HapticsProvider>(context, listen: false)
                    .selection();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _saveNewRequirement(
                societyId: society?.id,
                type: _typeController.text.trim(),
                description: _descriptionController.text.trim(),
                hours: double.tryParse(_hoursController.text.trim()) ?? 0,
                iconName: iconName,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNewRequirement({
    required int? societyId,
    required String type,
    required String description,
    required double hours,
    required String iconName,
  }) async {
    Provider.of<HapticsProvider>(context, listen: false).selection();

    if (type.isEmpty || hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter a type name and hours greater than 0'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (societyId == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await supabase.Supabase.instance.client
          .from('hour_requirements')
          .insert({
            'society_id': societyId,
            'type': type,
            'description': description,
            'hours_needed': hours,
            'is_active': true,
            'icon_name': iconName,
          })
          .select()
          .single();

      if (!mounted) return;
      setState(() {
        _requirements.add(HourRequirement.fromJson(response));
      });
      await Provider.of<SocietyProvider>(context, listen: false)
          .refreshCurrentSociety();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Requirement added successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding requirement: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SocietyProvider>(builder: (context, provider, _) {
      if (_requirements.isEmpty && provider.currentSociety != null) {
        _requirements = List.from(provider.currentSociety!.hourRequirements);
      }

      return Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                color: Theme.of(context).colorScheme.primary,
                onRefresh: () async {
                  await provider.refreshCurrentSociety();
                  if (provider.currentSociety != null) {
                    setState(() {
                      _requirements =
                          List.from(provider.currentSociety!.hourRequirements);
                    });
                  }
                },
                child: _requirements.isEmpty
                    ? _buildEmptyState()
                    : _buildRequirementsList(),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            final hapticsProvider =
                Provider.of<HapticsProvider>(context, listen: false);
            hapticsProvider.selection();
            _showAddRequirementDialog();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Requirement'),
        ),
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: AppDesign.paddingLarge,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: AppDesign.paddingLarge,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                borderRadius: AppDesign.borderRound,
              ),
              child: Icon(
                Icons.assignment_add,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.6),
              ),
            ),
            SizedBox(height: AppDesign.spacingL),
            Text(
              'No Requirements Defined',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            SizedBox(height: AppDesign.spacingS),
            Text(
              'Create hour requirements to track student progress',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppDesign.spacingL),
            FilledButton.icon(
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                _showAddRequirementDialog();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Requirement'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementsList() {
    return ListView.builder(
      padding: AppDesign.paddingMedium,
      itemCount: _requirements.length,
      itemBuilder: (context, index) {
        final requirement = _requirements[index];
        return AppContentCard(
          margin: const EdgeInsets.only(bottom: AppDesign.spacingM),
          child: InkWell(
            borderRadius: AppDesign.borderLarge,
            onTap: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              _showEditRequirementDialog(requirement);
            },
            child: Padding(
              padding: AppDesign.paddingMedium,
              child: Row(
                children: [
                Container(
                  padding: AppDesign.paddingMedium,
                  decoration: BoxDecoration(
                    color: requirement.isActive
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: AppDesign.borderMedium,
                  ),
                  child: Icon(
                    getIconDataByName(requirement.iconName),
                    color: requirement.isActive
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                SizedBox(width: AppDesign.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              requirement.type,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: requirement.isActive
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                            ),
                          ),
                          if (!requirement.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDesign.spacingS,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant,
                                borderRadius: AppDesign.borderSmall,
                              ),
                              child: Text(
                                'Inactive',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: AppDesign.spacingXS),
                      Text(
                        requirement.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      SizedBox(height: AppDesign.spacingXS),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDesign.spacingS,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          borderRadius: AppDesign.borderSmall,
                        ),
                        child: Text(
                          '${requirement.hoursNeeded} hours required',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppDesign.spacingS),
                Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
