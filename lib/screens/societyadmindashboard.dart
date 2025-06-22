import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'JoinRequestsAdmin.dart';
import 'societyadminpage.dart';
import '../providers/societyprovider.dart';
import 'package:provider/provider.dart';
import '../models/honorsociety.dart';
import '../models/meetingnote.dart';
import 'admineventspage.dart';
import 'activitylogpage.dart';
import "adminlistspage.dart";



final supabase = Supabase.instance.client;

/// Dashboard for society administrators showing statistics and quick access to management features
class SocietyAdminDashboard extends StatefulWidget {
  const SocietyAdminDashboard({Key? key}) : super(key: key);

  @override
  _SocietyAdminDashboardState createState() => _SocietyAdminDashboardState();
}

class _SocietyAdminDashboardState extends State<SocietyAdminDashboard> {
  bool _isLoading = true;
  late SocietyStats _stats;
  List<ActivitySummary> _recentActivity = [];
  final formatter = NumberFormat('#,###.#');

  @override
  void initState() {
    super.initState();

    // Initialize with default stats to prevent null errors
    _stats = SocietyStats(
      totalMembers: 0,
      qualifyingMembers: 0,
      totalEvents: 0,
      totalHours: 0,
      pendingRequests: 0,
      upcomingEvents: 0,
    );

    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // We'll execute several queries in parallel for efficiency
      final results = await Future.wait([
        _fetchSocietyStats(society.id),
        _fetchRecentActivity(society.id),
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as SocietyStats;
          _recentActivity = results[1] as List<ActivitySummary>;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard data: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<SocietyStats> _fetchSocietyStats(int societyId) async {
    try {
      // Run queries in parallel with separate, simpler queries
      final results = await Future.wait([
        // 1. Get members
        supabase
            .from('user_society_memberships')
            .select('user_id, profiles(name)')
            .eq('society_id', societyId),

        // 2. Get service hours separately
        supabase
            .from('Service hours')
            .select('user_id, hours, type')
            .eq('society_id', societyId),

        // 3. All events in a single query
        supabase.from('Events').select().eq('society_id', societyId),

        // 4. Join requests in a single query
        supabase
            .from('society_join_requests')
            .select()
            .eq('society_id', societyId)
      ]);

      // Process results
      final memberships = results[0];
      final serviceHours = results[1];
      final events = results[2];
      final joinRequests = results[3];

      // 1. Process members data
      final totalMembers = memberships.length;

      // Calculate total hours and qualifying members locally
      double totalHours = 0.0;
      int qualifyingMembers = 0;
      Map<String, Map<String, double>> userHours = {};

      // Create a map of user_id -> hours by type
      for (final member in memberships) {
        final userId = member['user_id'];
        userHours[userId] = {'Service': 0.0, 'Tutoring': 0.0, 'Meeting': 0.0};
      }

      // Process service hour records into the map
      for (final hourRecord in serviceHours) {
        final userId = hourRecord['user_id'];
        final type = hourRecord['type'] as String? ?? 'Service';
        final hours = (hourRecord['hours'] as num?)?.toDouble() ?? 0.0;

        if (userHours.containsKey(userId)) {
          if (userHours[userId]!.containsKey(type)) {
            userHours[userId]![type] =
                (userHours[userId]![type] ?? 0.0) + hours;
          } else {
            userHours[userId]![type] = hours;
          }

          // Add to total hours
          totalHours += hours;
        }
      }

      // Get the society's requirements from the provider
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      final Map<String, double> requirementMap = {};
      int meetingRequirement = 5; // Default

      if (society != null) {
        // Get hour requirements
        for (final req in society.hourRequirements) {
          if (req.isActive) {
            requirementMap[req.type] = req.hoursNeeded;
          }
        }

        // Get meeting requirement
        meetingRequirement = society.meetingRequirement;
      }

      // Determine qualifying members based on requirements
      for (final userId in userHours.keys) {
        final userRecord = userHours[userId]!;
        bool isQualifying = true;

        // Check each requirement
        for (final type in requirementMap.keys) {
          final required = requirementMap[type] ?? 0.0;
          final completed = userRecord[type] ?? 0.0;

          if (completed < required) {
            isQualifying = false;
            break;
          }
        }

        // Check meeting requirement separately
        if (isQualifying &&
            (userRecord['Meeting'] ?? 0.0) < meetingRequirement) {
          isQualifying = false;
        }

        if (isQualifying) {
          qualifyingMembers++;
        }
      }

      // 2. Process events data
      final totalEvents = events.length;

      // Filter upcoming events
      final now = DateTime.now();
      final upcomingEvents = events.where((event) {
        try {
          final eventDate = DateTime.parse(event['date']);
          return eventDate.isAfter(now);
        } catch (e) {
          return false;
        }
      }).length;

      // 3. Process join requests - filter pending ones
      final pendingRequests =
          joinRequests.where((req) => req['status'] == 'pending').length;

      return SocietyStats(
        totalMembers: totalMembers,
        qualifyingMembers: qualifyingMembers,
        totalEvents: totalEvents,
        totalHours: totalHours,
        pendingRequests: pendingRequests,
        upcomingEvents: upcomingEvents,
      );
    } catch (e) {
      print('Error fetching society stats: $e');
      // Return default stats on error
      return SocietyStats(
        totalMembers: 0,
        qualifyingMembers: 0,
        totalEvents: 0,
        totalHours: 0,
        pendingRequests: 0,
        upcomingEvents: 0,
      );
    }
  }


  Future<List<ActivitySummary>> _fetchRecentActivity(int societyId) async {
    try {
      // Get recent activity from activity_logs
      final logsResponse = await supabase
          .from('activity_logs')
          .select('''
            id, event_name, action_type, hours, created_at,
            profiles!activity_logs_user_id_fkey(name)
          ''')
          .eq('society_id', societyId)
          .order('created_at', ascending: false)
          .limit(10);

      return logsResponse.map<ActivitySummary>((log) {
        return ActivitySummary(
          id: log['id'],
          eventName: log['event_name'],
          actionType: log['action_type'],
          userName: log['profiles']['name'],
          dateTime: DateTime.parse(log['created_at']),
          hours: log['hours']?.toDouble() ?? 0,
        );
      }).toList();
    } catch (e) {
      print('Error fetching activity: $e');
      return [];
    }
  }

  void _navigateToJoinRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JoinRequestsAdminPage(),
      ),
    ).then((_) => _fetchDashboardData());
  }

