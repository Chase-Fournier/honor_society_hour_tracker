import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../providers/societyprovider.dart';
import '../models/leadershiprole.dart';
import '../common/app_design.dart';
import '../common/app_widgets.dart';
import '../providers/hapticsprovider.dart';

final supabase = Supabase.instance.client;

class AdminLeadershipPage extends StatefulWidget {
  const AdminLeadershipPage({Key? key}) : super(key: key);

  @override
  _AdminLeadershipPageState createState() => _AdminLeadershipPageState();
}

class _AdminLeadershipPageState extends State<AdminLeadershipPage> {
  List<LeadershipRole> _leadershipRoles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeadershipRoles();
  }

  Future<void> _fetchLeadershipRoles() async {
    setState(() => _isLoading = true);

    try {
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await supabase
          .from('leadership_roles')
          .select()
          .eq('society_id', society.id)
          .order('display_order');

      setState(() {
        _leadershipRoles = response
            .map<LeadershipRole>((json) => LeadershipRole.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching leadership roles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading leadership roles: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _showAddRoleDialog() {
    _showRoleDialog();
  }

  void _showEditRoleDialog(LeadershipRole role) {
    _showRoleDialog(role: role);
  }

  void _showRoleDialog({LeadershipRole? role}) {
    final isEditing = role != null;
    String title = role?.title ?? '';
    String description = role?.description ?? '';
    String holderName = role?.holderName ?? '';
    String email = role?.email ?? '';
    String phone = role?.phone ?? '';
    bool isActive = role?.isActive ?? true;
    int displayOrder = role?.displayOrder ?? (_leadershipRoles.length + 1);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title:
              Text(isEditing ? 'Edit Leadership Role' : 'Add Leadership Role'),
          shape: RoundedRectangleBorder(
            borderRadius: AppDesign.borderLarge,
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    label: 'Role Title',
                    hint: 'e.g., President, Vice President, Secretary',
                    controller: TextEditingController(text: title),
                    onChanged: (value) => title = value,
                    prefixIcon: Icons.title,
                  ),
                  SizedBox(height: AppDesign.spacingM),
                  AppTextField(
                    label: 'Role Holder Name',
                    hint: 'Full name of the person in this role',
                    controller: TextEditingController(text: holderName),
                    onChanged: (value) => holderName = value,
                    prefixIcon: Icons.person,
                  ),
                  SizedBox(height: AppDesign.spacingM),
                  AppTextField(
                    label: 'Email (Optional)',
                    hint: 'contact@example.com',
                    controller: TextEditingController(text: email),
                    onChanged: (value) => email = value,
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: AppDesign.spacingM),
                  AppTextField(
                    label: 'Phone (Optional)',
                    hint: '(555) 123-4567',
                    controller: TextEditingController(text: phone),
                    onChanged: (value) => phone = value,
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: AppDesign.spacingM),
                  AppTextField(
                    label: 'Role Description',
                    hint: 'Describe the responsibilities and duties...',
                    controller: TextEditingController(text: description),
                    onChanged: (value) => description = value,
                    prefixIcon: Icons.description,
                    keyboardType: TextInputType.multiline,
                  ),
                  SizedBox(height: AppDesign.spacingM),
                  AppTextField(
                    label: 'Display Order',
                    hint: 'Order in which this role appears (1 = first)',
                    controller:
                        TextEditingController(text: displayOrder.toString()),
                    onChanged: (value) =>
                        displayOrder = int.tryParse(value) ?? displayOrder,
                    prefixIcon: Icons.sort,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: AppDesign.spacingM),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
                      borderRadius: AppDesign.borderMedium,
                    ),
                    child: SwitchListTile(
                      title: const Text('Active Role'),
                      subtitle: const Text(
                          'Inactive roles won\'t be displayed to members'),
                      value: isActive,
                      onChanged: (value) => setState(() => isActive = value),
                    ),
                  ),
                ],
              ),
            ),
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
            if (isEditing)
              TextButton(
                onPressed: () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();
                  _showDeleteConfirmation(role);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            FilledButton(
              onPressed: () async {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                if (title.isNotEmpty &&
                    holderName.isNotEmpty &&
                    description.isNotEmpty) {
                  await _saveRole(
                    role,
                    title,
                    description,
                    holderName,
                    email.isEmpty ? null : email,
                    phone.isEmpty ? null : phone,
                    isActive,
                    displayOrder,
                  );
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRole(
    LeadershipRole? existingRole,
    String title,
    String description,
    String holderName,
    String? email,
    String? phone,
    bool isActive,
    int displayOrder,
  ) async {
    try {
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) return;

      final roleData = {
        'title': title,
        'description': description,
        'holder_name': holderName,
        'email': email,
        'phone': phone,
        'society_id': society.id,
        'is_active': isActive,
        'display_order': displayOrder,
      };

      if (existingRole != null) {
        // Update existing role
        await supabase
            .from('leadership_roles')
            .update(roleData)
            .eq('id', existingRole.id);
      } else {
        // Create new role
        roleData['created_at'] = DateTime.now().toIso8601String();
        await supabase.from('leadership_roles').insert(roleData);
      }

      await _fetchLeadershipRoles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existingRole != null
                ? 'Leadership role updated successfully'
                : 'Leadership role added successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving leadership role: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(LeadershipRole role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Leadership Role'),
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderLarge,
        ),
        content: Text(
          'Are you sure you want to delete the ${role.title} role? This action cannot be undone.',
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
              await _deleteRole(role);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
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

  Future<void> _deleteRole(LeadershipRole role) async {
    try {
      await supabase.from('leadership_roles').delete().eq('id', role.id);

      await _fetchLeadershipRoles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Leadership role deleted successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting leadership role: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SocietyProvider>(
      builder: (context, provider, _) {
        final society = provider.currentSociety;

        if (provider.isLoading || society == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              '${society.name} - Leadership',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24.0,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            elevation: 0,
            backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
            centerTitle: true,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchLeadershipRoles,
                  child: _leadershipRoles.isEmpty
                      ? _buildEmptyState()
                      : _buildLeadershipList(),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              _showAddRoleDialog();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Role'),
          ),
        );
      },
    );
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
                Icons.supervisor_account,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.6),
              ),
            ),
            SizedBox(height: AppDesign.spacingL),
            Text(
              'No Leadership Roles',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            SizedBox(height: AppDesign.spacingS),
            Text(
              'Add leadership roles to help members know who to contact',
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
                _showAddRoleDialog();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Role'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadershipList() {
    return ListView.builder(
      padding: AppDesign.paddingMedium,
      itemCount: _leadershipRoles.length,
      itemBuilder: (context, index) {
        final role = _leadershipRoles[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppDesign.spacingM),
          child: AppCard(
            onTap: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              _showEditRoleDialog(role);
            },
            child: Row(
              children: [
                Container(
                  padding: AppDesign.paddingMedium,
                  decoration: BoxDecoration(
                    color: role.isActive
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: AppDesign.borderMedium,
                  ),
                  child: Icon(
                    Icons.supervisor_account,
                    color: role.isActive
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
                              role.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: role.isActive
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                            ),
                          ),
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
                              'Order ${role.displayOrder}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          if (!role.isActive) ...[
                            SizedBox(width: AppDesign.spacingS),
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
                        ],
                      ),
                      SizedBox(height: AppDesign.spacingXS),
                      Text(
                        role.holderName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      if (role.email != null || role.phone != null) ...[
                        SizedBox(height: AppDesign.spacingXS),
                        Row(
                          children: [
                            if (role.email != null) ...[
                              Icon(
                                Icons.email,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              SizedBox(width: 4),
                              Text(
                                role.email!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                            if (role.email != null && role.phone != null) ...[
                              SizedBox(width: AppDesign.spacingS),
                              Text('•',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                              SizedBox(width: AppDesign.spacingS),
                            ],
                            if (role.phone != null) ...[
                              Icon(
                                Icons.phone,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              SizedBox(width: 4),
                              Text(
                                role.phone!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ],
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
        );
      },
    );
  }
}
