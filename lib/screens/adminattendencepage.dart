import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:intl/intl.dart';
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import '../models/timeslot.dart';
import '../models/collection.dart';
import '../models/event.dart';
import '../models/attendee.dart';
import 'attendencecheckpage.dart';
import '../common/nhsformatutils.dart';
import '../common/iconutils.dart';
import '../common/normalizetype.dart';
import '../providers/hapticsprovider.dart';

final supabase = Supabase.instance.client;

class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  _AdminAttendancePageState createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  List<Event> _events = [];
  List<Collection> _collections = [];
  bool _isLoading = true;
  String _selectedEventType = 'All'; // Added for filtering
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _fetchEvents(),
        _fetchCollections(),
      ]);
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Get available requirement types from current society
  List<String> get _availableEventTypes {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null)
      return ['All', 'Service', 'Tutoring', 'Meeting']; // Default fallback

    // Start with All and Meeting (special case)
    final types = ['All', 'Meeting'];

    // Add all active requirements from the society
    for (final req in society.hourRequirements) {
      if (req.isActive && !types.contains(req.type)) {
        types.add(req.type);
      }
    }

    return types;
  }

  List<Event> get _filteredEvents {
    final events = _selectedEventType == 'All'
        ? List<Event>.from(_events)
        : _events
            .where((e) =>
                normalizeType(e.type) == normalizeType(_selectedEventType))
            .toList();
    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  List<Collection> _getCollectionsWithEvents() {
    final filtered = _filteredEvents;
    return _collections
        .where((c) => filtered.any((e) => e.collectionId == c.id))
        .toList();
  }

  List<Event> _getUncategorizedEvents() =>
      _filteredEvents.where((e) => e.collectionId == null).toList();

  // Build event type filter chips based on society requirements
  List<Widget> _buildEventTypeChips() {
    return _availableEventTypes.map((type) {
      return FilterChip(
        label: Text(type),
        selected: _selectedEventType == type,
        onSelected: (selected) {
          setState(() {
            _selectedEventType = type;
          });
        },
        backgroundColor:
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        title: Text(
          'Attendance',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: Row(
        children: [
          // Optional side panel for wide screens
          if (isWideScreen)
            Container(
              width: 250,
              height: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Padding(
                padding: AppDesign.paddingMedium,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Date selector in sidebar for wide screens
                    _buildDateRangeSelector(isCompact: false),
                    const SizedBox(height: 16),
                    // Vertical chips for wider screens
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      direction: Axis.vertical,
                      children: _buildEventTypeChips(),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),

          // Main content area (takes full width on mobile, remaining space on web)
          Expanded(
            child: Column(
              children: [
                // Today's Events Section
                _buildTodaysEventsHeader(),

                // Show horizontal chips and date selector only on mobile
                if (!isWideScreen) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 12,
                        children: _buildEventTypeChips(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: _buildDateRangeSelector(isCompact: true),
                  ),
                ],

                // Event Count and Loading Indicator
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _filteredEvents.isEmpty
                            ? 'No events found'
                            : '${_filteredEvents.length} ${_filteredEvents.length == 1 ? 'event' : 'events'}${_selectedEventType != 'All' ? ' - $_selectedEventType' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_isLoading)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),

                // Main event list
                Expanded(
                  child: _filteredEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No events found',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              if (_selectedEventType != 'All')
                                Padding(
                                  padding: AppDesign.paddingSmall,
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.filter_alt_off),
                                    label: const Text('Clear filter'),
                                    onPressed: () {
                                      final hapticsProvider =
                                          Provider.of<HapticsProvider>(context,
                                              listen: false);
                                      hapticsProvider.selection();
                                      setState(() {
                                        _selectedEventType = 'All';
                                      });
                                    },
                                  ),
                                ),
                            ],
                          ),
                        )
                      : Builder(builder: (context) {
                          final collections = _getCollectionsWithEvents();
                          final uncategorized = _getUncategorizedEvents();
                          final total = collections.length + uncategorized.length;
                          return ListView.builder(
                            itemCount: total,
                            itemBuilder: (context, index) {
                              if (index < collections.length) {
                                return _buildCollectionCard(collections[index]);
                              }
                              return _buildEventCard(
                                  uncategorized[index - collections.length]);
                            },
                          );
                        }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Now create a date range selector widget
  Widget _buildDateRangeSelector({required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Date Range',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        Row(
          children: [
            // Start date selector
            Expanded(
              child: InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked;
                    });
                    _fetchEvents();
                  }
                },
                child: Container(
                  padding: AppDesign.paddingSmall,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.5),
                    borderRadius: AppDesign.borderMedium,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _startDate == null
                              ? 'Start'
                              : DateFormat('MMM d, y').format(_startDate!),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _startDate == null
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withOpacity(0.7)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_startDate != null)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _startDate = null;
                            });
                            _fetchEvents();
                          },
                          child: Icon(
                            Icons.clear,
                            size: 18,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // End date selector
            Expanded(
              child: InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ??
                        (_startDate != null ? _startDate! : DateTime.now()),
                    firstDate: _startDate ?? DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      _endDate = picked;
                    });
                    _fetchEvents();
                  }
                },
                child: Container(
                  padding: AppDesign.paddingSmall,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.5),
                    borderRadius: AppDesign.borderMedium,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _endDate == null
                              ? 'End'
                              : DateFormat('MMM d, y').format(_endDate!),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _endDate == null
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withOpacity(0.7)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_endDate != null)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _endDate = null;
                            });
                            _fetchEvents();
                          },
                          child: Icon(
                            Icons.clear,
                            size: 18,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Show applied filter info if dates are selected
        if (_startDate != null || _endDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _getDateRangeText(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    _fetchEvents();
                  },
                  child: Text(
                    'Clear filter',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Helper to generate date range description text
  String _getDateRangeText() {
    if (_startDate != null && _endDate != null) {
      return 'Showing events from ${DateFormat('MMM d').format(_startDate!)} to ${DateFormat('MMM d').format(_endDate!)}';
    } else if (_startDate != null) {
      return 'Showing events from ${DateFormat('MMM d').format(_startDate!)} onwards';
    } else if (_endDate != null) {
      return 'Showing events until ${DateFormat('MMM d').format(_endDate!)}';
    }
    return '';
  }

  // Display today's events or upcoming events section
  Widget _buildTodaysEventsHeader() {
    // Filter today's events
    final now = DateTime.now();
    final todaysEvents = _events.where((event) {
      return event.date.year == now.year &&
          event.date.month == now.month &&
          event.date.day == now.day;
    }).toList();

    // If no events today, don't show the section
    if (todaysEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: AppDesign.paddingMedium,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: AppDesign.borderLarge,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  padding: AppDesign.paddingSmall,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_available,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Events",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d').format(now),
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Chip(
                  label: Text(
                    '${todaysEvents.length} ${todaysEvents.length == 1 ? 'event' : 'events'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ],
            ),
          ),

          TodaysEventsSection(
            events: todaysEvents,
            onEventTap: (event, currentTimeSlot) {
              if (event.timeSlots.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceCheckPage(
                      event: event,
                      timeSlot: currentTimeSlot ?? event.timeSlots.first,
                    ),
                  ),
                ).then((_) => _fetchData());
              }
            },
          ),
          // Bottom padding
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Shows a dialog with a copyable list of attendee emails for a time slot,
  /// with the option to expand to every attendee across the whole event, plus
  /// a copy-to-clipboard button.
  Future<void> _showAttendeeEmailsDialog(Event event, TimeSlot timeSlot) async {
    final Set<String> slotUserIds =
        timeSlot.attendees.map((a) => a.userId).toSet();
    final Set<String> eventUserIds = event.timeSlots
        .expand((ts) => ts.attendees)
        .map((a) => a.userId)
        .toSet();

    if (eventUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendees to export.')),
      );
      return;
    }

    // Fetch emails for every attendee that could be shown, in one query.
    final Map<String, String> emailMap = {};
    try {
      final resp = await supabase
          .from('profiles')
          .select('user_id, email')
          .inFilter('user_id', eventUserIds.toList());
      for (final item in resp as List) {
        emailMap[item['user_id']] = (item['email'] as String?) ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching emails: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    bool wholeEvent = false;

    List<String> emailsFor(Set<String> ids) {
      final list = ids
          .map((id) => emailMap[id] ?? '')
          .where((e) => e.isNotEmpty)
          .toList()
        ..sort();
      return list;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final emails = emailsFor(wholeEvent ? eventUserIds : slotUserIds);
            final text = emails.join('\n');
            return AlertDialog(
              title: const Text('Attendee Emails'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${emails.length} ${emails.length == 1 ? 'email' : 'emails'} • '
                      '${wholeEvent ? 'entire event' : 'this time slot'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 240),
                      width: double.maxFinite,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: AppDesign.borderSmall,
                      ),
                      child: emails.isEmpty
                          ? Text(
                              'No emails found.',
                              style: TextStyle(
                                color:
                                    Theme.of(ctx).colorScheme.onSurfaceVariant,
                              ),
                            )
                          : SingleChildScrollView(
                              child: SelectableText(
                                text,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                    ),
                    if (!wholeEvent && event.timeSlots.length > 1) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.group_add, size: 18),
                        label: const Text("Add entire event's attendees"),
                        onPressed: () {
                          Provider.of<HapticsProvider>(ctx, listen: false)
                              .selection();
                          setLocalState(() => wholeEvent = true);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                  onPressed: emails.isEmpty
                      ? null
                      : () {
                          Provider.of<HapticsProvider>(ctx, listen: false)
                              .success();
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Copied ${emails.length} ${emails.length == 1 ? 'email' : 'emails'} to clipboard'),
                            ),
                          );
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCollectionCard(Collection collection) {
    final events = _filteredEvents
        .where((e) => e.collectionId == collection.id)
        .toList();
    if (events.isEmpty) return const SizedBox.shrink();

    final earliest = events.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.borderLarge,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          shape: RoundedRectangleBorder(borderRadius: AppDesign.borderLarge),
          collapsedShape: RoundedRectangleBorder(borderRadius: AppDesign.borderLarge),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.secondary,
              borderRadius: AppDesign.borderSmall,
            ),
            child: Icon(Icons.folder_rounded, color: colorScheme.onSecondary, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      collection.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 12, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Next: ${DateFormat('MMM d, y').format(earliest)}',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.secondary,
                  borderRadius: AppDesign.borderMedium,
                ),
                child: Text(
                  '${events.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondary,
                  ),
                ),
              ),
            ],
          ),
          children: events.map((e) => _buildEventCard(e)).toList(),
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    // Get color for event type
    final Color typeColor = _getColorForEventType(event.type, context);

    // Calculate attendance stats
    int totalAttendees = 0;
    int presentAttendees = 0;

    for (final timeSlot in event.timeSlots) {
      totalAttendees += timeSlot.attendees.length;
      presentAttendees += timeSlot.attendees.where((a) => a.isPresent).length;
    }

    final attendancePercentage =
        totalAttendees > 0 ? (presentAttendees / totalAttendees) * 100 : 0.0;

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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.only(right: 12),
              childrenPadding: EdgeInsets.zero,
              title: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 0, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Event icon with type color
                    CircleAvatar(
                      backgroundColor: typeColor.withOpacity(0.15),
                      radius: 20,
                      child: Icon(
                        getIconForType(event.type, context),
                        color: typeColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Event info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event title
                          Text(
                            event.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Date and type
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${DateFormat('MMM d').format(event.date)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  borderRadius: AppDesign.borderSmall,
                                ),
                                child: Text(
                                  event.type,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Attendance ratio
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.how_to_reg_outlined,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$presentAttendees/$totalAttendees',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${attendancePercentage.round()}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Time slots as children when expanded
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time Slots',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${event.timeSlots.length} ${event.timeSlots.length == 1 ? 'slot' : 'slots'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ...event.timeSlots.map((timeSlot) {
                  final timeSlotAttendees = timeSlot.attendees.length;
                  final timeSlotPresent =
                      timeSlot.attendees.where((a) => a.isPresent).length;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.2),
                        borderRadius: AppDesign.borderSmall,
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        title: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: typeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${NhsFormatUtils.formatTimeOfDay(timeSlot.time, context)} - ${NhsFormatUtils.formatTimeOfDay(timeSlot.endTime, context)}',
                              style: const TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.how_to_reg_outlined,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$timeSlotPresent/$timeSlotAttendees',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.email_outlined, size: 20),
                              color: Theme.of(context).colorScheme.onSurface,
                              tooltip: 'Export emails',
                              onPressed: () {
                                Provider.of<HapticsProvider>(context,
                                        listen: false)
                                    .selection();
                                _showAttendeeEmailsDialog(event, timeSlot);
                              },
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 0),
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                            IconButton(
                              icon: const Icon(Icons.checklist, size: 20),
                              color: Theme.of(context).colorScheme.onSurface,
                              tooltip: 'Track attendance',
                              onPressed: () {
                                final hapticsProvider =
                                    Provider.of<HapticsProvider>(context,
                                        listen: false);
                                hapticsProvider.selection();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AttendanceCheckPage(
                                      event: event,
                                      timeSlot: timeSlot,
                                    ),
                                  ),
                                ).then((_) => _fetchData());
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppDesign.borderSmall,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 0),
                                minimumSize: const Size(0, 28),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
      ),
    );
  }

  // Helper method to get color based on event type
  Color _getColorForEventType(String type, BuildContext context) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('service'))
      return Theme.of(context).colorScheme.primary;
    if (lowerType.contains('tutor'))
      return Theme.of(context).colorScheme.secondary;
    if (lowerType.contains('meeting'))
      return Theme.of(context).colorScheme.tertiary;
    if (lowerType.contains('leader')) return Colors.amber;
    return Theme.of(context).colorScheme.primary;
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Get current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() {
          _events = [];
          _isLoading = false;
        });
        return;
      }

      // 1. Start building query for events in this society
      var query = supabase.from('Events').select().eq('society_id', society.id);

      // 2. Apply date range filter if dates are selected
      if (_startDate != null) {
        query = query.gte('date', _startDate!.toIso8601String());
      }

      if (_endDate != null) {
        // Include the entire end date by setting time to end of day
        final endOfDay = DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        query = query.lte('date', endOfDay.toIso8601String());
      }

      // 3. Order by date
      final eventResponse = await query.order('date');

      // Create events map for quick lookups
      final Map<int, Event> eventsMap = {
        for (var json in eventResponse) json['id']: Event.fromJson(json)
      };

      // 2. Fetch all time slots for these events in a single query
      final timeSlotResponse = await Supabase.instance.client
          .from('Time slots')
          .select()
          .inFilter('event_id', eventsMap.keys.toList());

      // Create time slots map for quick lookups
      final Map<int, TimeSlot> timeSlotsMap = {
        for (var json in timeSlotResponse) json['id']: TimeSlot.fromJson(json)
      };

      // Create a map of event_id to list of time slot ids
      final Map<int, List<int>> eventToTimeSlots = {};
      for (var timeSlot in timeSlotResponse) {
        final eventId = timeSlot['event_id'] as int;
        eventToTimeSlots
            .putIfAbsent(eventId, () => [])
            .add(timeSlot['id'] as int);
      }

      // 3. Fetch all attendees with their profiles in a single query
      final attendeeResponse = await Supabase.instance.client
          .from('Attendees')
          .select('*, profiles!inner(name)')
          .inFilter('timeslot_id', timeSlotsMap.keys.toList());

      // Organize attendees by time slot
      for (var attendeeJson in attendeeResponse) {
        final timeSlotId = attendeeJson['timeslot_id'] as int;
        final attendee = Attendee.fromJson({
          ...attendeeJson,
          'name': attendeeJson['profiles']['name'],
        });

        if (timeSlotsMap.containsKey(timeSlotId)) {
          timeSlotsMap[timeSlotId]!.attendees.add(attendee);
        }
      }

      // Assemble the final event structure
      final List<Event> assembledEvents = [];
      for (var entry in eventToTimeSlots.entries) {
        final eventId = entry.key;
        final timeSlotIds = entry.value;

        if (eventsMap.containsKey(eventId)) {
          final event = eventsMap[eventId]!;
          event.timeSlots = timeSlotIds.map((id) => timeSlotsMap[id]!).toList();
          assembledEvents.add(event);
        }
      }

      if (mounted) {
        setState(() {
          _events = assembledEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: $e')),
        );
      }
    }
  }

  Future<void> _fetchCollections() async {
    try {
      // Get current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() => _collections = []);
        return;
      }

      final collectionsResponse = await Supabase.instance.client
          .from('Collections')
          .select('*')
          .eq('society_id', society.id);

      setState(() {
        _collections = collectionsResponse
            .map<Collection>((json) => Collection.fromJson(json))
            .toList();
      });
    } catch (e) {
      debugPrint('Error fetching collections: $e');
    }
  }

  
}