  void _navigateToSocietySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SocietyAdminPage(),
      ),
    ).then((_) => _fetchDashboardData());
  }

  void _navigateToEvents() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminEventsPage(),
      ),
    );
  }

  void _navigateToMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminListPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we're on a desktop-sized screen
    final isDesktop = MediaQuery.of(context).size.width > 1000;

    return Consumer<SocietyProvider>(builder: (context, provider, _) {
      final society = provider.currentSociety;

      if (provider.isLoading || society == null) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: Text('${society.name} Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.note_add),
              tooltip: 'Add Note',
              onPressed: _showAddNotesDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchDashboardData,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: isDesktop
                      ? _buildDesktopLayout(society)
                      : _buildMobileLayout(society),
                ),
              ),
      );
    });
  }

// Desktop optimized layout
  Widget _buildDesktopLayout(HonorSociety society) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Society Info Card
        _buildSocietyInfoCard(society),
        const SizedBox(height: 24),

        // Stats in a row with Material You styling - now clickable
        SizedBox(
          height: 160,
          child: Row(
            children: [
              Expanded(
                  child: _buildClickableStatCard(
                'Members',
                _stats.totalMembers.toString(),
                Icons.people,
                _navigateToMembers,
                subtitle: '${_stats.qualifyingMembers} qualifying',
                color: Theme.of(context).colorScheme.primary,
              )),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildClickableStatCard(
                'Service Hours',
                formatter.format(_stats.totalHours),
                Icons.volunteer_activism,
                _navigateToTotalHours,
                subtitle: 'Hours completed',
                color: Theme.of(context).colorScheme.secondary,
              )),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildClickableStatCard(
                'Events',
                _stats.totalEvents.toString(),
                Icons.event,
                _navigateToEvents,
                subtitle: '${_stats.upcomingEvents} upcoming',
                color: Theme.of(context).colorScheme.tertiary,
              )),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildClickableStatCard(
                'Requests',
                _stats.pendingRequests.toString(),
                Icons.person_add,
                _navigateToJoinRequests,
                subtitle: 'Pending approval',
                color: Theme.of(context).colorScheme.error,
                showBadge: _stats.pendingRequests > 0,
              )),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Content area with notes and activity
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meeting Notes
            Expanded(
              flex: 45,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Meeting Notes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _showAddNotesDialog,
                        tooltip: 'Add Note',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMeetingNotes(),
                ],
              ),
            ),
            const SizedBox(width: 24),

            // Activity Feed
            Expanded(
              flex: 55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Activity',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.history),
                        label: const Text('View All'),
                        onPressed: () => _navigateToActivityLog(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRecentActivity(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

// Original mobile layout, enhanced with notes and clickable stats
  Widget _buildMobileLayout(HonorSociety society) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Society Info Card
        _buildSocietyInfoCard(society),
        const SizedBox(height: 24),

        // Stats Grid - with clickable cards
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildClickableStatCard(
              'Members',
              _stats.totalMembers.toString(),
              Icons.people,
              _navigateToMembers,
              subtitle: '${_stats.qualifyingMembers} qualifying',
              color: Theme.of(context).colorScheme.primary,
            ),
            _buildClickableStatCard(
              'Hours',
              formatter.format(_stats.totalHours),
              Icons.volunteer_activism,
              _navigateToTotalHours,
              subtitle: 'Hours completed',
              color: Theme.of(context).colorScheme.secondary,
            ),
            _buildClickableStatCard(
              'Events',
              _stats.totalEvents.toString(),
              Icons.event,
              _navigateToEvents,
              subtitle: '${_stats.upcomingEvents} upcoming',
              color: Theme.of(context).colorScheme.tertiary,
            ),
            _buildClickableStatCard(
              'Requests',
              _stats.pendingRequests.toString(),
              Icons.person_add,
              _navigateToJoinRequests,
              subtitle: 'Pending approval',
              color: Theme.of(context).colorScheme.error,
              showBadge: _stats.pendingRequests > 0,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Recent Activity
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('View All'),
              onPressed: () => _navigateToActivityLog(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRecentActivity(),

        // Meeting Notes
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Meeting Notes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddNotesDialog,
              tooltip: 'Add Note',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMeetingNotes(),
      ],
    );
  }

// Clickable stat card with Material You theming
  Widget _buildClickableStatCard(
      String title, String value, IconData icon, VoidCallback onTap,
      {String? subtitle, required Color color, bool showBadge = false}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withOpacity(0.2),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        value,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                      ),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              if (showBadge)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    width: 16,
                    height: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTotalHours() {
    /// Navigator.push(
    ///  context,
    ///  MaterialPageRoute(builder: (context) => const AdminTotalHoursPage()),
    ///);
  }

  void _navigateToActivityLog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ActivityLogPage()),
    );
  }

