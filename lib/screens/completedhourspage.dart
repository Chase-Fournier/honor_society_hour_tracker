import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import '../models/completedhour.dart';
import '../models/meetingnote.dart';
import 'leaderboardpage.dart';
import '../common/iconutils.dart';
import '../common/normalizetype.dart';

final supabase = Supabase.instance.client;

class CompletedHoursPage extends StatefulWidget {
  const CompletedHoursPage({super.key});

  @override
  _CompletedHoursPageState createState() => _CompletedHoursPageState();
}

class _CompletedHoursPageState extends State<CompletedHoursPage> {
  Map<String, double> _completedHoursMap = {};
  Map<String, List<CompletedHour>> _hoursByTypeMap = {};
  Map<String, double> _requirementMap = {};
  int _meetingRequirement = 5; // Default value

  List<MeetingNote> _meetingNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Get current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get society requirements
      _meetingRequirement = society.meetingRequirement;
      _requirementMap = {};

      for (final req in society.hourRequirements) {
        if (req.isActive) {
          _requirementMap[req.type] = req.hoursNeeded;
        }
      }

      // Run queries in parallel
      await Future.wait([
        _fetchCompletedHours(),
        _fetchMeetingNotes(),
      ]);

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMeetingNotes() async {
    try {
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) return;

      final response = await Supabase.instance.client
          .from('Notes')
          .select('*')
          .eq('society_id', society.id)
          .order('created_at', ascending: false);

      setState(() {
        _meetingNotes =
            response.map((json) => MeetingNote.fromJson(json)).toList();
      });
    } catch (e) {
      print('Error fetching meeting notes: $e');
    }
  }

  Future<void> _fetchCompletedHours() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;

    if (userId != null && society != null) {
      // Get all service hours for this user in this society in a single query
      final response = await Supabase.instance.client
          .from('Service hours')
          .select('hours, type, event_name, date')
          .eq('user_id', userId)
          .eq('society_id', society.id);

      final data = response;
      Map<String, double> hoursMap = {};
      Map<String, List<CompletedHour>> hoursByType = {};

      // Initialize maps with all requirement types
      for (final reqType in _requirementMap.keys) {
        hoursMap[reqType] = 0;
        hoursByType[reqType] = [];
      }

      // Always include Meeting type
      if (!hoursMap.containsKey('Meeting')) {
        hoursMap['Meeting'] = 0;
        hoursByType['Meeting'] = [];
      }

      // Process completed hours
      for (final entry in data) {
        final hours = entry['hours'] + 0.0 ?? 0.0;
        final eventType = entry['type'] as String;
        final eventName = entry['event_name'] as String? ?? 'Unknown Event';
        final dateString = entry['date'] as String?;
        final DateTime date =
            dateString != null ? DateTime.parse(dateString) : DateTime.now();

        // Use normalized type for consistent matching
        final normalizedType = normalizeType(eventType);

        if (hoursMap.containsKey(normalizedType)) {
          hoursMap[normalizedType] = hoursMap[normalizedType]! + hours;

          // Also store the individual hour entries
          hoursByType[normalizedType]!.add(CompletedHour(
            title: eventName,
            date: date,
            hours: hours,
          ));
        }
      }

      setState(() {
        _completedHoursMap = hoursMap;
        _hoursByTypeMap = hoursByType;
      });
    }
  }

  void _showMeetingNotesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Meeting Notes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _meetingNotes.map((note) {
                return ListTile(
                  title: Text(note.title),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showNoteDetailsDialog(note);
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showNoteDetailsDialog(MeetingNote note) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          scrollable: true,
          title: Text(note.title),
          content: Text(note.text),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _openLeaderboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaderboardPage(
          currentUserId: supabase.auth.currentUser?.id ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Completed Hours',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            color: Theme.of(context).colorScheme.primary,
            tooltip: 'View Leaderboard',
            onPressed: _openLeaderboard,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Header with meeting notes button
                    Card(
                      margin: AppDesign.paddingMedium,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppDesign.borderLarge,
                      ),
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: InkWell(
                        onTap: _showMeetingNotesDialog,
                        borderRadius: AppDesign.borderLarge,
                        child: Padding(
                          padding: AppDesign.paddingMedium,
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).colorScheme.secondary,
                                child: Icon(
                                  Icons.notes,
                                  color:
                                      Theme.of(context).colorScheme.onSecondary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Meeting Notes',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'View important information from previous meetings',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer
                                            .withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Hour requirements sections
                    ..._buildRequirementsList(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWebsite,
        icon: const Icon(Icons.report_problem),
        label: const Text('Report Issue'),
        elevation: 4,
      ),
    );
  }

// Build list of requirements with progress and details
  List<Widget> _buildRequirementsList() {
    List<Widget> widgets = [];

    // First build standard hour requirements
    _requirementMap.forEach((type, hoursNeeded) {
      final completedHours = _completedHoursMap[type] ?? 0.0;

      widgets.add(_buildProgressBar(
          context, type, completedHours, hoursNeeded.floor()));

      widgets.add(_buildCompletedHoursList(type, _hoursByTypeMap[type] ?? []));

      widgets.add(const SizedBox(height: 20));
    });

    // Then add the special meeting requirement
    final meetingHours = _completedHoursMap['Meeting'] ?? 0.0;
    widgets.add(_buildProgressBar(
        context, 'Meeting', meetingHours, _meetingRequirement,
        isMeeting: true));

    widgets.add(
        _buildCompletedHoursList('Meeting', _hoursByTypeMap['Meeting'] ?? []));

    return widgets;
  }

  Widget _buildProgressBar(BuildContext context, String title,
      double completedHours, int hoursNeeded,
      {bool isMeeting = false}) {
    // Calculate percentage for display
    final percentage =
        ((completedHours / hoursNeeded) * 100).clamp(0, 100).toInt();
    final isComplete = completedHours >= hoursNeeded;
    final color = Theme.of(context).colorScheme.primary;
    final backgroundColor = Theme.of(context).colorScheme.primaryContainer;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Type with icon
              Row(
                children: [
                  Icon(
                    isMeeting ? Icons.groups_rounded : getIconForType(title, context),
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMeeting ? 'Meeting Attendance' : '$title Hours',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),

              // Completion percentage
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isComplete
                      ? color
                      : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: AppDesign.borderLarge,
                ),
                child: Text(
                  isComplete ? 'Complete!' : '$percentage%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isComplete
                        ? (Theme.of(context).colorScheme.onPrimary)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Hours text and progress
          Row(
            children: [
              Expanded(
                child: Text(
                  '${completedHours.toStringAsFixed(1)} / $hoursNeeded ${isMeeting ? 'meetings' : 'hours'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                isMeeting
                    ? '$completedHours of $hoursNeeded required'
                    : '${(completedHours / hoursNeeded * 100).toStringAsFixed(0)}% complete',
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress bar with animation
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutQuart,
            tween: Tween<double>(
              begin: 0,
              end: (completedHours / hoursNeeded).clamp(0.0, 1.0),
            ),
            builder: (context, value, _) {
              return Stack(
                children: [
                  // Background track
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: backgroundColor.withOpacity(0.3),
                      borderRadius: AppDesign.borderSmall,
                    ),
                  ),

                  // Progress
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 12,
                    width: MediaQuery.of(context).size.width * value * 0.89,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: AppDesign.borderSmall,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedHoursList(String type, List<CompletedHour> hours) {
    if (hours.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          padding: AppDesign.paddingMedium,
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: AppDesign.borderMedium,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.event_busy,
                  size: 32,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  'No ${type.toLowerCase()} hours recorded yet',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              '${hours.length} ${hours.length == 1 ? 'Event' : 'Events'}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: hours.length,
            itemBuilder: (context, index) {
              final hour = hours[index];

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: AppDesign.borderMedium,
                  boxShadow: [
                    BoxShadow(
                      color:
                          Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  dense: false,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    child: Text(
                      hour.title.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    hour.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hour.date.year == 0
                            ? 'Date not recorded'
                            : '${hour.date.month}-${hour.date.day}-${hour.date.year}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: AppDesign.borderLarge,
                    ),
                    child: Text(
                      '${hour.hours.toStringAsFixed(1)}h',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openWebsite() async {
    final Uri url = Uri.parse(
        'https://docs.google.com/forms/d/e/1FAIpQLSeXg0ctE8Lg3r4aLhUSZYWj8GlvxwxM4aTRhf3axEQRljeRtw/viewform');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch url');
    }
  }
}
