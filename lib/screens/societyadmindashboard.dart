import 'dart:convert';

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
import '../providers/hapticsprovider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_html/flutter_html.dart';
import '../common/app_design.dart';

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
  late QuillController _quillController;
  List<ActivitySummary> _recentActivity = [];
  final formatter = NumberFormat('#,###.#');

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
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

  @override
    void dispose() {
      _quillController.dispose();
      super.dispose();
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
      debugPrint('Error loading dashboard data: $e');
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
      debugPrint('Error fetching society stats: $e');
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
      debugPrint('Error fetching activity: $e');
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
          elevation: 0,
          backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
          title: Text(
            'Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24.0,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.note_add),
              tooltip: 'Add Note',
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                _showAddNotesDialog();
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                _fetchDashboardData();
              },
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
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          _showAddNotesDialog();
                        },
                        tooltip: 'Add Note',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildEnhancedMeetingNotes(),
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
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          _navigateToActivityLog();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildEnhancedRecentActivity(),
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
          ],
        ),
        const SizedBox(height: 12),
        _buildEnhancedRecentActivity(),

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
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                _showAddNotesDialog();
              },
              tooltip: 'Add Note',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEnhancedMeetingNotes(),
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
                      color: Theme.of(context).colorScheme.error,
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
                  society.name.isNotEmpty
                      ? society.name.substring(0, 1)
                      : '?',
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
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SocietyAdminPage()),
                ).then((_) => _fetchDashboardData());
              },
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
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: AppDesign.borderLarge,
              side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.note_add,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      'No meeting notes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        final hapticsProvider = Provider.of<HapticsProvider>(
                            context,
                            listen: false);
                        hapticsProvider.selection();
                        _showAddNotesDialog();
                      },
                      child: const Text('Add New Note'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppDesign.borderLarge,
            side: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context)
              .colorScheme
              .secondaryContainer
              .withValues(alpha: 0.4),
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
                      onPressed: () {
                        final hapticsProvider = Provider.of<HapticsProvider>(
                            context,
                            listen: false);
                        hapticsProvider.selection();
                        _showEditNotesDialog(note);
                      },
                    ),
                    Text(
                      _getTimeAgo(note.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                onTap: () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();
                  _showNoteDetailsDialog(note);
                },
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
      debugPrint('Error fetching meeting notes: $e');
      return [];
    }
  }

// Save a new note
  Future<void> _saveNote(String title, String text, String content) async {
  try {
    final societyId = Provider.of<SocietyProvider>(context, listen: false)
        .currentSociety?.id;
    if (societyId == null) return;

    await supabase.from('Notes').insert({
      'title': title,
      'text': text,
      'content': content,
      'society_id': societyId,
      'created_at': DateTime.now().toIso8601String(),
    });

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note added successfully')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error adding note: $e')),
    );
  }
  _quillController?.dispose();
}

Future<void> _updateNote(int noteId, String title, String text, String content) async {
  try {
    await supabase.from('Notes').update({
      'title': title,
      'text': text,
      'content': content,
    }).eq('id', noteId);

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note updated successfully')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error updating note: $e')),
    );
  }
  _quillController?.dispose();
}

// Add note dialog
void _showAddNotesDialog() {
  final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
  hapticsProvider.selection();
  
  final screenWidth = MediaQuery.of(context).size.width;
  
  if (screenWidth < 600) {
    // Mobile - use bottom sheet
    _showMobileRichTextEditor(
      onSave: (title, content, plainText) async {
        await _saveNote(title, plainText, content);
        Navigator.pop(context);
      },
    );
  } else {
    // Desktop/tablet - use dialog with collapsible toolbar
    _showDesktopAddDialog();
  }
}

void _showMobileRichTextEditor({
  String? initialContent,
  String? initialTitle,
  MeetingNote? noteToEdit, // Add this parameter
  required Function(String title, String content, String plainText) onSave,
  VoidCallback? onDelete, // Add this parameter
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MobileRichTextEditor(
      initialContent: initialContent,
      initialTitle: initialTitle,
      noteToEdit: noteToEdit, // Pass the note
      onSave: onSave,
      onDelete: onDelete, // Pass the delete callback
    ),
  );
}

void _showDesktopAddDialog() {
  String title = '';
  _quillController = QuillController.basic();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Add Meeting Note'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
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
                _CollapsibleQuillEditor(controller: _quillController!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _quillController?.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (title.isNotEmpty && !_quillController!.document.isEmpty()) {
                final deltaJson = jsonEncode(_quillController!.document.toDelta().toJson());
                final plainText = _quillController!.document.toPlainText();
                await _saveNote(title, plainText, deltaJson);
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
  final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
  hapticsProvider.selection();
  
  final screenWidth = MediaQuery.of(context).size.width;
  
  if (screenWidth < 600) {
    // Mobile - use bottom sheet
    _showMobileRichTextEditor(
      initialContent: note.content,
      initialTitle: note.title,
      noteToEdit: note, // Pass the note
      onSave: (title, content, plainText) async {
        await _updateNote(note.id, title, plainText, content);
      },
      onDelete: () async {
        Navigator.pop(context); // Close the editor first
        await _deleteNote(note.id);
      },
    );
  } else {
    // Desktop/tablet - use dialog
    _showDesktopEditDialog(note);
  }
}

Future<void> _deleteNote(int noteId) async {
  try {
    await supabase.from('Notes').delete().eq('id', noteId);
    _quillController.dispose;
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note deleted successfully')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting note: $e')),
      );
    }
  }
}


