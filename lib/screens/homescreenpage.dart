import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as add2cal;
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter/src/painting/box_border.dart' as border;
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import '../models/timeslot.dart';
import '../models/hourrequirement.dart';
import '../models/honorsociety.dart';
import '../models/collection.dart';
import '../models/completedhour.dart';
import '../models/event.dart';
import '../models/swaprequest.dart';
import '../models/userprofile.dart';
import '../models/attendee.dart';
import '../models/continuousevent.dart';
import '../models/continuouseventsubmission.dart';
import '../common/customexpansiontile.dart';
import '../common/nhsformatutils.dart';
import '../models/logactivity.dart';
import '../common/iconutils.dart';
import '../common/normalizetype.dart';
import 'package:provider/provider.dart';
import '../providers/hapticsprovider.dart';
import 'continuouseventdetailpage.dart';

final supabase = Supabase.instance.client;

class HomePage extends StatefulWidget {
  final HonorSociety? society;

  const HomePage({super.key, this.society});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentPageIndex = 0;
  List<Collection> _collections = [];
  List<Event> _events = [];
  String _selectedEventType = 'All';
  String _searchQuery = '';
  bool _showSignedUpOnly = false;
  String _dateFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  late Map<String, double> _completedHoursMap = {};
  late Map<String, double> _potentialHoursMap = {};
  late Map<String, double> _requirementMap = {};
  int _meetingRequirement = 5;
  List<String> _availableEventTypes = ['All'];
  bool _isLoading = true;
  List<ContinuousEvent> _continuousEvents = [];
  // event id -> most recent submission for the current user (for status pill)
  Map<int, ContinuousEventSubmission> _myLatestSubmissionByEvent = {};
  // Raw pending swap-request rows targeted at the current user (with nested
  // Events / profiles / "Time slots"). Rendered as the home-screen inbox.
  List<Map<String, dynamic>> _pendingSwapRequests = [];
  final DateFormat formatter = DateFormat('jm');