class TodaysEventsSection extends StatefulWidget {
  final List<Event> events;
  final Function(Event, TimeSlot?) onEventTap;

  const TodaysEventsSection({
    Key? key,
    required this.events,
    required this.onEventTap,
  }) : super(key: key);

  @override
  State<TodaysEventsSection> createState() => _TodaysEventsSectionState();
}

class _TodaysEventsSectionState extends State<TodaysEventsSection> {
  bool _isExpanded = true; // Start expanded by default

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Section header with collapse control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Today\'s Events',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.events.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),

        // Collapsible events list
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: widget.events
                .map((event) => _buildTodaysEventItem(event))
                .toList(),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }

  // Individual event item (original widget)
  Widget _buildTodaysEventItem(Event event) {
    // Calculate attendance info
    int totalAttendees = 0;
    int presentAttendees = 0;

    for (final timeSlot in event.timeSlots) {
      totalAttendees += timeSlot.attendees.length;
      presentAttendees += timeSlot.attendees.where((a) => a.isPresent).length;
    }

    // Calculate attendance percentage
    final attendancePercentage =
        totalAttendees > 0 ? (presentAttendees / totalAttendees) * 100 : 0.0;

    // Determine if any time slots are happening now
    final now = DateTime.now();
    final currentHour = TimeOfDay.fromDateTime(now);

    bool isHappeningNow = false;
    TimeSlot? currentTimeSlot;

    for (final timeSlot in event.timeSlots) {
      final startMinutes = timeSlot.time.hour * 60 + timeSlot.time.minute;
      final endMinutes = timeSlot.endTime.hour * 60 + timeSlot.endTime.minute;
      final currentMinutes = currentHour.hour * 60 + currentHour.minute;

      if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
        isHappeningNow = true;
        currentTimeSlot = timeSlot;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppDesign.borderMedium,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: AppDesign.borderMedium,
        onTap: () {
          widget.onEventTap(event, currentTimeSlot);
        },
        child: Padding(
          padding: AppDesign.paddingSmall,
          child: Row(
            children: [
              // Event icon with type color
              CircleAvatar(
                backgroundColor: _getColorForEventType(event.type, context)
                    .withOpacity(0.15),
                child: Icon(
                  getIconForType(event.type, context),
                  color: _getColorForEventType(event.type, context),
                ),
              ),
              const SizedBox(width: 12),

              // Event info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event title with optional "happening now" badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isHappeningNow)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: AppDesign.borderMedium,
                            ),
                            child: const Text(
                              'NOW',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Event type
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getColorForEventType(event.type, context)
                            .withOpacity(0.1),
                        borderRadius: AppDesign.borderMedium,
                      ),
                      child: Text(
                        event.type,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getColorForEventType(event.type, context),
                        ),
                      ),
                    ),

                    // Time slots
                    if (event.timeSlots.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.timeSlots.length == 1
                            ? NhsFormatUtils.formatTimeSlot(
                                event.timeSlots.first, context)
                            : '${event.timeSlots.length} time slots',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Attendance ratio
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attendance info
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$presentAttendees/$totalAttendees',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: presentAttendees > 0
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress indicator
                  SizedBox(
                    width: 60,
                    height: 8,
                    child: ClipRRect(
                      borderRadius: AppDesign.borderSmall,
                      child: LinearProgressIndicator(
                        value: totalAttendees > 0
                            ? presentAttendees / totalAttendees
                            : 0,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Percentage text
                  Text(
                    '${attendancePercentage.round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorForEventType(String type, BuildContext context) {
        return Theme.of(context).colorScheme.primary;
    
  }
}