void _showDesktopEditDialog(MeetingNote note) {
  String title = note.title;
  
  // Initialize controller with existing content
  if (note.content != null && note.content!.isNotEmpty) {
    try {
      final deltaJson = jsonDecode(note.content!);
      _quillController = QuillController(
        document: Document.fromJson(deltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      // Fallback to plain text if JSON parsing fails
      _quillController = QuillController.basic();
      _quillController!.document.insert(0, note.text);
    }
  } else {
    // Fallback for old notes without rich content
    _quillController = QuillController.basic();
    _quillController!.document.insert(0, note.text);
  }

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Edit Meeting Note')),
            IconButton(
              onPressed: () async {
                _quillController?.dispose();
                Navigator.pop(context);
                await _deleteNote(note.id);
              },
              icon: const Icon(
                Icons.delete_outline,
              ),
              tooltip: 'Delete note',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
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
                _CollapsibleQuillEditor(controller: _quillController!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _quillController?.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (title.isNotEmpty && !_quillController!.document.isEmpty()) {
                final deltaJson = jsonEncode(_quillController!.document.toDelta().toJson());
                final plainText = _quillController!.document.toPlainText();
                await _updateNote(note.id, title, plainText, deltaJson);
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
  QuillController displayController;
  
  // Load rich content if available
  if (note.content != null && note.content!.isNotEmpty) {
    try {
      final deltaJson = jsonDecode(note.content!);
      displayController = QuillController(
        document: Document.fromJson(deltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      // Fallback to plain text
      displayController = QuillController.basic();
      displayController.document.insert(0, note.text);
    }
  } else {
    // Fallback for old notes
    displayController = QuillController.basic();
    displayController.document.insert(0, note.text);
  }

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(note.title)),
            PopupMenuButton<String>(
              onSelected: (value) async {
                displayController.dispose();
                Navigator.pop(context);
                
                if (value == 'edit') {
                  _showEditNotesDialog(note);
                } else if (value == 'delete') {
                  await _deleteNote(note.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: QuillEditor.basic(
              controller: displayController,
              config: QuillEditorConfig(
                
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              displayController.dispose();
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              displayController.dispose();
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


  Widget _buildEnhancedRecentActivity() {
  if (_recentActivity.isEmpty) {
    return _buildEmptyActivityState();
  }

  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppDesign.borderLarge,
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        width: 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        // Activity items with enhanced design
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: min(5, _recentActivity.length),
          separatorBuilder: (context, index) => const SizedBox(),
          itemBuilder: (context, index) {
            final activity = _recentActivity[index];
            return _buildActivityItem(activity, index);
          },
        ),
        
        // View all button
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _navigateToActivityLog,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View All Activity',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildActivityItem(ActivitySummary activity, int index) {
  IconData icon;
  Color color;
  String action;
  
  // Activity type mapping (same as before)
  switch (activity.actionType) {
    case 'signup':
      icon = Icons.person_add;
      color = Colors.green;
      action = 'signed up for';
      break;
    case 'unsignup':
      icon = Icons.person_remove;
      color = Colors.red;
      action = 'cancelled';
      break;
    case 'attendance_marked':
      icon = Icons.check_circle;
      color = Colors.green;
      action = 'attended';
      break;
    default:
      icon = Icons.info;
      color = Colors.grey;
      action = 'modified';
  }

  return AnimatedContainer(
    duration: Duration(milliseconds: 300 + (index * 100)),
    curve: Curves.easeOutCubic,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Show activity details
          _showActivityDetails(activity);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: activity.userName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' $action '),
                          TextSpan(
                            text: activity.eventName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeAgo(activity.dateTime),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (activity.hours > 0) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${activity.hours} hrs',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Arrow indicator
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Enhanced Meeting Notes Widget
Widget _buildEnhancedMeetingNotes() {
  return FutureBuilder<List<MeetingNote>>(
    future: _fetchMeetingNotes(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildNotesLoadingState();
      }

      final notes = snapshot.data ?? [];
      
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderLarge,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Notes content
            if (notes.isEmpty)
              _buildEmptyNotesState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: notes.length,
                separatorBuilder: (context, index) => const SizedBox(),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return _buildNoteItem(note);
                },
              ),
          ],
        ),
      );
    },
  );
}

Widget _buildNoteItem(MeetingNote note) {
  final isRecent = note.createdAt.isAfter(
    DateTime.now().subtract(const Duration(days: 7)),
  );

  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => _showNoteDetailsDialog(note),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date indicator
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isRecent 
                  ? Theme.of(context).colorScheme.tertiaryContainer
                  : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM').format(note.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isRecent
                        ? Theme.of(context).colorScheme.onTertiaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    DateFormat('dd').format(note.createdAt),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isRecent
                        ? Theme.of(context).colorScheme.onTertiaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Note content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isRecent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onTertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    note.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditNotesDialog(note),
                  visualDensity: VisualDensity.compact,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// Loading states
Widget _buildNotesLoadingState() {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: AppDesign.borderLarge),
    child: Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceVariant,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: List.generate(3, (index) => Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          )),
        ),
      ),
    ),
  );
}

// Empty states with illustrations
Widget _buildEmptyActivityState() {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: AppDesign.borderLarge),
    child: Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.timeline,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Recent Activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Member activities will appear here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildEmptyNotesState() {
  return Container(
    padding: const EdgeInsets.all(48),
    child: Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.note_add,
            size: 40,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No Meeting Notes',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Start documenting your meetings',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _showAddNotesDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add First Note'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    ),
  );
}

// Additional helper methods
void _showActivityDetails(ActivitySummary activity) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Activity details
          Text(
            'Activity Details',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Add more detailed information here
          _buildDetailRow('Member', activity.userName),
          _buildDetailRow('Action', activity.actionType),
          _buildDetailRow('Event', activity.eventName),
          _buildDetailRow('Time', DateFormat.yMMMd().add_jm().format(activity.dateTime)),
          if (activity.hours > 0)
            _buildDetailRow('Hours', '${activity.hours} hours'),
        ],
      ),
    ),
  );
}

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    ),
  );
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