// Society info card with Material You theming
  Widget _buildSocietyInfoCard(HonorSociety society) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (society.imageUrl != null)
              CircleAvatar(
                radius: 32,
                backgroundImage: NetworkImage(society.imageUrl!),
              )
            else
              CircleAvatar(
                radius: 32,
                child: Text(
                  society.name.substring(0, 1),
                  style: const TextStyle(fontSize: 24),
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    society.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    society.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SocietyAdminPage()),
              ).then((_) => _fetchDashboardData()),
              tooltip: 'Society Settings',
            ),
          ],
        ),
      ),
    );
  }

// Meeting notes widget
  Widget _buildMeetingNotes() {
    return FutureBuilder<List<MeetingNote>>(
      future: _fetchMeetingNotes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading notes: ${snapshot.error}'));
        }

        final notes = snapshot.data ?? [];

        if (notes.isEmpty) {
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.note_add, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'No meeting notes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _showAddNotesDialog,
                      child: const Text('Add New Note'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: notes.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final note = notes[index];
              return ListTile(
                title: Text(
                  note.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  note.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditNotesDialog(note),
                    ),
                    Text(
                      _getTimeAgo(note.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                onTap: () => _showNoteDetailsDialog(note),
              );
            },
          ),
        );
      },
    );
  }

