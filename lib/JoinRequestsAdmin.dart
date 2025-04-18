import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'societyprovider.dart';
import 'main.dart';

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

      // First, fetch the join requests
      final joinRequestsResponse = await supabase
          .from('society_join_requests')
          .select()
          .eq('society_id', society.id)
          .order('requested_at', ascending: false);

      // Then, separately fetch user profiles for each request's user
      final List<JoinRequest> pendingRequests = [];
      final List<JoinRequest> processedRequests = [];

      for (final req in joinRequestsResponse) {
        // Fetch user profile info separately
        final userProfileResponse = await supabase
            .from('profiles')
            .select('name, email')
            .eq('user_id', req['user_id'])
            .single();

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

        final joinRequest = JoinRequest(
          id: req['id'],
          status: req['status'],
          userId: req['user_id'],
          userName: userProfileResponse['name'] ?? 'Unknown User',
          userEmail: userProfileResponse['email'] ?? 'No email',
        );

        if (joinRequest.status == 'pending') {
          pendingRequests.add(joinRequest);
        } else {
          processedRequests.add(joinRequest);
        }
      }

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
          SnackBar(content: Text('Error fetching join requests: $e')),
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
          content:
              Text('Request ${approve ? 'approved' : 'rejected'} successfully'),
          backgroundColor: approve ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing request: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            title: Text('${society.name} - Membership Requests'),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  text: _pendingRequests.isEmpty
                      ? 'Pending'
                      : 'Pending (${_pendingRequests.length})',
                ),
                Tab(text: 'Processed'),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.inbox : Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? 'No pending requests' : 'No processed requests',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              isPending
                  ? 'When users request to join, they\'ll appear here'
                  : 'Approved and rejected requests will appear here',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchJoinRequests,
      child: ListView.builder(
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(request.userName[0]),
                backgroundColor: isPending
                    ? Theme.of(context).colorScheme.primary
                    : request.status == 'approved'
                        ? Colors.green
                        : Colors.red,
              ),
              title: Text(request.userName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.userEmail),
                  const SizedBox(height: 4),
                  if (!isPending) ...[
                    Text(
                      'Status: ${request.status.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: request.status == 'approved'
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: isPending
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle),
                          color: Colors.green,
                          onPressed: () => _processRequest(request, true),
                          tooltip: 'Approve',
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel),
                          color: Colors.red,
                          onPressed: () => _processRequest(request, false),
                          tooltip: 'Reject',
                        ),
                      ],
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

}

/// Model class for join requests
class JoinRequest {
  final int id;
  final String status;
  final String userId;
  final String userName;
  final String userEmail;

  JoinRequest({
    required this.id,
    required this.status,
    required this.userId,
    required this.userName,
    required this.userEmail,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'],
      status: json['status'],
      userId: json['user_id'],
      userName: json['userName'] ?? 'Unknown User',
      userEmail: json['userEmail'] ?? 'No email',
    );
  }
}