class _MobileRichTextEditor extends StatefulWidget {
  final String? initialContent;
  final String? initialTitle;
  final Function(String title, String content, String plainText) onSave;
  final VoidCallback? onDelete;
  final MeetingNote? noteToEdit;

  const _MobileRichTextEditor({
    this.initialContent,
    this.initialTitle,
    required this.onSave,
    this.noteToEdit,
    this.onDelete,
  });

  @override
  State<_MobileRichTextEditor> createState() => _MobileRichTextEditorState();
}

class _MobileRichTextEditorState extends State<_MobileRichTextEditor> {
  late QuillController _controller;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      try {
        final deltaJson = jsonDecode(widget.initialContent!);
        _controller = QuillController(
          document: Document.fromJson(deltaJson),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        _controller = QuillController.basic();
      }
    } else {
      _controller = QuillController.basic();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initialTitle != null ? 'Edit Note' : 'New Note',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.noteToEdit != null && widget.onDelete != null)
                    IconButton(
                      onPressed: widget.onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                      ),
                      tooltip: 'Delete note',
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final title = _titleController.text;
                      if (title.isNotEmpty && !_controller.document.isEmpty()) {
                        final deltaJson = jsonEncode(_controller.document.toDelta().toJson());
                        final plainText = _controller.document.toPlainText();
                        widget.onSave(title, deltaJson, plainText);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            
            // Title field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Compact toolbar
            QuillSimpleToolbar(
              controller: _controller,
              config: QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                toolbarSize: 40,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showListNumbers: true,
                showListBullets: true,
                showFontFamily: false,
                showFontSize: false,
                showAlignmentButtons: false,
                showHeaderStyle: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showClearFormat: false,
                showStrikeThrough: false,
                showInlineCode: false,
                showCodeBlock: false,
                showIndent: false,
                showLink: false,
                showUndo: false,
                showRedo: false,
                showDirection: false,
                showSearchButton: false,
              ),
            ),
            
            const Divider(height: 1),
            
            // Editor
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: QuillEditor.basic(
                  controller: _controller,
                  config: QuillEditorConfig(
                    
                    placeholder: 'Start writing your note...',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleQuillEditor extends StatefulWidget {
  final QuillController controller;
  
  const _CollapsibleQuillEditor({required this.controller});

  @override
  State<_CollapsibleQuillEditor> createState() => _CollapsibleQuillEditorState();
}

class _CollapsibleQuillEditorState extends State<_CollapsibleQuillEditor> {
  bool _showToolbar = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Toolbar toggle button
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_showToolbar ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                  onPressed: () {
                    setState(() {
                      _showToolbar = !_showToolbar;
                    });
                  },
                  tooltip: _showToolbar ? 'Hide formatting' : 'Show formatting',
                ),
                Expanded(
                  child: Text(
                    _showToolbar ? 'Hide formatting tools' : 'Tap to show formatting tools',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          
          // Collapsible toolbar
          if (_showToolbar)
            QuillSimpleToolbar(
              controller: widget.controller,
              config: QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                toolbarSize: 35,
                showFontFamily: false,
                showFontSize: false,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showListNumbers: true,
                showListBullets: true,
                showAlignmentButtons: false,
                showHeaderStyle: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showClearFormat: false,
                showStrikeThrough: false,
                showInlineCode: false,
                showCodeBlock: false,
                showIndent: false,
                showLink: false,
                showUndo: false,
                showRedo: false,
                showDirection: false,
                showSearchButton: false,
              ),
            ),
          
          // Editor
          Expanded(
            child: QuillEditor.basic(
              controller: widget.controller,
              config: QuillEditorConfig(
                placeholder: _showToolbar ? 'Start typing...' : 'Tap above for formatting options...',
              ),
            ),
          ),
        ],
      ),
    );
  }
}