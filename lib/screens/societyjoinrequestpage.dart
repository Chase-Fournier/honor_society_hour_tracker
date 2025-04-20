import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../common/app_design.dart';
import '../models/hourrequirement.dart';
import '../models/honorsociety.dart';

final supabase = Supabase.instance.client;


class SocietyJoinRequestPage extends StatefulWidget {
  const SocietyJoinRequestPage({super.key});

  @override
  _SocietyJoinRequestPageState createState() => _SocietyJoinRequestPageState();
}

class _SocietyJoinRequestPageState extends State<SocietyJoinRequestPage> {
  List<HonorSociety> _availableSocieties = [];
  Map<int, String> _requestStatuses =
      {}; // Track status: 'pending', 'approved', 'rejected'
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
            hour_requirements(
              id,
              type,
              description,
              hours_needed,
              is_active
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
          SnackBar(content: Text('Error loading societies: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Fetch all request statuses (pending, approved, rejected)
  Future<void> _fetchAllRequestStatuses() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get all requests for the current user with their status
      final requestsResponse = await supabase
          .from('society_join_requests')
          .select('society_id, status')
          .eq('user_id', userId);

      // Create a map of society_id -> status for quick lookup
      final Map<int, String> statusMap = {};
      for (final req in requestsResponse) {
        statusMap[req['society_id']] = req['status'];
      }

      setState(() {
        _requestStatuses = statusMap;
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

      if (existingRequest != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have a request for this society'),
              backgroundColor: Colors.orange,
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
      });

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Request Sent'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                    'Your request to join ${society.name} has been sent successfully.'),
                const SizedBox(height: 8),
                const Text(
                  'An administrator will review your request soon.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending request: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Allow resubmitting after a rejection
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
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request resubmitted for ${society.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resubmitting request: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join an Honor Society'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availableSocieties.isEmpty
              ? const Center(
                  child: Text('No available societies to join'),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      _fetchAvailableSocieties(),
                      _fetchAllRequestStatuses(),
                    ]);
                  },
                  child: ListView.builder(
                    itemCount: _availableSocieties.length,
                    itemBuilder: (context, index) {
                      final society = _availableSocieties[index];
                      final status = _requestStatuses[society.id];
                      final hasPendingRequest = status == 'pending';
                      final hasRejectedRequest = status == 'rejected';

                      return Card(
                        margin: AppDesign.paddingSmall,
                        child: ListTile(
                          leading: society.imageUrl != null
                              ? CircleAvatar(
                                  backgroundImage:
                                      NetworkImage(society.imageUrl!),
                                )
                              : CircleAvatar(
                                  child: Text(society.name[0]),
                                ),
                          title: Text(society.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(society.description),
                              if (hasRejectedRequest)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Your previous request was rejected',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: hasPendingRequest
                              ? Chip(
                                  label: const Text('Request Pending'),
                                  backgroundColor: Colors.amber[100],
                                  labelStyle: TextStyle(
                                    color: Colors.amber[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                  avatar: Icon(
                                    Icons.hourglass_top,
                                    color: Colors.amber[800],
                                    size: 18,
                                  ),
                                )
                              : hasRejectedRequest
                                  ? ElevatedButton(
                                      onPressed: () =>
                                          _resubmitRequest(society),
                                      child: const Text('Resubmit Request'),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _requestJoin(society),
                                      child: const Text('Request Join'),
                                    ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
