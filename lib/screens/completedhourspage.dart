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
import '../models/continuouseventsubmission.dart';
import 'leaderboardpage.dart';
import '../common/iconutils.dart';
import '../providers/hapticsprovider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';
import '../data/supabase_client.dart';
import '../logic/relative_time.dart';


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
  List<ContinuousEventSubmission> _pendingSubmissions = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Get current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        if (mounted) setState(() => _isLoading = false);
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
        _fetchPendingSubmissions(),
      ]);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMeetingNotes() async {
    try {
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) return;

      final response = await supabase
          .from('Notes')
          .select('*')
          .eq('society_id', society.id)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _meetingNotes =
            response.map((json) => MeetingNote.fromJson(json)).toList();
      });
    } catch (e) {
      debugPrint('Error fetching meeting notes: $e');
    }
  }

  Future<void> _fetchCompletedHours() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;

    if (userId != null && society != null) {
      // Get all service hours for this user in this society in a single query
      final response = await supabase
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
        final hours = (entry['hours'] as num?)?.toDouble() ?? 0.0;
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

      if (!mounted) return;
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
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
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

                  // Requirements List
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      title: 'Your Requirements',
                    ),
                  ),

                  // Summary Cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppDesign.spacingM, 0, AppDesign.spacingM, AppDesign.spacingM),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Total Hours',
                              value: _calculateTotalHours().toStringAsFixed(1),
                              subtitle: 'All activities',
                              icon: Icons.timer,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppDesign.spacingM),
                          Expanded(
                            child: _buildSummaryCard(
                              title: 'Requirements',
                              value:
                                  '${_countCompletedRequirements()}/${_requirementMap.length + 1}',
                              subtitle: 'Completed',
                              icon: Icons.check_circle,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Hour Requirements
                  SliverList(
                    delegate: SliverChildListDelegate([
                      ..._buildRequirementsList(),
                    ]),
                  ),

                  // Pending Submissions (continuous events awaiting review)
                  if (_pendingSubmissions.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _buildSectionHeader(
                        title: 'Pending Submissions',
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) =>
                            _buildPendingSubmissionTile(_pendingSubmissions[i]),
                        childCount: _pendingSubmissions.length,
                      ),
                    ),
                  ],

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

  Widget _buildSectionHeader({required String title}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDesign.spacingM, AppDesign.spacingL,
          AppDesign.spacingM, AppDesign.spacingM),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
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
                    hour.title.isNotEmpty
                        ? hour.title.substring(0, 1).toUpperCase()
                        : '?',
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
    debugPrint(customUrl);
    if (customUrl == null) {
      return SizedBox();
    }
    return OutlinedButton.icon(
      onPressed: _openWebsite,
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
      // Links saved without a scheme (e.g. "forms.gle/abc") parse to a
      // schemeless URI the OS can't resolve, so default to https://.
      var url = Uri.parse(urlToLaunch.trim());
      if (!url.hasScheme) {
        url = Uri.parse('https://${urlToLaunch.trim()}');
      }
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
    builder: (context) => _MeetingNotesSheet(
      notes: _meetingNotes,
      haptics: hapticsProvider,
    ),
  );
}

Future<void> _fetchPendingSubmissions() async {
  try {
    final userId = supabase.auth.currentUser?.id;
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (userId == null || society == null) {
      if (mounted) setState(() => _pendingSubmissions = []);
      return;
    }
    final rows = await supabase
        .from('continuous_event_submissions')
        .select('*, continuous_events!inner(name)')
        .eq('user_id', userId)
        .eq('society_id', society.id)
        .inFilter('status', ['pending', 'rejected'])
        .order('created_at', ascending: false);

    if (!mounted) return;
    setState(() {
      _pendingSubmissions = (rows as List)
          .map((r) =>
              ContinuousEventSubmission.fromJson(r as Map<String, dynamic>))
          .toList();
    });
  } catch (e) {
    debugPrint('Error fetching pending submissions: $e');
  }
}

