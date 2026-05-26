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
import 'package:intl/intl.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';

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
            onPressed:
              _openLeadership,
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            color: Theme.of(context).colorScheme.primary,
            tooltip: 'View Leaderboard',
            onPressed:_openLeaderboard,
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

Widget _buildMeetingNotesHeader() {
  final hasNotes = _meetingNotes.isNotEmpty;
  final noteCount = _meetingNotes.length;
  final colorScheme = Theme.of(context).colorScheme;

  return Container(
    margin: AppDesign.paddingMedium,
    child: Hero(
      tag: 'meeting_notes_card',
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              Provider.of<HapticsProvider>(context, listen: false).light();
              _showEnhancedMeetingNotesDialog();
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.notes_rounded,
                      color: colorScheme.onSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Meeting Notes',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        if (hasNotes) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.secondary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$noteCount',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: colorScheme.onSecondaryContainer.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// Enhanced Meeting Notes Dialog
void _showEnhancedMeetingNotesDialog() {
  final hapticsProvider = Provider.of<HapticsProvider>(context, listen: false);
  hapticsProvider.selection();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.notes_rounded,
                      color: Theme.of(context).colorScheme.onSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meeting Notes',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                        ),
                        Text(
                          '${_meetingNotes.length} notes available',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      hapticsProvider.selection();
                      Navigator.pop(context);
                    },
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ],
              ),
            ),
            
            // Notes list
            Expanded(
              child: _meetingNotes.isEmpty
                  ? _buildEmptyNotesState()
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _meetingNotes.length,
                      itemBuilder: (context, index) {
                        final note = _meetingNotes[index];
                        final isRecent = note.createdAt.isAfter(
                          DateTime.now().subtract(const Duration(days: 7)),
                        );
                        
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                hapticsProvider.light();
                                Navigator.pop(context);
                                _showEnhancedNoteDetailsDialog(note);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isRecent 
                                      ? Theme.of(context).colorScheme.tertiary.withOpacity(0.3)
                                      : Theme.of(context).colorScheme.outlineVariant,
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Date badge
                                      Container(
                                        width: 60,
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
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _getTimeAgo(note.createdAt),
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Arrow indicator
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Enhanced Note Details Dialog
void _showEnhancedNoteDetailsDialog(MeetingNote note) {
  QuillController displayController;
  
  if (note.content != null && note.content!.isNotEmpty) {
    try {
      final deltaJson = jsonDecode(note.content!);
      displayController = QuillController(
        document: Document.fromJson(deltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      displayController = QuillController.basic();
      displayController.document.insert(0, note.text);
    }
  } else {
    displayController = QuillController.basic();
    displayController.document.insert(0, note.text);
  }

  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.yMMMd().format(note.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: QuillEditor.basic(
                  controller: displayController,
                  config: const QuillEditorConfig(),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () {
                      displayController.dispose();
                      Navigator.pop(context);
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
// Empty state for meeting notes
Widget _buildEmptyNotesState() {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.note_add_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Meeting Notes Yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Meeting notes from your society will appear here',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// Helper function for time ago
String _getTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays > 30) {
    return DateFormat('MMM d, y').format(dateTime);
  } else if (difference.inDays > 7) {
    final weeks = (difference.inDays / 7).floor();
    return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
  } else {
    return 'Just now';
  }
}
}
