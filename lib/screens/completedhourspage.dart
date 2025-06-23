import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nhs_tracker/screens/leadershippage.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import '../models/completedhour.dart';
import '../models/meetingnote.dart';
import 'leaderboardpage.dart';
import '../common/iconutils.dart';
import '../providers/hapticsprovider.dart';

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
            dateString != null ? DateTime.parse(dateString) : DateTime(0);

        if (hoursMap.containsKey(eventType)) {
          hoursMap[eventType] = hoursMap[eventType]! + hours;

          // Also store the individual hour entries
          hoursByType[eventType]!.add(CompletedHour(
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
    final hapticsProvider =
        Provider.of<HapticsProvider>(context, listen: false);
    hapticsProvider.selection();

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
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.light();
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
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
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
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _openLeaderboard() {
    final hapticsProvider =
        Provider.of<HapticsProvider>(context, listen: false);
    hapticsProvider.selection();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaderboardPage(
          currentUserId: supabase.auth.currentUser?.id ?? '',
        ),
      ),
    );
  }

  void _openLeadership() {
    final hapticsProvider =
        Provider.of<HapticsProvider>(context, listen: false);
    hapticsProvider.selection();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeadershipPage(),
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
            icon: const Icon(Icons.groups_3),
            color: Theme.of(context).colorScheme.primary,
            tooltip: 'View Leadership',
            onPressed: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              _openLeadership;
            },
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            color: Theme.of(context).colorScheme.primary,
            tooltip: 'View Leaderboard',
            onPressed: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              _openLeaderboard;
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              color: Theme.of(context).colorScheme.primary,
              onRefresh: _fetchData,
              child: CustomScrollView(
                slivers: [
                  // Meeting Notes Header
                  SliverToBoxAdapter(
                    child: _buildMeetingNotesHeader(),
                  ),

                  // Summary Cards
                  SliverPadding(
                    padding: const EdgeInsets.all(AppDesign.spacingM),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        childAspectRatio:
                            MediaQuery.of(context).size.width > 600 ? 2.2 : 1.8,
                        crossAxisSpacing: AppDesign.spacingM,
                        mainAxisSpacing: AppDesign.spacingM,
                      ),
                      delegate: SliverChildListDelegate([
                        _buildSummaryCard(
                          title: 'Total Hours',
                          value: _calculateTotalHours().toStringAsFixed(1),
                          subtitle: 'All activities',
                          icon: Icons.timer,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        _buildSummaryCard(
                          title: 'Requirements',
                          value:
                              '${_countCompletedRequirements()}/${_requirementMap.length + 1}',
                          subtitle: 'Completed',
                          icon: Icons.check_circle,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ]),
                    ),
                  ),

                  // Requirements List
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      title: 'Your Requirements',
                      subtitle: 'Track your progress towards graduation',
                    ),
                  ),

                  // Hour Requirements
                  SliverList(
                    delegate: SliverChildListDelegate([
                      ..._buildRequirementsList(),
                    ]),
                  ),

                  // Report Issue Button
                  SliverPadding(
                    padding: const EdgeInsets.all(AppDesign.spacingXL),
                    sliver: SliverToBoxAdapter(
                      child: _buildReportIssueButton(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildRequirementsList() {
    List<Widget> widgets = [];

    // First build standard hour requirements
    _requirementMap.forEach((type, hoursNeeded) {
      final completedHours = _completedHoursMap[type] ?? 0.0;
      widgets.add(_buildModernRequirementCard(
        type: type,
        completedHours: completedHours,
        requiredHours: hoursNeeded.floor(),
        hours: _hoursByTypeMap[type] ?? [],
      ));
    });

    // Then add the special meeting requirement
    final meetingHours = _completedHoursMap['Meeting'] ?? 0.0;
    widgets.add(_buildModernRequirementCard(
      type: 'Meeting',
      completedHours: meetingHours,
      requiredHours: _meetingRequirement,
      hours: _hoursByTypeMap['Meeting'] ?? [],
      isMeeting: true,
    ));

    return widgets;
  }

  // Calculate total hours across all requirements
  double _calculateTotalHours() {
    return _completedHoursMap.values.fold(0.0, (sum, hours) => sum + hours);
  }

  Widget _buildSectionHeader(
      {required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDesign.spacingM, AppDesign.spacingL,
          AppDesign.spacingM, AppDesign.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: AppDesign.borderLarge,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppDesign.paddingMedium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppDesign.spacingS),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingNotesHeader() {
    return Container(
      margin: AppDesign.paddingMedium,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
          ],
        ),
        borderRadius: AppDesign.borderLarge,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final hapticsProvider =
                Provider.of<HapticsProvider>(context, listen: false);
            hapticsProvider.light(); // Light haptic for tapping meeting notes
            _showMeetingNotesDialog();
          },
          borderRadius: AppDesign.borderLarge,
          child: Padding(
            padding: AppDesign.paddingLarge,
            child: Row(
              children: [
                Container(
                  padding: AppDesign.paddingMedium,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: AppDesign.borderMedium,
                  ),
                  child: Icon(
                    Icons.notes,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppDesign.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meeting Notes',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review important information from previous meetings',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withOpacity(0.8),
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Count completed requirements
  int _countCompletedRequirements() {
    int completed = 0;

    // Check hour requirements
    for (final entry in _requirementMap.entries) {
      if ((_completedHoursMap[entry.key] ?? 0.0) >= entry.value) {
        completed++;
      }
    }

    // Check meeting requirement
    final meetingHours = _completedHoursMap['Meeting'] ?? 0.0;
    if (meetingHours >= _meetingRequirement) {
      completed++;
    }

    return completed;
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
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
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

  Widget _buildModernRequirementCard({
    required String type,
    required double completedHours,
    required int requiredHours,
    required List<CompletedHour> hours,
    bool isMeeting = false,
  }) {
    final percentage = ((completedHours / requiredHours) * 100).clamp(0, 100);
    final isComplete = completedHours >= requiredHours;
    final icon =
        isMeeting ? Icons.groups_rounded : getIconForType(type, context);

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppDesign.spacingM, 0, AppDesign.spacingM, AppDesign.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppDesign.borderLarge,
        border: Border.all(
          color: isComplete
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: AppDesign.paddingMedium,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: AppDesign.borderMedium,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppDesign.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMeeting ? 'Meeting Attendance' : '$type Hours',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${completedHours.toStringAsFixed(1)} / $requiredHours ${isMeeting ? 'meetings' : 'hours'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                // Status chip
                AnimatedContainer(
                  duration: AppDesign.animationShort,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: AppDesign.borderRound,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isComplete)
                        Icon(
                          Icons.check,
                          size: 14,
                          color: Theme.of(context).colorScheme.onPrimary,
                        )
                      else
                        SizedBox(width: 14),
                      const SizedBox(width: 4),
                      Text(
                        isComplete ? 'Complete' : '${percentage.round()}%',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isComplete
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesign.spacingM),
            child: ClipRRect(
              borderRadius: AppDesign.borderLarge,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(
                  begin: 0,
                  end: (completedHours / requiredHours).clamp(0.0, 1.0),
                ),
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 12,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    year2023: false,
                  );
                },
              ),
            ),
          ),

          // Event list or empty state
          Padding(
            padding: AppDesign.paddingMedium,
            child:
                hours.isEmpty ? _buildEmptyState(type) : _buildEventList(hours),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    return Container(
      width: double.infinity,
      padding: AppDesign.paddingLarge,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: AppDesign.borderMedium,
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy,
            size: 32,
            color:
                Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
          const SizedBox(height: AppDesign.spacingS),
          Text(
            'No ${type.toLowerCase()} hours recorded yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.8),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(List<CompletedHour> hours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${hours.length} ${hours.length == 1 ? 'Event' : 'Events'}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppDesign.spacingS),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: hours.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppDesign.spacingS),
          itemBuilder: (context, index) {
            final hour = hours[index];
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                borderRadius: AppDesign.borderMedium,
              ),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    hour.title.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                title: Text(
                  hour.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                subtitle: Text(
                  hour.date.year == 0
                      ? 'Date not recorded'
                      : '${hour.date.month}-${hour.date.day}-${hour.date.year}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: AppDesign.borderMedium,
                  ),
                  child: Text(
                    '${hour.hours.toStringAsFixed(1)}h',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
    );
  }

  Widget _buildReportIssueButton() {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    final customUrl = society?.errorFormUrl;
    print(customUrl);
    if (customUrl == null) {
      return SizedBox();
    }
    return OutlinedButton.icon(
      onPressed: () {
        final hapticsProvider =
            Provider.of<HapticsProvider>(context, listen: false);
        hapticsProvider.selection();
        _openWebsite;
      },
      icon: const Icon(Icons.bug_report),
      label: const Text('Report an Issue'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spacingL,
          vertical: AppDesign.spacingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderMedium,
        ),
      ),
    );
  }

  void _openWebsite() async {
    final hapticsProvider =
        Provider.of<HapticsProvider>(context, listen: false);
    hapticsProvider.selection();
    // Get the current society from the provider
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    final customUrl = society?.errorFormUrl;

    // Define the default URL (your original hardcoded one)
    const String defaultUrl =
        'https://docs.google.com/forms/d/e/1FAIpQLSeXg0ctE8Lg3r4aLhUSZYWj8GlvxwxM4aTRhf3axEQRljeRtw/viewform';

    // Use the custom URL if it exists and is not empty, otherwise use the default
    final String urlToLaunch =
        (customUrl != null && customUrl.isNotEmpty) ? customUrl : defaultUrl;

    try {
      final Uri url = Uri.parse(urlToLaunch);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        // Show a more user-friendly error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch URL: $urlToLaunch')),
          );
        }
      }
    } catch (e) {
      // Handle potential Uri.parse errors for invalid URLs
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid URL format: $urlToLaunch')),
        );
      }
    }
  }
}