// Fetch meeting notes for the current society
  Future<List<MeetingNote>> _fetchMeetingNotes() async {
    try {
      final societyId = Provider.of<SocietyProvider>(context, listen: false)
          .currentSociety
          ?.id;
      if (societyId == null) return [];

      final response = await supabase
          .from('Notes')
          .select('*')
          .eq('society_id', societyId)
          .order('created_at', ascending: false);

      return response
          .map<MeetingNote>((json) => MeetingNote.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching meeting notes: $e');
      return [];
    }
  }

// Save a new note
  Future<void> _saveNote(String title, String text) async {
    try {
      final societyId = Provider.of<SocietyProvider>(context, listen: false)
          .currentSociety
          ?.id;
      if (societyId == null) return;

      await supabase.from('Notes').insert({
        'title': title,
        'text': text,
        'society_id': societyId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Refresh notes
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding note: $e')),
      );
    }
  }

// Add note dialog
  void _showAddNotesDialog() {
    String title = '';
    String content = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Meeting Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 10,
                  onChanged: (value) => content = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (title.isNotEmpty && content.isNotEmpty) {
                  await _saveNote(title, content);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

// Edit note dialog
  void _showEditNotesDialog(MeetingNote note) {
    String title = note.title;
    String content = note.text;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Meeting Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: title),
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  controller: TextEditingController(text: content),
                  maxLines: 10,
                  onChanged: (value) => content = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (title.isNotEmpty && content.isNotEmpty) {
                  await _updateNote(note.id, title, content);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

// Note details dialog
  void _showNoteDetailsDialog(MeetingNote note) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(note.title),
          content: SingleChildScrollView(
            child: Text(note.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditNotesDialog(note);
              },
              child: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

// Update an existing note
  Future<void> _updateNote(int noteId, String title, String text) async {
    try {
      await supabase.from('Notes').update({
        'title': title,
        'text': text,
      }).eq('id', noteId);

      // Refresh notes
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating note: $e')),
      );
    }
  }

// Desktop-specific quick actions layout
  Widget _buildDesktopQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Manage Members',
                Icons.people,
                _navigateToMembers,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                'Manage Events',
                Icons.event_note,
                _navigateToEvents,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Join Requests',
                Icons.person_add,
                _navigateToJoinRequests,
                Colors.purple,
                badge: _stats.pendingRequests > 0
                    ? _stats.pendingRequests.toString()
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                'Society Settings',
                Icons.settings,
                _navigateToSocietySettings,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Members',
          _stats.totalMembers.toString(),
          Icons.people,
          Colors.blue,
          subtitle: '${_stats.qualifyingMembers} qualifying',
        ),
        _buildStatCard(
          'Service Hours',
          formatter.format(_stats.totalHours),
          Icons.volunteer_activism,
          Colors.orange,
          subtitle: 'Hours completed',
        ),
        _buildStatCard(
          'Events',
          _stats.totalEvents.toString(),
          Icons.event,
          Colors.green,
          subtitle: '${_stats.upcomingEvents} upcoming',
        ),
        _buildStatCard(
          'Requests',
          _stats.pendingRequests.toString(),
          Icons.person_add,
          Colors.purple,
          subtitle: 'Pending approval',
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {String? subtitle}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, VoidCallback onPressed, Color color,
      {String? badge}) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      child: Stack(
        children: [
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Center(
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_recentActivity.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.history, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'No recent activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: min(5, _recentActivity.length),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final activity = _recentActivity[index];

          IconData icon;
          Color color;
          String action;

          switch (activity.actionType) {
            case 'signup':
              icon = Icons.person_add;
              color = Colors.green;
              action = 'signed up for';
              break;
            case 'unsignup':
              icon = Icons.person_remove;
              color = Colors.red;
              action = 'removed from';
              break;
            case 'attendance_marked':
              icon = Icons.check_box;
              color = Colors.green;
              action = 'marked attended for';
              break;
            case 'attendance_removed':
              icon = Icons.check_box_outline_blank;
              color = Colors.red;
              action = 'attendance removed for';
              break;
            case 'manual_addition':
              icon = Icons.add_box;
              color = Colors.purple;
              action = 'manually added to';
              break;
            default:
              icon = Icons.info;
              color = Colors.grey;
              action = 'modified';
          }

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color, size: 20),
            ),
            title: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface),
                children: [
                  TextSpan(
                    text: activity.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' $action '),
                  TextSpan(
                    text: activity.eventName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            subtitle: Text(
              '${_getTimeAgo(activity.dateTime)} • ${activity.hours > 0 ? '${activity.hours} hrs' : 'No hours'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        },
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class SocietyStats {
  final int totalMembers;
  final int qualifyingMembers;
  final int totalEvents;
  final double totalHours;
  final int pendingRequests;
  final int upcomingEvents;

  SocietyStats({
    required this.totalMembers,
    required this.qualifyingMembers,
    required this.totalEvents,
    required this.totalHours,
    required this.pendingRequests,
    required this.upcomingEvents,
  });
}

class ActivitySummary {
  final int id;
  final String eventName;
  final String actionType;
  final String userName;
  final DateTime dateTime;
  final double hours;

  ActivitySummary({
    required this.id,
    required this.eventName,
    required this.actionType,
    required this.userName,
    required this.dateTime,
    required this.hours,
  });
}