Widget _buildPendingSubmissionTile(ContinuousEventSubmission s) {
  final scheme = Theme.of(context).colorScheme;
  final dateFmt = DateFormat.yMMMd();
  final isRejected = s.isRejected;
  final statusColor = isRejected ? scheme.error : scheme.primary;
  final statusLabel = isRejected ? 'Rejected' : 'Pending review';
  final eventName = s.continuousEventName ?? 'Ongoing opportunity';

  return Container(
    margin: const EdgeInsets.fromLTRB(
        AppDesign.spacingM, 0, AppDesign.spacingM, AppDesign.spacingS),
    decoration: BoxDecoration(
      color: scheme.surface,
      borderRadius: AppDesign.borderLarge,
      border: Border.all(color: scheme.outlineVariant, width: 1),
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
        padding: AppDesign.paddingMedium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.hours} hr • ${dateFmt.format(s.activityDate)}',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: AppDesign.borderRound,
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (isRejected &&
                s.reviewerNotes != null &&
                s.reviewerNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: AppDesign.paddingSmall,
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withOpacity(0.4),
                  borderRadius: AppDesign.borderSmall,
                ),
                child: Text('Reviewer: ${s.reviewerNotes!}',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
  );
}
}

// Meeting notes bottom sheet. Switches its content in place between the notes
// list and a single note's details instead of closing and reopening a dialog.
class _MeetingNotesSheet extends StatefulWidget {
  final List<MeetingNote> notes;
  final HapticsProvider haptics;

  const _MeetingNotesSheet({
    required this.notes,
    required this.haptics,
  });

  @override
  State<_MeetingNotesSheet> createState() => _MeetingNotesSheetState();
}

class _MeetingNotesSheetState extends State<_MeetingNotesSheet> {
  MeetingNote? _selectedNote;
  QuillController? _detailController;

  @override
  void dispose() {
    _detailController?.dispose();
    super.dispose();
  }

  void _openNote(MeetingNote note) {
    widget.haptics.light();
    setState(() {
      _detailController?.dispose();
      _detailController = _buildControllerFor(note);
      _selectedNote = note;
    });
  }

  void _backToList() {
    widget.haptics.selection();
    setState(() {
      _selectedNote = null;
      _detailController?.dispose();
      _detailController = null;
    });
  }

  QuillController _buildControllerFor(MeetingNote note) {
    if (note.content != null && note.content!.isNotEmpty) {
      try {
        final deltaJson = jsonDecode(note.content!);
        return QuillController(
          document: Document.fromJson(deltaJson),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        final controller = QuillController.basic();
        controller.document.insert(0, note.text);
        return controller;
      }
    }
    final controller = QuillController.basic();
    controller.document.insert(0, note.text);
    return controller;
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _selectedNote == null
              ? _buildListView(scrollController)
              : _buildDetailView(_selectedNote!),
        ),
      ),
    );
  }

  Widget _buildListView(ScrollController scrollController) {
    return Column(
      key: const ValueKey('meeting_notes_list'),
      children: [
        // Handle bar + header
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSecondaryContainer
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 8, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meeting Notes',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                          Text(
                            '${widget.notes.length} ${widget.notes.length == 1 ? 'note' : 'notes'} available',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer
                                  .withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        widget.haptics.selection();
                        Navigator.pop(context);
                      },
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Notes list
        Expanded(
          child: widget.notes.isEmpty
              ? _buildEmptyNotesState()
              : ListView.builder(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: widget.notes.length,
                  itemBuilder: (context, index) {
                    final note = widget.notes[index];
                    final isRecent = note.createdAt.isAfter(
                      DateTime.now().subtract(const Duration(days: 7)),
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openNote(note),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isRecent
                                    ? Theme.of(context)
                                        .colorScheme
                                        .tertiary
                                        .withOpacity(0.3)
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
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
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isRecent
                                          ? Theme.of(context)
                                              .colorScheme
                                              .tertiaryContainer
                                          : Theme.of(context)
                                              .colorScheme
                                              .surfaceVariant,
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
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onTertiaryContainer
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('dd').format(note.createdAt),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: isRecent
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onTertiaryContainer
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Note content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                note.title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (isRecent)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .tertiary,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'NEW',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onTertiary,
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withOpacity(0.7),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              timeAgo(note.createdAt),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withOpacity(0.7),
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.5),
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
    );
  }

  Widget _buildDetailView(MeetingNote note) {
    return Column(
      key: const ValueKey('meeting_note_detail'),
      children: [
        // Handle bar + header with back button
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSecondaryContainer
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back to notes',
                      onPressed: _backToList,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat.yMMMd().format(note.createdAt),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer
                                  .withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        widget.haptics.selection();
                        Navigator.pop(context);
                      },
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Note body
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: QuillEditor.basic(
              controller: _detailController!,
              config: QuillEditorConfig(
                onLaunchUrl: (url) async {
                  final uri = Uri.tryParse(url);
                  if (uri == null) return;
                  try {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open link')),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

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
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withOpacity(0.3),
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

}
