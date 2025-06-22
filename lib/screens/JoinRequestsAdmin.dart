import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/societyprovider.dart';
import '../main.dart';
import '../common/app_design.dart';
import '../common/app_widgets.dart';

/// Page to manage join requests for a society's admin
class JoinRequestsAdminPage extends StatefulWidget {
  const JoinRequestsAdminPage({Key? key}) : super(key: key);

  @override
  _JoinRequestsAdminPageState createState() => _JoinRequestsAdminPageState();
}

class _JoinRequestsAdminPageState extends State<JoinRequestsAdminPage>
    with SingleTickerProviderStateMixin {
  List<JoinRequest> _pendingRequests = [];
  List<JoinRequest> _processedRequests = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchJoinRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchJoinRequests() async {
    setState(() => _isLoading = true);

    try {
      // Get current society from provider
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;

      if (society == null) {
        setState(() {
          _pendingRequests = [];
          _processedRequests = [];
          _isLoading = false;
        });
        return;
      }

      print(1);

      // First, fetch the join requests
      final joinRequestsResponse = await supabase
          .from('society_join_requests')
          .select()
          .eq('society_id', society.id)
          .order('requested_at', ascending: false);

      // Then, separately fetch user profiles for each request's user
      final List<JoinRequest> pendingRequests = [];
      final List<JoinRequest> processedRequests = [];

      print(2);

      for (final req in joinRequestsResponse) {
        // Fetch user profile info separately
        final userProfileResponse = await supabase
            .from('profiles')
            .select('name, email')
            .eq('user_id', req['user_id'])
            .single();

        print(3);

        // Fetch processor profile if processed
        String? processorName;
        if (req['processed_by'] != null) {
          try {
            final processorResponse = await supabase
                .from('profiles')
                .select('name')
                .eq('user_id', req['processed_by'])
                .single();

            processorName = processorResponse['name'];
          } catch (e) {
            // If processor profile can't be found, just leave it null
            print('Could not find processor profile: $e');
          }
        }

        print(4);

        final joinRequest = JoinRequest(
          id: req['id'],
          status: req['status'],
          userId: req['user_id'],
          userName: userProfileResponse['name'] ?? 'Unknown User',
          userEmail: userProfileResponse['email'] ?? 'No email',
          requestedAt: DateTime.parse(req['requested_at'] ?? DateTime.now()),
          processedAt: req['processed_at'] != null 
              ? DateTime.parse(req['processed_at']) 
              : null,
          processorName: processorName,
        );

        if (joinRequest.status == 'pending') {
          pendingRequests.add(joinRequest);
        } else {
          processedRequests.add(joinRequest);
        }
      }

      print(5);

      if (mounted) {
        setState(() {
          _pendingRequests = pendingRequests;
          _processedRequests = processedRequests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching join requests: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processRequest(JoinRequest request, bool approve) async {
    setState(() => _isLoading = true);

    try {
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        throw Exception('No society selected');
      }

      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not logged in');
      }

      final now = DateTime.now().toIso8601String();

      // Begin a Supabase transaction by updating the request status
      await supabase.from('society_join_requests').update({
        'status': approve ? 'approved' : 'rejected',
        'processed_by': currentUserId,
        'processed_at': now,
      }).eq('id', request.id);

      // If approved, add the user to the society members
      if (approve) {
        await supabase.from('user_society_memberships').insert({
          'user_id': request.userId,
          'society_id': society.id,
          'is_admin': false, // New members are not admins by default
        });
      }

      // Update local state
      setState(() {
        // Remove the request from pending
        _pendingRequests.removeWhere((r) => r.id == request.id);

        // Update the request with processed info
        final processedRequest = JoinRequest(
          id: request.id,
          status: approve ? 'approved' : 'rejected',
          userId: request.userId,
          userName: request.userName,
          userEmail: request.userEmail,
          requestedAt: request.requestedAt,
          processedAt: DateTime.now(),
          processorName: 'You', // Current user processed it
        );

        // Add to processed list at the beginning
        _processedRequests.insert(0, processedRequest);
      });

      // If approved, refresh the society provider to reflect new members
      if (approve) {
        await Provider.of<SocietyProvider>(context, listen: false)
            .loadUserSocieties();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${approve ? 'approved' : 'rejected'} successfully'),
          backgroundColor: approve ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing request: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(JoinRequest request) async {
    // Show confirmation dialog first
    final confirmed = await _showRemoveConfirmation(request);
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        throw Exception('No society selected');
      }

      // Remove from society membership
      await supabase
          .from('user_society_memberships')
          .delete()
          .eq('user_id', request.userId)
          .eq('society_id', society.id);

      // Update the join request to show it was revoked
      await supabase.from('society_join_requests').update({
        'status': 'revoked',
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', request.id);

      // Update local state
      setState(() {
        final index = _processedRequests.indexWhere((r) => r.id == request.id);
        if (index != -1) {
          _processedRequests[index] = JoinRequest(
            id: request.id,
            status: 'revoked',
            userId: request.userId,
            userName: request.userName,
            userEmail: request.userEmail,
            requestedAt: request.requestedAt,
            processedAt: DateTime.now(),
            processorName: 'You',
          );
        }
      });

      // Refresh society provider
      await Provider.of<SocietyProvider>(context, listen: false)
          .loadUserSocieties();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${request.userName} has been removed from the society'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing member: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showRemoveConfirmation(JoinRequest request) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: AppDesign.borderLarge,
          ),
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 32,
          ),
          title: const Text('Remove Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to remove ${request.userName} from the honor society?',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppDesign.spacingM),
              Container(
                padding: AppDesign.paddingMedium,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: AppDesign.borderMedium,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: AppDesign.spacingXS),
                        Text(
                          'This action will:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDesign.spacingXS),
                    Text(
                      '• Remove their access to society events and activities\n'
                      '• Preserve their completed service hours for records\n'
                      '• Allow them to request to rejoin in the future',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Remove Member'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Consumer<SocietyProvider>(
      builder: (context, societyProvider, _) {
        final society = societyProvider.currentSociety;

        if (societyProvider.isLoading || society == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membership Requests',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  society.name,
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
                onPressed: _fetchJoinRequests,
                tooltip: 'Refresh',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hourglass_top),
                      const SizedBox(width: 8),
                      Text(_pendingRequests.isEmpty
                          ? 'Pending'
                          : 'Pending (${_pendingRequests.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history),
                      const SizedBox(width: 8),
                      const Text('Processed'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestList(_pendingRequests, true),
                    _buildRequestList(_processedRequests, false),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildRequestList(List<JoinRequest> requests, bool isPending) {
    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: AppDesign.paddingLarge,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: AppDesign.paddingLarge,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: AppDesign.borderRound,
                ),
                child: Icon(
                  isPending ? Icons.inbox : Icons.history,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: AppDesign.spacingL),
              Text(
                isPending ? 'No pending requests' : 'No processed requests',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDesign.spacingS),
              Text(
                isPending
                    ? 'When users request to join, they\'ll appear here'
                    : 'Approved and rejected requests will appear here',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchJoinRequests,
      child: ListView.builder(
        padding: AppDesign.paddingMedium,
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return Container(
            margin: const EdgeInsets.only(bottom: AppDesign.spacingM),
            child: _buildRequestCard(request, isPending),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(JoinRequest request, bool isPending) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (request.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'APPROVED';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'REJECTED';
        break;
      case 'revoked':
        statusColor = Colors.orange;
        statusIcon = Icons.remove_circle;
        statusText = 'REMOVED';
        break;
      default:
        statusColor = Colors.amber;
        statusIcon = Icons.hourglass_top;
        statusText = 'PENDING';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with user info
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: statusColor.withOpacity(0.2),
                child: Text(
                  request.userName.isNotEmpty ? request.userName[0] : '?',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: AppDesign.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.userName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.userEmail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPending)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesign.spacingS,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: AppDesign.borderSmall,
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Request details
          const SizedBox(height: AppDesign.spacingM),
          Container(
            padding: AppDesign.paddingSmall,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: AppDesign.borderSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Requested: ${_formatDateTime(request.requestedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                if (request.processedAt != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Processed by: ${request.processorName ?? "Unknown"} on ${_formatDateTime(request.processedAt!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Actions
          if (isPending || request.status == 'approved') ...[
            const SizedBox(height: AppDesign.spacingM),
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _processRequest(request, false),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: AppDesign.spacingS),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _processRequest(request, true),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              )
            else if (request.status == 'approved')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _removeMember(request),
                  icon: const Icon(Icons.person_remove),
                  label: const Text('Remove from Society'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

/// Enhanced model class for join requests
class JoinRequest {
  final int id;
  final String status;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processorName;

  JoinRequest({
    required this.id,
    required this.status,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.requestedAt,
    this.processedAt,
    this.processorName,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'],
      status: json['status'],
      userId: json['user_id'],
      userName: json['userName'] ?? 'Unknown User',
      userEmail: json['userEmail'] ?? 'No email',
      requestedAt: DateTime.parse(json['requested_at']),
      processedAt: json['processed_at'] != null 
          ? DateTime.parse(json['processed_at']) 
          : null,
      processorName: json['processorName'],
    );
  }
}