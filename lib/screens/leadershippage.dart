import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/societyprovider.dart';
import '../models/leadershiprole.dart';
import '../common/app_design.dart';
import '../providers/hapticsprovider.dart';

final supabase = Supabase.instance.client;

class LeadershipPage extends StatefulWidget {
  const LeadershipPage({Key? key}) : super(key: key);

  @override
  _LeadershipPageState createState() => _LeadershipPageState();
}

class _LeadershipPageState extends State<LeadershipPage> {
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
          .eq('is_active', true)
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
          SnackBar(content: Text('Error loading leadership: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _showRoleDetails(LeadershipRole role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderLarge,
        ),
        title: Row(
          children: [
            Icon(
              Icons.supervisor_account,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: AppDesign.spacingS),
            Expanded(
              child: Text(
                role.title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Role holder info
              Container(
                padding: AppDesign.paddingMedium,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.3),
                  borderRadius: AppDesign.borderMedium,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        role.holderName
                            .split(' ')
                            .where((part) => part.isNotEmpty)
                            .map((name) => name[0])
                            .take(2)
                            .join(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: AppDesign.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role.holderName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            role.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AppDesign.spacingL),

              // Contact information
              if (role.email != null || role.phone != null) ...[
                Text(
                  'Contact Information',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                SizedBox(height: AppDesign.spacingS),
                if (role.email != null)
                  _buildContactItem(
                      icon: Icons.email,
                      label: 'Email',
                      value: role.email!,
                      onTap: () {
                        final hapticsProvider = Provider.of<HapticsProvider>(
                            context,
                            listen: false);
                        hapticsProvider.selection();
                        _launchEmail(role.email!);
                      }),
                if (role.phone != null)
                  _buildContactItem(
                    icon: Icons.phone,
                    label: 'Phone',
                    value: role.phone!,
                    onTap: () {
                      final hapticsProvider =
                          Provider.of<HapticsProvider>(context, listen: false);
                      hapticsProvider.selection();
                      _launchPhone(role.phone!);
                    },
                  ),
                SizedBox(height: AppDesign.spacingL),
              ],

              // Role description
              Text(
                'Role Description',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              SizedBox(height: AppDesign.spacingS),
              Container(
                padding: AppDesign.paddingMedium,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.3),
                  borderRadius: AppDesign.borderMedium,
                ),
                child: Text(
                  role.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.spacingS),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDesign.borderSmall,
        child: Container(
          padding: AppDesign.paddingSmall,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            borderRadius: AppDesign.borderSmall,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: AppDesign.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );

    try {
      await launchUrl(emailUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open email app: $e')),
        );
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phone,
    );

    try {
      await launchUrl(phoneUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone app: $e')),
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
            title: Text('${society.name} Leadership'),
            elevation: 0,
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchLeadershipRoles,
                  child: _leadershipRoles.isEmpty
                      ? _buildEmptyState()
                      : _buildLeadershipList(),
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
              'No Leadership Information',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            SizedBox(height: AppDesign.spacingS),
            Text(
              'Leadership information will appear here once added by administrators',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadershipList() {
    final bool isWideScreen = MediaQuery.of(context).size.width > 900;

    if (isWideScreen) {
      return _buildGridLayout();
    } else {
      return _buildListLayout();
    }
  }

  // Bordered card with a soft shadow, matching the rest of the app's cards.
  Widget _appStyleCard({required Widget child, VoidCallback? onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppDesign.borderLarge,
        border: Border.all(color: scheme.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppDesign.paddingMedium,
          child: child,
        ),
      ),
    );
  }

  Widget _buildListLayout() {
    return ListView.builder(
      padding: AppDesign.paddingMedium,
      itemCount: _leadershipRoles.length,
      itemBuilder: (context, index) {
        final role = _leadershipRoles[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppDesign.spacingM),
          child: _appStyleCard(
            onTap: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              _showRoleDetails(role);
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    role.holderName
                        .split(' ')
                        .where((part) => part.isNotEmpty)
                        .map((name) => name[0])
                        .take(2)
                        .join(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(width: AppDesign.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      SizedBox(height: AppDesign.spacingXS),
                      Text(
                        role.holderName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
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
                            ],
                            Text(
                              'Contact available',
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
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridLayout() {
    return GridView.builder(
      padding: AppDesign.paddingMedium,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _leadershipRoles.length,
      itemBuilder: (context, index) {
        final role = _leadershipRoles[index];
        return _appStyleCard(
          onTap: () {
            final hapticsProvider =
                Provider.of<HapticsProvider>(context, listen: false);
            hapticsProvider.selection();
            _showRoleDetails(role);
          },
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        role.holderName
                            .split(' ')
                            .where((part) => part.isNotEmpty)
                            .map((name) => name[0])
                            .take(2)
                            .join(),
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    SizedBox(height: AppDesign.spacingM),
                    Text(
                      role.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppDesign.spacingS),
                    Text(
                      role.holderName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (role.email != null || role.phone != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesign.spacingS,
                    vertical: AppDesign.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3),
                    borderRadius: AppDesign.borderSmall,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (role.email != null) ...[
                        Icon(
                          Icons.email,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        if (role.phone != null)
                          SizedBox(width: AppDesign.spacingXS),
                      ],
                      if (role.phone != null) ...[
                        Icon(
                          Icons.phone,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                      SizedBox(width: 4),
                      Text(
                        'Contact',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