  @override
  void initState() {
    super.initState();
    _fetchData();
    _checkPendingSwapRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Get the current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get society requirements
      _meetingRequirement = society.meetingRequirement;
      _requirementMap = {};
      _availableEventTypes = ['All'];

      for (final req in society.hourRequirements) {
        if (req.isActive) {
          _requirementMap[req.type] = req.hoursNeeded;
          if (!_availableEventTypes.contains(req.type)) {
            _availableEventTypes.add(req.type);
          }
        }
      }

      // Add Meeting type if not already present
      if (!_availableEventTypes.contains('Meeting')) {
        _availableEventTypes.add('Meeting');
      }

      // Run fetches in parallel
      await Future.wait([
        _fetchEvents(),
        _fetchCollections(),
        _fetchCompletedHours(),
        _fetchContinuousEvents(),
      ]);

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEvents() async {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return;

    // 1) Fetch all events for the society.
    final eventResponse = await Supabase.instance.client
        .from('Events')
        .select()
        .eq('society_id', society.id)
        .gt('date',
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String())
        .order('date');

    final List<Event> events =
        (eventResponse as List).map((json) => Event.fromJson(json)).toList();

    if (events.isEmpty) {
      if (mounted) setState(() => _events = []);
      return;
    }

    final List<int> eventIds =
        events.map((e) => e.id).whereType<int>().toList();

    // 2) Fetch every time slot for those events in a single batched query.
    final timeSlotResponse = await Supabase.instance.client
        .from('Time slots')
        .select()
        .inFilter('event_id', eventIds);

    final List<TimeSlot> timeSlots = (timeSlotResponse as List)
        .map((json) => TimeSlot.fromJson(json))
        .toList();

    final Map<int, List<TimeSlot>> slotsByEvent = {};
    for (final ts in timeSlots) {
      slotsByEvent.putIfAbsent(ts.eventId, () => []).add(ts);
    }

    // 3) Fetch every attendee for those time slots in a single batched query.
    final List<int> timeSlotIds =
        timeSlots.map((ts) => ts.id).whereType<int>().toList();

    final Map<int, List<Attendee>> attendeesBySlot = {};
    if (timeSlotIds.isNotEmpty) {
      final attendeeResponse = await Supabase.instance.client
          .from('Attendees')
          .select('*, profiles!inner(name)')
          .inFilter('timeslot_id', timeSlotIds);

      for (final json in attendeeResponse as List) {
        final attendee = Attendee.fromJson({
          ...json,
          'name': json['profiles']['name'],
        });
        final tsId = json['timeslot_id'] as int?;
        if (tsId != null) {
          attendeesBySlot.putIfAbsent(tsId, () => []).add(attendee);
        }
      }
    }

    // 4) Stitch attendees into time slots and time slots into events.
    for (final ts in timeSlots) {
      if (ts.id != null) ts.attendees = attendeesBySlot[ts.id!] ?? [];
    }
    for (final event in events) {
      event.timeSlots = slotsByEvent[event.id] ?? [];
    }

    if (mounted) {
      setState(() {
        _events = events;
        _events.sort((a, b) => a.date.compareTo(b.date));
      });
    }
  }

  Future<void> _fetchCompletedHours() async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;

    if (userId != null && society != null) {
      // Get user's service hours for this society in a single query
      final response = await Supabase.instance.client
          .from('Service hours')
          .select('hours, type, event_name, date')
          .eq('user_id', userId)
          .eq('society_id', society.id);

      if (_events != null) {
        final data = response;
        Map<String, double> completedHoursMap = {};
        Map<String, double> potentialHoursMap = {};
        Map<String, List<CompletedHour>> hoursByTypeMap = {};

        // Initialize maps with all requirement types
        for (final reqType in _requirementMap.keys) {
          completedHoursMap[reqType] = 0;
          potentialHoursMap[reqType] = 0;
          hoursByTypeMap[reqType] = [];
        }

        // Always include Meeting type
        if (!completedHoursMap.containsKey('Meeting')) {
          completedHoursMap['Meeting'] = 0;
          potentialHoursMap['Meeting'] = 0;
          hoursByTypeMap['Meeting'] = [];
        }

        // Process completed hours
        for (final entry in data) {
          final hours = (entry['hours'] as num?)?.toDouble() ?? 0.0;
          final eventType = entry['type'] as String;
          final eventName = entry['event_name'] as String? ?? 'Unknown Event';
          final dateString = entry['date'] as String?;
          final DateTime date =
              dateString != null ? DateTime.parse(dateString) : DateTime.now();

          if (completedHoursMap.containsKey(eventType)) {
            completedHoursMap[eventType] =
                completedHoursMap[eventType]! + hours;
            potentialHoursMap[eventType] =
                potentialHoursMap[eventType]! + hours;

            // Also store the individual hour entries
            hoursByTypeMap[eventType]!.add(CompletedHour(
              title: eventName,
              date: date,
              hours: hours,
            ));
          }
        }

        // Process potential hours from upcoming events
        for (final event in _events) {
          for (final timeSlot in event.timeSlots) {
            final isSignedUp =
                timeSlot.attendees.any((attendee) => attendee.userId == userId);
            final isNotPresent = timeSlot.attendees.any(
                (attendee) => attendee.userId == userId && !attendee.isPresent);

            if (isSignedUp && isNotPresent) {
              final duration = NhsFormatUtils.calculateDuration(
                  timeSlot.time, timeSlot.endTime);

              if (potentialHoursMap.containsKey(event.type)) {
                potentialHoursMap[event.type] =
                    potentialHoursMap[event.type]! + duration;
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            // Store the full maps for dynamic rendering
            _completedHoursMap = completedHoursMap;
            _potentialHoursMap = potentialHoursMap;
          });
        }
      }
    }
  }

  // Build event type filter chips based on society requirements
  List<Widget> _buildEventTypeChips(ThemeData theme) {
    return _availableEventTypes.map((type) {
      final bool isSelected = _selectedEventType == type;
      return _buildAnimatedFilterChip(
        theme: theme,
        label: type,
        isSelected: isSelected,
        onSelected: () {
          if (mounted) setState(() => _selectedEventType = type);
        },
      );
    }).toList();
  }

  List<Event> _getFilteredEvents() {
    List<Event> events = _events;

    if (_selectedEventType != 'All') {
      events = events
          .where((e) => normalizeType(e.type) == normalizeType(_selectedEventType))
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      events = events
          .where((e) =>
              e.name.toLowerCase().contains(q) ||
              e.description.toLowerCase().contains(q) ||
              (e.location?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    if (_showSignedUpOnly) {
      final userId = supabase.auth.currentUser?.id;
      events = events
          .where((e) =>
              e.timeSlots.any((ts) => ts.attendees.any((a) => a.userId == userId)))
          .toList();
    }

    if (_dateFilter == 'This Week') {
      final cutoff = DateTime.now().add(const Duration(days: 7));
      events = events.where((e) => !e.date.isAfter(cutoff)).toList();
    } else if (_dateFilter == 'This Month') {
      final now = DateTime.now();
      final cutoff = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      events = events.where((e) => !e.date.isAfter(cutoff)).toList();
    }

    return events;
  }

  Widget _buildAnimatedFilterChip({
    required ThemeData theme,
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    // Define shapes - no explicit borders needed on the shapes themselves now
    final ShapeBorder unselectedShape = StadiumBorder(); // Pill shape
    final ShapeBorder selectedShape = RoundedRectangleBorder(
      borderRadius:
          AppDesign.borderMedium, // e.g., BorderRadius.circular(12.0) or 16.0
    );

    // Define colors
    final Color unselectedBackgroundColor =
        theme.colorScheme.surfaceVariant.withOpacity(0.7);
    final Color selectedBackgroundColor = theme.colorScheme.primaryContainer;
    final Color unselectedLabelColor = theme.colorScheme.onSurfaceVariant;
    final Color selectedLabelColor = theme.colorScheme.onPrimaryContainer;
    final Color iconColor =
        isSelected ? selectedLabelColor : unselectedLabelColor;

    return GestureDetector(
      onTap: () {
        final hapticsProvider =
            Provider.of<HapticsProvider>(context, listen: false);
        hapticsProvider.light();
        onSelected();
      },
      child: AnimatedContainer(
        duration: AppDesign.animationShort,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDesign.spacingL - 4,
            vertical: AppDesign.spacingS + 2),
        decoration: ShapeDecoration(
          color:
              isSelected ? selectedBackgroundColor : unselectedBackgroundColor,
          shape: isSelected ? selectedShape : unselectedShape,
          // No shadows by default for a flatter, cleaner look, but you can add them:
          // shadows: isSelected ? [
          //   BoxShadow(
          //     color: theme.colorScheme.shadow.withOpacity(0.1),
          //     blurRadius: 4,
          //     offset: const Offset(0, 2),
          //   )
          // ] : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isSelected ? selectedLabelColor : unselectedLabelColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collectionsWithEvents = _getCollectionsWithEvents();
    final uncategorizedEvents = _getUncategorizedEvents();
    final totalItems =
        collectionsWithEvents.length + uncategorizedEvents.length;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        title: Text(
          'Home',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                year2023: false,
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_pendingSwapRequests.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildSwapRequestsHeader(),
                      const SizedBox(height: 8),
                      ..._pendingSwapRequests.map(_buildSwapRequestCard),
                      const SizedBox(height: 16),
                    ],
                    // Progress bars for each requirement type
                    ..._buildProgressBars(),

                    const SizedBox(height: 20),

                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search events…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: AppDesign.borderMedium,
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Event type filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        spacing: 6,
                        children: [
                          ..._buildEventTypeChips(Theme.of(context)),
                          _buildAnimatedFilterChip(
                            theme: Theme.of(context),
                            label: 'Signed Up',
                            isSelected: _showSignedUpOnly,
                            onSelected: () => setState(
                                () => _showSignedUpOnly = !_showSignedUpOnly),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Collections and Events
                    if (totalItems == 0)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: totalItems,
                        itemBuilder: (context, index) {
                          if (index < collectionsWithEvents.length) {
                            // Render collection
                            return _buildCollectionCard(
                                collectionsWithEvents[index]);
                          } else {
                            // Render uncategorized event
                            final eventIndex =
                                index - collectionsWithEvents.length;
                            return _buildEventCard(
                                uncategorizedEvents[eventIndex]);
                          }
                        },
                      ),

                    // Ongoing / external opportunities
                    if (_continuousEvents.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildOngoingHeader(),
                      const SizedBox(height: 8),
                      ..._continuousEvents
                          .map((ce) => _buildContinuousEventCard(ce)),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _fetchContinuousEvents() async {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (society == null || userId == null) {
      if (mounted) {
        setState(() {
          _continuousEvents = [];
          _myLatestSubmissionByEvent = {};
        });
      }
      return;
    }

    try {
      final eventRows = await Supabase.instance.client
          .from('continuous_events')
          .select()
          .eq('society_id', society.id)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final events = (eventRows as List)
          .map((e) => ContinuousEvent.fromJson(e as Map<String, dynamic>))
          .toList();

      Map<int, ContinuousEventSubmission> latest = {};
      if (events.isNotEmpty) {
        final subRows = await Supabase.instance.client
            .from('continuous_event_submissions')
            .select()
            .eq('user_id', userId)
            .inFilter('continuous_event_id', events.map((e) => e.id).toList())
            .order('created_at', ascending: false);

        for (final row in (subRows as List)) {
          final s = ContinuousEventSubmission.fromJson(
              row as Map<String, dynamic>);
          latest.putIfAbsent(s.continuousEventId, () => s);
        }
      }

      if (!mounted) return;
      setState(() {
        _continuousEvents = events;
        _myLatestSubmissionByEvent = latest;
      });
    } catch (e) {
      debugPrint('Error fetching continuous events: $e');
    }
  }

  Widget _buildSwapRequestsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(Icons.swap_horiz,
              color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Swap Requests',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapRequestCard(Map<String, dynamic> row) {
    final scheme = Theme.of(context).colorScheme;
    final swapRequest = SwapRequest.fromJson(row);
    final eventData = row['Events'] as Map<String, dynamic>?;
    final profileData = row['profiles'] as Map<String, dynamic>?;
    final requesterName = profileData?['name'] ?? 'A member';
    final eventName = eventData?['name'] ?? 'an event';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppDesign.borderLarge,
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$requesterName wants to swap',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '$eventName • ${formatter.format(swapRequest.startTime)} - ${formatter.format(swapRequest.endTime)}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    Provider.of<HapticsProvider>(context, listen: false)
                        .selection();
                    _declineSwapRequest(swapRequest);
                    await _checkPendingSwapRequests();
                  },
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: eventData == null
                      ? null
                      : () async {
                          Provider.of<HapticsProvider>(context, listen: false)
                              .selection();
                          final already = await _isAlreadySignedUp(swapRequest);
                          if (already) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'You already hold this slot.')),
                              );
                            }
                            return;
                          }
                          _acceptSwapRequest(swapRequest, eventData);
                          await _checkPendingSwapRequests();
                        },
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOngoingHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(Icons.repeat,
              color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Ongoing Opportunities',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinuousEventCard(ContinuousEvent ce) {
    final scheme = Theme.of(context).colorScheme;
    final latest = _myLatestSubmissionByEvent[ce.id];

    Widget? statusPill;
    if (latest != null) {
      Color color;
      String label;
      switch (latest.status) {
        case 'approved':
          color = Colors.green;
          label = 'Approved';
          break;
        case 'rejected':
          color = scheme.error;
          label = 'Rejected';
          break;
        default:
          color = scheme.primary;
          label = 'Pending';
      }
      statusPill = _buildBadge(
        label,
        latest.isApproved
            ? Icons.check_circle
            : latest.isRejected
                ? Icons.cancel
                : Icons.hourglass_top,
        color,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: InkWell(
              onTap: () async {
                Provider.of<HapticsProvider>(context, listen: false)
                    .selection();
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ContinuousEventDetailPage(event: ce),
                  ),
                );
                _fetchContinuousEvents();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event icon
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: scheme.primary.withOpacity(0.15),
                      child: Icon(
                        getIconForType(ce.type, context),
                        color: scheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Event details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and status badge row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ce.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (statusPill != null) statusPill,
                            ],
                          ),

                          // Ongoing label and type chip
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.repeat,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${ce.steps.length} step${ce.steps.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 13.0,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withOpacity(0.1),
                                  borderRadius: AppDesign.borderSmall,
                                ),
                                child: Text(
                                  ce.type,
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (ce.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              ce.description,
                              style: TextStyle(
                                fontSize: 13.0,
                                color: scheme.onSurface.withOpacity(0.8),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Affordance chevron
                    Icon(
                      Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppDesign.spacingXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDesign.spacingL),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: AppDesign.borderRound,
            ),
            child: Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.6),
            ),
          ),
          const SizedBox(height: AppDesign.spacingL),
          Text(
            'No events found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppDesign.spacingS),
          Text(
            _selectedEventType != 'All'
                ? 'Try changing your filter or check back later'
                : 'Check back later for upcoming events',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
          ),
          if (_selectedEventType != 'All') ...[
            const SizedBox(height: AppDesign.spacingM),
            OutlinedButton.icon(
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear filter'),
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                setState(() {
                  _selectedEventType = 'All';
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Retrieves all collections from the database.
  /// Updates the state with fetched collections.
  ///
  /// Returns:
  /// - Future<void>
  ///
  /// Throws:
  /// - DatabaseException if collection fetch fails
  Future<void> _fetchCollections() async {
    try {
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;

      if (society == null) {
        setState(() => _collections = []);
        return;
      }

      final response = await Supabase.instance.client
          .from('Collections')
          .select('*')
          .eq('society_id', society.id);

      final List<dynamic> data = response;
      if (mounted) {
        setState(() {
          _collections = data.map((json) => Collection.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching collections: $e');
      if (mounted) {
        setState(() => _collections = []);
      }
    }
  }

  List<Collection> _getCollectionsWithEvents() {
    final filteredEvents = _getFilteredEvents();
    return _collections.where((collection) {
      return filteredEvents.any((event) => event.collectionId == collection.id);
    }).toList();
  }

  List<Event> _getUncategorizedEvents() {
    final filteredEvents = _getFilteredEvents();
    return filteredEvents.where((event) => event.collectionId == null).toList();
  }

  // Updated method to create better looking progress bars with Material You styling
  List<Widget> _buildProgressBars() {
    List<Widget> progressBars = [];

    // First add all the hour requirements in more compact cards
    _requirementMap.forEach((type, hoursNeeded) {
      final completedHours = _completedHoursMap[type] ?? 0.0;
      final potentialHours = _potentialHoursMap[type] ?? 0.0;

      progressBars.add(_buildDoubleProgressBar(
          context, type, completedHours, potentialHours, hoursNeeded.floor()));
    });

    // Then add the special meeting requirement
    final meetingHours = _completedHoursMap['Meeting'] ?? 0.0;
    progressBars.add(
        _buildMeetingProgressBar(context, meetingHours, _meetingRequirement));

    return progressBars;
  }

  /// Creates a double progress bar showing completed and potential hours.
  Widget _buildDoubleProgressBar(BuildContext context, String title,
      double completedHours, double potentialHours, int hoursNeeded) {
    final isComplete = completedHours >= hoursNeeded;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppDesign.borderMedium),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: AppDesign.paddingSmall,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title with icon
                Row(
                  children: [
                    Icon(
                      getIconForType(title, context),
                      size: 18,
                      color: isComplete
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$title',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                // Hours text more compact
                Text(
                  '${completedHours.toStringAsFixed(1)} / $hoursNeeded',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isComplete
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Progress bars with animation
            Stack(
              children: [
                // Background track
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: AppDesign.borderSmall,
                  ),
                ),

                // Potential hours progress
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeInOut,
                  tween: Tween<double>(
                    begin: 0,
                    end: (potentialHours / hoursNeeded).clamp(0.0, 1.0),
                  ),
                  builder: (context, potentialValue, _) {
                    return FractionallySizedBox(
                      widthFactor: potentialValue,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                          borderRadius: AppDesign.borderSmall,
                        ),
                      ),
                    );
                  },
                ),

                // Completed hours progress
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutQuart,
                  tween: Tween<double>(
                    begin: 0,
                    end: (completedHours / hoursNeeded).clamp(0.0, 1.0),
                  ),
                  builder: (context, completedValue, _) {
                    return FractionallySizedBox(
                      widthFactor: completedValue,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: isComplete
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.8),
                          borderRadius: AppDesign.borderSmall,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Only show this info if there's additional potential hours
            if (potentialHours > completedHours)
              Padding(
                padding: AppDesign.paddingSmall,
                child: Row(
                  children: [
                    Icon(
                      Icons.upcoming,
                      size: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Potential: ${potentialHours.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.7),
                      ),
                    ),
                    if (isComplete)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Complete',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Creates a progress bar specifically for meeting attendance with Material You styling
  Widget _buildMeetingProgressBar(
      BuildContext context, double completedHours, int hoursNeeded) {
    final meetingsAttended = completedHours.floor();
    final meetingsLeft =
        _events.where((event) => event.type == 'Meeting').length;
    final isComplete = meetingsAttended >= hoursNeeded;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppDesign.borderMedium),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: AppDesign.paddingSmall,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title with icon
                Row(
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 18,
                      color: isComplete
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Meetings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                // Meetings text
                Text(
                  '$meetingsAttended / $hoursNeeded',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isComplete
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
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
                end: (meetingsAttended / hoursNeeded).clamp(0.0, 1.0),
              ),
              builder: (context, value, _) {
                return Stack(
                  children: [
                    // Background track
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: AppDesign.borderSmall,
                      ),
                    ),

                    // Progress
                    FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: isComplete
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context)
                                  .colorScheme
                                  .tertiary
                                  .withOpacity(0.8),
                          borderRadius: AppDesign.borderSmall,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            if (meetingsLeft > 0)
              Padding(
                padding: AppDesign.paddingSmall,
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Upcoming: $meetingsLeft',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.7),
                      ),
                    ),
                    if (isComplete)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 12,
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Complete',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.tertiary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Finds the earliest event date in a collection.
  ///
  /// Parameters:
  /// - collection: Collection - Collection to check
  ///
  /// Returns:
  /// - DateTime
  DateTime _getClosestEventDate(Collection collection) {
    final collectionEvents =
        _events.where((event) => event.collectionId == collection.id).toList();
    return collectionEvents
        .map((event) => event.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  Widget _buildEventCard(Event event) {
    final bool isNew = event.createdAt
        .isAfter(DateTime.now().subtract(const Duration(days: 2)));
    final bool isMandatory = event.isMandatory;
    final currentUserId = supabase.auth.currentUser?.id;

    // Check if forms are required and completed
    final bool formsCompleted = event.timeSlots.any((timeSlot) =>
        timeSlot.attendees.any((attendee) =>
            attendee.userId == currentUserId && attendee.formsCompleted));

    final bool showRequiredForms = event.requiresForms &&
        !formsCompleted &&
        event.timeSlots.any((timeSlot) => timeSlot.attendees
            .any((attendee) => attendee.userId == currentUserId));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppDesign.borderLarge,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomExpansionTile(
              title: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event icon
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.15),
                      child: Icon(
                        getIconForType(event.type, context),
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Event details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and badges row
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Use more compact badges
                              if (showRequiredForms)
                                _buildBadge('Forms', Icons.assignment_late,
                                    Theme.of(context).colorScheme.error)
                              else if (isMandatory)
                                _buildBadge('Required', Icons.priority_high,
                                    Theme.of(context).colorScheme.tertiary)
                              else if (isNew)
                                _buildBadge('New', Icons.new_releases,
                                    Theme.of(context).colorScheme.secondary),
                            ],
                          ),

                          // Date and description
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.event_note,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${event.date.month}/${event.date.day}/${event.date.year}",
                                style: TextStyle(
                                  fontSize: 13.0,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                                  borderRadius: AppDesign.borderSmall,
                                ),
                                child: Text(
                                  event.type,
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (event.location != null &&
                              event.location!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.location!,
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 4),
                          Text(
                            event.description,
                            style: TextStyle(
                              fontSize: 13.0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              children: _buildTimeSlotItems(event, currentUserId),
            ),
    );
  }

// Add this method to build time slot items
  List<Widget> _buildTimeSlotItems(Event event, String? currentUserId) {
    final bool isMandatory = event.isMandatory;

    return event.timeSlots.map((timeSlot) {
      // Get timeslot-specific status
      final isSignedUp = timeSlot.attendees
          .any((attendee) => attendee.userId == currentUserId);

      // Get society requirements and check if user has completed them
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      bool hasCompletedRequirements = false;

      if (society != null) {
        // For Meeting type, use the society's meeting requirement
        if (event.type == 'Meeting') {
          final meetingsCompleted = _completedHoursMap['Meeting'] ?? 0.0;
          hasCompletedRequirements =
              meetingsCompleted >= society.meetingRequirement;
        } else {
          // For other types, find the matching requirement in the society
          final matchingRequirement = society.hourRequirements.firstWhere(
            (req) => normalizeType(req.type) == normalizeType(event.type),
            orElse: () => HourRequirement(
              id: -1,
              type: event.type,
              hoursNeeded: 0,
              description: '',
              isActive: false,
            ),
          );

          // Check if user has completed the required hours for this type
          final completedHours =
              _completedHoursMap[normalizeType(event.type)] ?? 0.0;
          hasCompletedRequirements =
              completedHours >= matchingRequirement.hoursNeeded;
        }
      }

      // Check if signup is delayed
      final canSignUp = !hasCompletedRequirements ||
          !event.hasDelay ||
          event.canSignUpForTimeSlot(timeSlot);

      // Check if we can show the cancel button
      final isTimeSlotInFuture = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        timeSlot.time.hour,
        timeSlot.time.minute,
      ).isAfter(DateTime.now());

      // Check if we can show the swap button
      final canRequestSwap = isSignedUp &&
          DateTime.now()
              .isAfter(event.date.subtract(event.swapRequestDeadline)) &&
          DateTime.now().isBefore(DateTime(
            event.date.year,
            event.date.month,
            event.date.day,
            timeSlot.time.hour,
            timeSlot.time.minute,
          ));

      // Get forms status for this timeslot
      final timeSlotFormsCompleted = isSignedUp
          ? timeSlot.attendees
              .firstWhere((attendee) => attendee.userId == currentUserId)
              .formsCompleted
          : false;

      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: AppDesign.borderSmall,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time info row
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    event.type == 'Meeting'
                        ? timeSlot.time.format(context)
                        : '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const Spacer(),

                  // Add to Calendar icon for signed up users
                  if (isSignedUp)
                    IconButton(
                        icon: Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        tooltip: 'Add to Calendar',
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          _addEventToCalendar(event, timeSlot);
                        }),

                  // Capacity info
                  if (!(event.type == 'Meeting'))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: AppDesign.borderSmall,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people,
                            size: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${timeSlot.numberOfPeople} spots',
                            style: TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Notes if available
              if (timeSlot.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  timeSlot.notes,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              // Action buttons
              const SizedBox(height: 10),
              isSignedUp
                  ? Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        if (canRequestSwap &&
                            event.type != 'Meeting' &&
                            !isMandatory)
                          OutlinedButton.icon(
                              icon: Icon(Icons.swap_horiz, size: 14),
                              label:
                                  Text('Swap', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size(0, 28),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                final hapticsProvider =
                                    Provider.of<HapticsProvider>(context,
                                        listen: false);
                                hapticsProvider.selection();
                                _showSwapRequestDialog(event, timeSlot);
                              }),
                        if (isTimeSlotInFuture &&
                            !isMandatory &&
                            event.type != 'Meeting' &&
                            !canRequestSwap)
                          OutlinedButton.icon(
                              icon: Icon(Icons.cancel, size: 14),
                              label: Text('Cancel',
                                  style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size(0, 28),
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                _removeAttendee(event, timeSlot);
                                final hapticsProvider =
                                    Provider.of<HapticsProvider>(context,
                                        listen: false);
                                hapticsProvider.selection();
                              }),
                        if (event.requiresForms)
                          OutlinedButton.icon(
                              icon: Icon(
                                timeSlotFormsCompleted
                                    ? Icons.inventory
                                    : Icons.pending_actions,
                                size: 14,
                              ),
                              label: Text(
                                  timeSlotFormsCompleted
                                      ? 'Forms'
                                      : 'Need Forms',
                                  style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size(0, 28),
                                foregroundColor: timeSlotFormsCompleted
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.error,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                _showUploadFormsDialog(
                                    event, timeSlot, timeSlotFormsCompleted);
                                final hapticsProvider =
                                    Provider.of<HapticsProvider>(context,
                                        listen: false);
                                hapticsProvider.selection();
                              }),
                      ],
                    )
                  : isMandatory || event.type == 'Meeting'
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: AppDesign.borderSmall,
                          ),
                          child: Center(
                            child: Text(
                              'Automatically Enrolled',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                        )
                      : !canSignUp
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiaryContainer,
                                borderRadius: AppDesign.borderSmall,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.timer,
                                      size: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onTertiaryContainer,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Available ${event.delayHours}h before event',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onTertiaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Visibility(
                            visible: timeSlot.numberOfPeople > 0,
                            child: ElevatedButton.icon(
                                onPressed: () {
                                  _showSignUpForm(event, timeSlot);
                                  final hapticsProvider =
                                      Provider.of<HapticsProvider>(context,
                                          listen: false);
                                  hapticsProvider.medium();
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Sign Up'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  minimumSize: const Size(double.infinity, 36),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppDesign.borderSmall,
                                  ),
                                ),
                              ),
                          ),
            ],
          ),
        ),
      );
    }).toList();
  }

// Helper method to build compact badges
  Widget _buildBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppDesign.borderSmall,
        border: border.Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Displays dialog for initiating a swap request.
  /// Allows user to select another member to swap with.
  ///
  /// Parameters:
  /// - event: Event - Event to swap
  /// - timeSlot: TimeSlot - Time slot to swap
  ///
  /// Returns:
  /// - void
  void _showSwapRequestDialog(Event event, TimeSlot timeSlot) {
    String searchQuery = '';
    List<UserProfile> allUsers = [];
    List<UserProfile> filteredUsers = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Request Swap'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        filteredUsers = allUsers
                            .where((user) => user.name
                                .toLowerCase()
                                .contains(searchQuery.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search Members',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<UserProfile>>(
                    future: _fetchAllUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          allUsers.isEmpty) {
                        return const CircularProgressIndicator(
                          year2023: false,
                        );
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else {
                        if (snapshot.hasData && allUsers.isEmpty) {
                          allUsers = snapshot.data!;
                          filteredUsers = allUsers;
                        }
                        return SizedBox(
                          height: 300,
                          width: 300,
                          child: ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return ListTile(
                                title: Text(user.name),
                                onTap: () {
                                  final hapticsProvider =
                                      Provider.of<HapticsProvider>(context,
                                          listen: false);
                                  hapticsProvider.selection();
                                  _showSwapConfirmationDialog(
                                      event, timeSlot, user);
                                },
                              );
                            },
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
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
      },
    );
  }

  void _showSwapConfirmationDialog(
      Event event, TimeSlot timeSlot, UserProfile targetUser) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Swap Request'),
          content: Text(
              'Are you sure you want to request a swap with ${targetUser.name} for the event "${event.name}"?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Confirm'),
              onPressed: () async {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                // Check if the user has already requested a swap for this time slot
                final hasPendingSwap =
                    await _checkPendingSwap(event.id, timeSlot.id ?? 0);

                if (hasPendingSwap) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'You already have a pending swap request for this time slot.')),
                  );
                } else {
                  _sendSwapRequest(event, timeSlot, targetUser);
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Close both dialogs
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Checks if user has pending swap requests for an event.
  ///
  /// Parameters:
  /// - eventId: int - Event to check
  /// - timeSlotId: int - Time slot to check
  ///
  /// Returns:
  /// - Future<bool>
  Future<bool> _checkPendingSwap(int eventId, int timeSlotId) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final pendingSwaps = await Supabase.instance.client
        .from('swap_requests')
        .select()
        .eq('event_id', eventId)
        .eq('timeslot_id', timeSlotId)
        .eq('requester_id', currentUserId)
        .eq('status', 'pending');

    return pendingSwaps.isNotEmpty;
  }

  /// Creates a new swap request in the database.
  ///
  /// Parameters:
  /// - event: Event - Event to swap
  /// - timeSlot: TimeSlot - Time slot to swap
  /// - targetUser: UserProfile - User to request swap with
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _sendSwapRequest(
      Event event, TimeSlot timeSlot, UserProfile targetUser) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await Supabase.instance.client.from('swap_requests').insert({
        'event_id': event.id,
        'timeslot_id': timeSlot.id,
        'requester_id': currentUserId,
        'target_id': targetUser.id,
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Swap request sent to ${targetUser.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending swap request: $e')),
      );
    }
  }

  /// Retrieves all user profiles with their completed hours.
  /// Used in admin interface for user management.
  ///
  /// Returns:
  /// - Future<void>
  Future<List<UserProfile>> _fetchAllUsers() async {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) return [];

    final response = await Supabase.instance.client
        .from('user_society_memberships')
        .select('profiles!inner(user_id, name)')
        .eq('society_id', society.id)
        .order('user_id');

    return (response as List)
        .map((row) {
          final profile = row['profiles'] as Map<String, dynamic>;
          return UserProfile(
            id: profile['user_id'],
            name: profile['name'],
            completedHours: [],
          );
        })
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Displays dialog for managing form submissions.
  /// Handles form completion status and updates.
  ///
  /// Parameters:
  /// - event: Event - Associated event
  /// - timeSlot: TimeSlot - Associated time slot
  /// - formsCompleted: bool - Current completion status
  ///
  /// Returns:
  /// - void
  void _showUploadFormsDialog(
      Event event, TimeSlot timeSlot, bool hasFilledForms) {
    final currentUserId = supabase.auth.currentUser?.id;
    final attendee = event.timeSlots
        .expand((timeSlot) => timeSlot.attendees)
        .firstWhere((attendee) => attendee.userId == currentUserId,
            orElse: () => Attendee(id: 0, timeSlotId: 0, userId: '', name: ''));

    final bool formsCompleted = attendee.formsCompleted;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(formsCompleted ? 'Forms Completed' : 'Required Forms'),
          content: Text(formsCompleted
              ? 'You have already completed the forms for this event.'
              : 'This event requires forms to be completed.'),
          actions: [
            Row(
              children: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    Navigator.of(context).pop();
                  },
                ),
                SizedBox(
                  width: 4,
                ),
                if (!formsCompleted) ...[
                  ElevatedButton(
                    child: const Text('Fill Out'),
                    onPressed: () {
                      final hapticsProvider =
                          Provider.of<HapticsProvider>(context, listen: false);
                      hapticsProvider.selection();
                      Navigator.of(context).pop();
                      _launchFormLink(event.formLink!);
                    },
                  ),
                  SizedBox(
                    width: 4,
                  ),
                  ElevatedButton(
                    child: const Text('Complete'),
                    onPressed: () {
                      final hapticsProvider =
                          Provider.of<HapticsProvider>(context, listen: false);
                      hapticsProvider.selection();
                      Navigator.of(context).pop();
                      _markFormsAsCompleted(event, timeSlot, true);
                    },
                  ),
                ] else
                  ElevatedButton(
                    child: const Text('Remove Completion'),
                    onPressed: () {
                      final hapticsProvider =
                          Provider.of<HapticsProvider>(context, listen: false);
                      hapticsProvider.selection();
                      Navigator.of(context).pop();
                      _markFormsAsCompleted(event, timeSlot, false);
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Opens external form URL in device browser.
  /// Use
  ///
  /// Parameters:
  /// - urls: String - URL to open
  ///
  /// Returns:
  /// - Future<void>
  ///
  /// Throws:
  /// - PlatformException if URL launch fails
  void _launchFormLink(String urls) async {
    final Uri url = Uri.parse(urls);
    await launchUrl(url);
  }

  /// Updates the form completion status for an attendee.
  ///
  /// Parameters:
  /// - event: Event - Associated event
  /// - timeSlot: TimeSlot - Associated time slot
  /// - completed: bool - New completion status
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _markFormsAsCompleted(
      Event event, TimeSlot timeSlot, bool completed) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('Attendees')
            .update({'forms_completed': completed})
            .eq('user_id', userId)
            .eq('timeslot_id', timeSlot.id ?? 0);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(completed
                  ? 'Forms marked as completed'
                  : 'Form completion status removed')),
        );

        // Refresh the events to update the UI
        _fetchEvents();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating form status: $e')),
      );
    }
  }

  /// Creates a widget displaying collection information and associated events.
  ///
  /// Parameters:
  /// - collection: Collection - Collection to display
  /// - index: int - Index in the collection list
  ///
  /// Returns:
  /// - Widget
  Widget _buildCollectionCard(Collection collection) {
    final filteredEvents = _getFilteredEvents();
    final collectionEvents = filteredEvents
        .where((event) => event.collectionId == collection.id)
        .toList();

    // Don't render if no events
    if (collectionEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get the earliest event date for sorting/display
    final earliestDate = collectionEvents
        .map((e) => e.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.borderLarge,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          shape: RoundedRectangleBorder(
            borderRadius: AppDesign.borderLarge,
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: AppDesign.borderLarge,
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: AppDesign.borderMedium,
            ),
            child: Icon(
              Icons.folder_open,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 24,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      collection.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: AppDesign.borderSmall,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${collectionEvents.length} event${collectionEvents.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Next: ${earliestDate.month}/${earliestDate.day}/${earliestDate.year}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            // Add a subtle divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 8),
            // Render events in the collection
            ...collectionEvents.map((event) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildEventCard(event),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSignUpForm(Event event, TimeSlot timeSlot) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign Up'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Event: ${event.name}'),
              const SizedBox(height: 8),
              Text('Time: ${timeSlot.time.format(context)}'),
              const SizedBox(height: 8),
              Text('Number of People: ${timeSlot.numberOfPeople}'),
            ],
          ),
          actions: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      final hapticsProvider =
                          Provider.of<HapticsProvider>(context, listen: false);
                      hapticsProvider.selection();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 3),
                  ElevatedButton(
                    child: const Text('Sign Up'),
                    onPressed: () {
                      final hapticsProvider =
                          Provider.of<HapticsProvider>(context, listen: false);
                      hapticsProvider.selection();
                      _signUpForTimeSlot(event, timeSlot);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: const Text('Add to Calendar'),
                onPressed: () {
                  final hapticsProvider =
                      Provider.of<HapticsProvider>(context, listen: false);
                  hapticsProvider.selection();
                  _signUpForTimeSlot(event, timeSlot);
                  _addEventToCalendar(event, timeSlot);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDesign.borderXLarge,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Removes a user's attendance registration from a time slot.
  /// Updates available capacity and logs the change.
  ///
  /// Parameters:
  /// - event: Event - Event containing the time slot
  /// - timeSlot: TimeSlot - Time slot to remove from
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _removeAttendee(Event event, TimeSlot timeSlot) async {
    final userId = supabase.auth.currentUser?.id;
    final hapticsProvider =
        Provider.of<HapticsProvider>(context, listen: false);

    try {
      if (userId != null) {
        final society =
            Provider.of<SocietyProvider>(context, listen: false).currentSociety;
        await Supabase.instance.client
            .from('Attendees')
            .delete()
            .eq('timeslot_id', timeSlot?.id ?? 0)
            .eq('user_id', userId);

        await Supabase.instance.client
            .from('Time slots')
            .update({'number_of_people': timeSlot.numberOfPeople + 1}).eq(
                'id', timeSlot?.id ?? 0);

        await logactivity(
          event.name,
          '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
          NhsFormatUtils.calculateDuration(timeSlot.time, timeSlot.endTime),
          'unsignup',
          userId,
          societyId: society?.id,
        );

        _fetchEvents();
      }
    } catch (e) {
      hapticsProvider.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling: $e')),
      );
    }
  }

  /// Registers a user for a specific time slot in an event.
  /// Checks capacity and existing registration.
  ///
  /// Parameters:
  /// - event: Event - Target event
  /// - timeSlot: TimeSlot - Selected time slot
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _signUpForTimeSlot(Event event, TimeSlot timeSlot) async {
    final User? user = supabase.auth.currentUser;
    final userId = user?.id;
    final hapticsProvider =
        Provider.of<HapticsProvider>(context, listen: false);

    try {
      if (userId != null) {
        // Check if the user has completed requirements using existing state

        // Get society's requirements
        final society =
            Provider.of<SocietyProvider>(context, listen: false).currentSociety;
        bool hasCompletedRequirements = false;

        if (society != null) {
          // For Meeting type, use the society's meeting requirement
          if (event.type == 'Meeting') {
            final meetingsCompleted = _completedHoursMap['Meeting'] ?? 0.0;
            hasCompletedRequirements =
                meetingsCompleted >= society.meetingRequirement;
          } else {
            // For other types, find the matching requirement in the society
            final matchingRequirement = society.hourRequirements.firstWhere(
              (req) => normalizeType(req.type) == normalizeType(event.type),
              orElse: () => HourRequirement(
                id: -1,
                type: event.type,
                hoursNeeded: 0,
                description: '',
                isActive: false,
              ),
            );

            // Check if user has completed the required hours for this type
            final completedHours =
                _completedHoursMap[normalizeType(event.type)] ?? 0.0;
            hasCompletedRequirements =
                completedHours >= matchingRequirement.hoursNeeded;
          }
        }

        // Check if signup is delayed
        final canSignUp = !hasCompletedRequirements ||
            !event.hasDelay ||
            event.canSignUpForTimeSlot(timeSlot);
        if (!canSignUp) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Signup will be available ${event.delayHours} hours before the event',
              ),
            ),
          );
          return;
        }
        // Atomic signup — see supabase/migrations/.._signup_for_timeslot.sql.
        // Returns 'ok' | 'full' | 'already'.
        final status = await Supabase.instance.client.rpc(
          'signup_for_timeslot',
          params: {
            'p_timeslot_id': timeSlot.id,
            'p_user_id': userId,
          },
        ) as String?;

        if (status == 'ok') {
          await logactivity(
            event.name,
            '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
            NhsFormatUtils.calculateDuration(timeSlot.time, timeSlot.endTime),
            'signup',
            userId,
            societyId: society?.id,
          );
          hapticsProvider.success();
          _fetchEvents();
        } else if (status == 'full') {
          hapticsProvider.error();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This time slot is now full.')),
            );
          }
        } else if (status == 'already') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("You're already signed up for this slot.")),
            );
          }
        }
      }
    } catch (e) {
      hapticsProvider.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing up: $e')),
      );
    }
  }

  /// Adds an event to the device calendar.
  ///
  /// Parameters:
  /// - event: Event - Event to add
  /// - timeSlot: TimeSlot - Specific time slot
  ///
  /// Returns:
  /// - void
  void _addEventToCalendar(Event event, TimeSlot timeSlot) {
    final calendarEventp = add2cal.Event(
      title: event.name,
      description: event.description,
      location: event.location,
      startDate: DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        timeSlot.time.hour,
        timeSlot.time.minute,
      ),
      endDate: DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        timeSlot.endTime.hour,
        timeSlot.endTime.minute,
      ),
      iosParams: const add2cal.IOSParams(
        reminder: Duration(minutes: 10),
      ),
      androidParams: const add2cal.AndroidParams(
        emailInvites: [],
      ),
    );

