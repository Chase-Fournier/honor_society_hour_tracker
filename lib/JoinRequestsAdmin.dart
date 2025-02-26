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

class _JoinRequestsAdminPageState extends State<JoinRequestsAdminPage> with SingleTickerProviderStateMixin {
  List<JoinRequest> _pendingRequests = [];
  List<JoinRequest> _processedRequests = [];
  bool _isLoading = true;
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy · h:mm a');

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
      final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      
      if (society == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Fetch pending requests
      final pendingResponse = await supabase
          .from('society_join_requests')
          .select('''
            id,
            status,
            requested_at,
            processed_at,
            processed_by,
            profiles!society_join_requests_user_id_fkey(user_id, name, email),
            profiles!society_join_requests_processed_by_fkey(name)
          ''')
          .eq('society_id', society.id)
          .eq('status', 'pending')
          .order('requested_at', ascending: false);
      
      // Fetch processed requests
      final processedResponse = await supabase
          .from('society_join_requests')
          .select('''
            id,
            status,
            requested_at,
            processed_at,
            processed_by,
            profiles!society_join_requests_user_id_fkey(user_id, name, email),
            profiles!society_join_requests_processed_by_fkey(name)
          ''')
          .eq('society_id', society.id)
          .neq('status', 'pending')
          .order('processed_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _pendingRequests = pendingResponse.map<JoinRequest>((req) => JoinRequest.fromJson(req)).toList();
          _processedRequests = processedResponse.map<JoinRequest>((req) => JoinRequest.fromJson(req)).toList();
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
      // Call the function to process the join request
      final response = await supabase
          .rpc('process_join_request', params: {
            'request_id_param': request.id,
            'approve': approve,
          });
      
      if (response == true) {
        // Refresh the requests
        await _fetchJoinRequests();
        
        // If approved, refresh the society provider to reflect new members
        if (approve) {
          await Provider.of<SocietyProvider>(context, listen: false).loadUserSocieties();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request ${approve ? 'approved' : 'rejected'} successfully'),
            backgroundColor: approve ? Colors.green : Colors.red,
          ),
        );
      } else {
        throw Exception('Failed to process request');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing request: $e')),
      );
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
              tabs: const [
                Tab(text: 'Pending'),
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
                  Text(
                    'Requested: ${_dateFormat.format(request.requestedAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (!isPending) ...[
                    Text(
                      'Status: ${request.status.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: request.status == 'approved' ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      'Processed: ${_dateFormat.format(request.processedAt!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (request.processedByName != null)
                      Text(
                        'By: ${request.processedByName}',
                        style: const TextStyle(fontSize: 12),
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
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processedBy;
  final String userId;
  final String userName;
  final String userEmail;
  final String? processedByName;

  JoinRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.processedByName,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    final userProfile = json['profiles!society_join_requests_user_id_fkey'];
    final processorProfile = json['profiles!society_join_requests_processed_by_fkey'];
    
    return JoinRequest(
      id: json['id'],
      status: json['status'],
      requestedAt: DateTime.parse(json['requested_at']),
      processedAt: json['processed_at'] != null 
          ? DateTime.parse(json['processed_at']) 
          : null,
      processedBy: json['processed_by'],
      userId: userProfile['user_id'],
      userName: userProfile['name'],
      userEmail: userProfile['email'],
      processedByName: processorProfile?['name'],
    );
  }
}