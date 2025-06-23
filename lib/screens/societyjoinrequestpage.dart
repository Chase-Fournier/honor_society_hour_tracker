import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../common/app_design.dart';
import '../common/app_widgets.dart';
import '../models/hourrequirement.dart';
import '../models/honorsociety.dart';
import '../common/iconutils.dart';
import '../common/iconselector.dart';
import 'package:provider/provider.dart';
import '../providers/hapticsprovider.dart';

final supabase = Supabase.instance.client;

class SocietyJoinRequestPage extends StatefulWidget {
  const SocietyJoinRequestPage({super.key});

  @override
  _SocietyJoinRequestPageState createState() => _SocietyJoinRequestPageState();
}

class _SocietyJoinRequestPageState extends State<SocietyJoinRequestPage> {
  List<HonorSociety> _availableSocieties = [];
  Map<int, String> _requestStatuses =
      {}; // Track status: 'pending', 'approved', 'rejected', 'revoked'
  Map<int, DateTime> _requestDates = {}; // Track when requests were made
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAvailableSocieties();
    _fetchAllRequestStatuses();
  }

  Future<void> _fetchAvailableSocieties() async {
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get societies user is already a member of
      final memberships = await supabase
          .from('user_society_memberships')
          .select('society_id')
          .eq('user_id', userId);

      final memberSocietyIds = memberships.map((m) => m['society_id']).toList();

      // Fetch all societies (not just ones they're not a member of)
      // We'll filter the display based on membership and request status
      final societies = await supabase.from('honor_societies').select('''
            id,
            name,
            description,
            image_url,
            meeting_requirement,
            created_at,
            error_form_url,
            hour_requirements(
              id,
              type,
              description,
              hours_needed,
              is_active,
              icon_name
            )
          ''');

      setState(() {
        _availableSocieties = societies.map<HonorSociety>((societyData) {
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
            errorFormUrl: societyData['error_form_url'],
          );
        }).toList();

        // Filter out societies the user is already a member of
        _availableSocieties = _availableSocieties
            .where((society) => !memberSocietyIds.contains(society.id))
            .toList();
      });
    } catch (e) {
      print('Error loading societies: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading societies: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Fetch all request statuses (pending, approved, rejected, revoked)
  Future<void> _fetchAllRequestStatuses() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get all requests for the current user with their status and dates
      final requestsResponse = await supabase
          .from('society_join_requests')
          .select('society_id, status, requested_at')
          .eq('user_id', userId);

      // Create maps for quick lookup
      final Map<int, String> statusMap = {};
      final Map<int, DateTime> dateMap = {};

      for (final req in requestsResponse) {
        statusMap[req['society_id']] = req['status'];
        dateMap[req['society_id']] = DateTime.parse(req['requested_at']);
      }

      setState(() {
        _requestStatuses = statusMap;
        _requestDates = dateMap;
      });
    } catch (e) {
      print('Error fetching request statuses: $e');
    }
  }

  Future<void> _requestJoin(HonorSociety society) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // First check if a request already exists
      final existingRequest = await supabase
          .from('society_join_requests')
          .select()
          .eq('user_id', userId)
          .eq('society_id', society.id)
          .maybeSingle();

      if (existingRequest != null && existingRequest['status'] == 'pending') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'You already have a pending request for this society'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // Create the join request
      await supabase.from('society_join_requests').insert({
        'user_id': userId,
        'society_id': society.id,
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
      });

      // Update local state
      setState(() {
        _requestStatuses[society.id] = 'pending';
        _requestDates[society.id] = DateTime.now();
      });

      if (mounted) {
        // Show success dialog
        _showSuccessDialog(society);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending request: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Allow resubmitting after a rejection or revocation
  Future<void> _resubmitRequest(HonorSociety society) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      // Update the existing request
      await supabase
          .from('society_join_requests')
          .update({
            'status': 'pending',
            'requested_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('society_id', society.id);

      // Update local state
      setState(() {
        _requestStatuses[society.id] = 'pending';
        _requestDates[society.id] = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request resubmitted for ${society.name}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resubmitting request: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(HonorSociety society) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderLarge,
        ),
        icon: Icon(
          Icons.check_circle_outline,
          color: Colors.green,
          size: 48,
        ),
        title: const Text('Request Sent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your request to join ${society.name} has been sent successfully.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDesign.spacingS),
            Container(
              padding: AppDesign.paddingSmall,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.5),
                borderRadius: AppDesign.borderMedium,
              ),
              child: Text(
                'An administrator will review your request soon.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSocietyDetails(HonorSociety society) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderLarge,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            children: [
              // Header
              Container(
                padding: AppDesign.paddingMedium,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppDesign.radiusLarge),
                    topRight: Radius.circular(AppDesign.radiusLarge),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: society.imageUrl != null
                          ? NetworkImage(society.imageUrl!)
                          : null,
                      child: society.imageUrl == null
                          ? Text(society.name.substring(0, 1))
                          : null,
                    ),
                    const SizedBox(width: AppDesign.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            society.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Honor Society',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          Navigator.pop(context);
                        }),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: AppDesign.paddingMedium,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      const AppSectionHeader(
                        title: 'About',
                        icon: Icons.info_outline,
                      ),
                      const SizedBox(height: AppDesign.spacingS),
                      Text(
                        society.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),

                      const SizedBox(height: AppDesign.spacingL),

                      // Requirements
                      const AppSectionHeader(
                        title: 'Requirements',
                        icon: Icons.assignment,
                      ),
                      const SizedBox(height: AppDesign.spacingS),

                      // Meeting requirement
                      _buildRequirementItem(
                        'Meeting Attendance',
                        '${society.meetingRequirement} meetings required',
                        Icons.groups,
                      ),

                      // Hour requirements
                      ...society.hourRequirements
                          .where((req) => req.isActive)
                          .map(
                            (req) => _buildRequirementItem(
                              req.type,
                              '${req.hoursNeeded} hours - ${req.description}',
                              getIconDataByName(req.iconName),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementItem(
      String title, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDesign.spacingS),
      padding: AppDesign.paddingSmall,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: AppDesign.borderMedium,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: AppDesign.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Join Honor Society',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Browse and request membership',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              await Future.wait([
                _fetchAvailableSocieties(),
                _fetchAllRequestStatuses(),
              ]);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availableSocieties.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      _fetchAvailableSocieties(),
                      _fetchAllRequestStatuses(),
                    ]);
                  },
                  child: isWideScreen ? _buildGridView() : _buildListView(),
                ),
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
                Icons.school_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.6),
              ),
            ),
            const SizedBox(height: AppDesign.spacingL),
            Text(
              'No Available Societies',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppDesign.spacingS),
            Text(
              'You are already a member of all available honor societies, or there are no societies to join at this time.',
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

  Widget _buildGridView() {
    return GridView.builder(
      padding: AppDesign.paddingMedium,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 1.2,
        crossAxisSpacing: AppDesign.spacingM,
        mainAxisSpacing: AppDesign.spacingM,
      ),
      itemCount: _availableSocieties.length,
      itemBuilder: (context, index) {
        final society = _availableSocieties[index];
        return _buildSocietyCard(society);
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: AppDesign.paddingMedium,
      itemCount: _availableSocieties.length,
      itemBuilder: (context, index) {
        final society = _availableSocieties[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppDesign.spacingM),
          child: _buildSocietyCard(society),
        );
      },
    );
  }

  Widget _buildSocietyCard(HonorSociety society) {
    final status = _requestStatuses[society.id];
    final requestDate = _requestDates[society.id];

    final hasPendingRequest = status == 'pending';
    final hasRejectedRequest = status == 'rejected';
    final hasRevokedRequest = status == 'revoked';
    final canResubmit = hasRejectedRequest || hasRevokedRequest;

    Color? statusColor;
    IconData? statusIcon;
    String? statusText;
    String? statusSubtext;

    if (status != null) {
      switch (status) {
        case 'pending':
          statusColor = Colors.amber.shade800;
          statusIcon = Icons.hourglass_top;
          statusText = 'PENDING';
          statusSubtext = 'Request submitted ${_formatDate(requestDate)}';
          break;
        case 'rejected':
          statusColor = Colors.red.shade400;
          statusIcon = Icons.cancel;
          statusText = 'REJECTED';
          statusSubtext = 'You can resubmit your request';
          break;
        case 'revoked':
          statusColor = Colors.orange.shade400;
          statusIcon = Icons.remove_circle;
          statusText = 'MEMBERSHIP REVOKED';
          statusSubtext = 'You can request to rejoin';
          break;
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with society info
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: society.imageUrl != null
                    ? NetworkImage(society.imageUrl!)
                    : null,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: society.imageUrl == null
                    ? Text(
                        society.name.substring(0, 1),
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppDesign.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      society.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      society.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();
                  _showSocietyDetails(society);
                },
                tooltip: 'View Details',
              ),
            ],
          ),

          // Status indicator
          if (status != null) ...[
            const SizedBox(height: AppDesign.spacingM),
            Container(
              padding: AppDesign.paddingSmall,
              decoration: BoxDecoration(
                color: statusColor!.withOpacity(0.1),
                borderRadius: AppDesign.borderMedium,
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    statusIcon!,
                    size: 20,
                    color: statusColor,
                  ),
                  const SizedBox(width: AppDesign.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        if (statusSubtext != null)
                          Text(
                            statusSubtext,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor.withOpacity(0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action button
          const SizedBox(height: AppDesign.spacingM),
          SizedBox(
            width: double.infinity,
            child: hasPendingRequest
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.hourglass_top, color: Colors.grey[600]),
                    label: Text(
                      'Request Pending',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : canResubmit
                    ? FilledButton.icon(
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          _resubmitRequest(society);
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(hasRevokedRequest
                            ? 'Request to Rejoin'
                            : 'Resubmit Request'),
                      )
                    : FilledButton.icon(
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          _requestJoin(society);
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Request to Join'),
                      ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return 'on ${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return 'today';
    }
  }
}