    add2cal.Add2Calendar.addEvent2Cal(calendarEventp);
  }

  Future<void> _checkPendingSwapRequests() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final swapRequests = await Supabase.instance.client
        .from('swap_requests')
        .select(
            '*, Events!swap_requests_event_id_fkey(*), profiles!swap_requests_requester_id_fkey(*), "Time slots"!swap_requests_timeslot_id_fkey(start_time, end_time)')
        .eq('status', 'pending')
        .eq("target_id", currentUserId);

    if (!mounted) return;
    setState(() {
      _pendingSwapRequests = List<Map<String, dynamic>>.from(swapRequests);
    });
  }

  Future<bool> _isAlreadySignedUp(SwapRequest swapRequest) async {
    final response = await Supabase.instance.client
        .from('Time slots')
        .select('*, Attendees(*)')
        .eq('id', swapRequest.timeSlotId)
        .eq('event_id', swapRequest.eventId)
        .single();

    final attendees = response['Attendees'] as List<dynamic>;
    return attendees.any(
        (attendee) => attendee['user_id'] == swapRequest.currentAttendeeId);
  }

  void _declineSwapRequest(SwapRequest swapRequest) async {
    try {
      await Supabase.instance.client
          .from('swap_requests')
          .update({'status': 'declined'}).eq('id', swapRequest.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Swap request declined')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining swap request: $e')),
      );
    }
  }

  void _acceptSwapRequest(
      SwapRequest swapRequest, Map<String, dynamic> eventData) async {
    final hapticsProvider =
        Provider.of<HapticsProvider>(context, listen: false);
    try {
      await Supabase.instance.client
          .from('swap_requests')
          .update({'status': 'accepted'}).eq('id', swapRequest.id);

      await _swapAttendees(
          swapRequest.currentAttendeeId,
          swapRequest.requesterId,
          swapRequest.eventId,
          swapRequest.timeSlotId,
          eventData,
          swapRequest);
      hapticsProvider.success();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Swap request accepted')),
      );

      // Refresh the UI
      await _fetchEvents();
    } catch (e) {
      hapticsProvider.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting swap request: $e')),
      );
    }
  }

  /// Executes attendance swap between two users.
  /// Updates database and notifications.
  ///
  /// Parameters:
  /// - currentAttendee: Attendee - Current event attendee
  /// - newUser: UserProfile - User to swap with
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _swapAttendees(
      String newAttendeeId,
      String currentAttendeeId,
      int eventId,
      int timeSlotId,
      Map<String, dynamic> eventData,
      SwapRequest swapRequest) async {
    try {
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      // Remove the current attendee
      await Supabase.instance.client
          .from('Attendees')
          .delete()
          .eq('user_id', currentAttendeeId)
          .eq('timeslot_id', timeSlotId);

      // Add the new attendee
      await Supabase.instance.client.from('Attendees').insert({
        'user_id': newAttendeeId,
        'timeslot_id': timeSlotId,
        'is_present': false,
        'forms_completed': false,
      });

      await logactivity(
        eventData['name'],
        '${formatter.format(swapRequest.startTime)} - ${formatter.format(swapRequest.endTime)}',
        NhsFormatUtils.calculateDuration(
            TimeOfDay.fromDateTime(swapRequest.startTime),
            TimeOfDay.fromDateTime(swapRequest.endTime)),
        'swap',
        currentAttendeeId,
        oldUserId: currentAttendeeId,
        newUserId: newAttendeeId,
        societyId: society?.id,
      );
    } catch (e) {
      debugPrint('Error swapping attendees: $e');
      rethrow;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _respondToSwapRequest(SwapRequest request, bool accepted) async {
    try {
      // Update the swap request status
      await Supabase.instance.client.from('swap_requests').update(
          {'status': accepted ? 'accepted' : 'denied'}).eq('id', request.id);

      if (accepted) {
        // Perform the swap
        await _performSwap(request);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Swap request ${accepted ? 'accepted' : 'denied'}')),
      );

      // Refresh the events list
      _fetchEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing swap request: $e')),
      );
    }
  }

  Future<void> _performSwap(SwapRequest request) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Remove the requester from the event
    await Supabase.instance.client
        .from('Attendees')
        .delete()
        .eq('timeslot_id', request.timeSlotId)
        .eq('user_id', request.requesterId);

    // Add the target (current user) to the event
    await Supabase.instance.client.from('Attendees').insert({
      'timeslot_id': request.timeSlotId,
      'user_id': currentUserId,
      'is_present': false,
    });
  }
}