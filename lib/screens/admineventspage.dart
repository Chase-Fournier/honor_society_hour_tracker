import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:intl/intl.dart';
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import '../models/timeslot.dart';
import '../models/hourrequirement.dart';
import '../models/honorsociety.dart';
import '../models/collection.dart';
import '../models/event.dart';
import '../models/attendee.dart';
import '../models/continuousevent.dart';
import '../models/continuouseventstep.dart';
import '../common/normalizetype.dart';
import '../common/iconutils.dart';
import '../providers/hapticsprovider.dart';
import 'continuouseventsubmissionspage.dart';

final supabase = Supabase.instance.client;

class AdminEventsPage extends StatefulWidget {
  final HonorSociety? society;
  const AdminEventsPage({super.key, this.society});

  @override
  _AdminEventsPageState createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  List<Event> _events = [];
  List<Collection> _collections = [];
  Event? _draggedEvent;
  int? _hoveredCollectionIndex;
  bool _isLoading = false;
  String _selectedEventType = 'All';

  // Continuous (ongoing / external) events
  String _listMode = 'Events'; // 'Events' | 'Ongoing'
  List<ContinuousEvent> _continuousEvents = [];
  Map<int, int> _continuousPendingCounts = {}; // event id -> pending submissions
  bool _isLoadingContinuous = false;

  @override
  void initState() {
    super.initState();
    _fetchDataOptimized();
    _fetchContinuousEvents();
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

  // Add this filtered events getter
  List<Event> get _filteredEvents {
    if (_selectedEventType == 'All') return _events;

    return _events
        .where((event) =>
            normalizeType(event.type) == normalizeType(_selectedEventType))
        .toList();
  }

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
    final uncategorizedEvents =
        _filteredEvents.where((event) => event.collectionId == null).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        title: Text(
          'Events',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Events', label: Text('Events')),
                ButtonSegment(value: 'Ongoing', label: Text('Ongoing')),
              ],
              selected: {_listMode},
              onSelectionChanged: (sel) {
                Provider.of<HapticsProvider>(context, listen: false).selection();
                setState(() => _listMode = sel.first);
              },
            ),
          ),
        ),
      ),
      body: _listMode == 'Ongoing'
          ? _buildContinuousEventsBody(isWideScreen)
          : Row(
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
                    // Vertical chips for wider screens
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      direction: Axis.vertical,
                      children: _buildEventTypeChips(),
                    ),
                    const Divider(height: 32),
                    Text(
                      'Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.add,
                          color: Theme.of(context).colorScheme.primary),
                      title: const Text('Add Event'),
                      onTap: () {
                        final hapticsProvider = Provider.of<HapticsProvider>(
                            context,
                            listen: false);
                        hapticsProvider.selection();
                        showAddEventDialog();
                      },
                      dense: true,
                    ),
                    ListTile(
                      leading: Icon(Icons.create_new_folder,
                          color: Theme.of(context).colorScheme.primary),
                      title: const Text('Add Collection'),
                      onTap: () {
                        final hapticsProvider = Provider.of<HapticsProvider>(
                            context,
                            listen: false);
                        hapticsProvider.selection();
                        _showAddCollectionDialog();
                      },
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),

          // Main content area (takes full width on mobile, remaining space on web)
          Expanded(
            child: Column(
              children: [
                // Show horizontal chips only on mobile
                if (!isWideScreen)
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

                // Event Count and Loading Indicator
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isLoading
                            ? 'Loading events...'
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
                        )
                    ],
                  ),
                ),

                // Main event list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _fetchDataOptimized();
                          },
                          child: _filteredEvents.isEmpty && _collections.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.event_busy,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No events found',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall,
                                      ),
                                      if (_selectedEventType != 'All')
                                        Padding(
                                          padding: AppDesign.paddingSmall,
                                          child: TextButton.icon(
                                            icon: const Icon(
                                                Icons.filter_alt_off),
                                            label: const Text('Clear filter'),
                                            onPressed: () {
                                              final hapticsProvider =
                                                  Provider.of<HapticsProvider>(
                                                      context,
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
                              : ListView.builder(
                                  itemCount: _collections.length +
                                      uncategorizedEvents.length,
                                  itemBuilder: (context, index) {
                                    if (index < _collections.length) {
                                      final collection = _collections[index];
                                      return _buildCollectionCard(
                                          collection, index);
                                    } else {
                                      final event = uncategorizedEvents[
                                          index - _collections.length];
                                      return _buildEventCard(event);
                                    }
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Only show FAB on mobile
      floatingActionButton: isWideScreen
          ? null
          : _listMode == 'Ongoing'
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Provider.of<HapticsProvider>(context, listen: false)
                        .selection();
                    showAddContinuousEventDialog();
                  },
                  heroTag: 'addContinuous',
                  icon: const Icon(Icons.add),
                  label: const Text('Ongoing'),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                      onPressed: () {
                        final hapticsProvider =
                            Provider.of<HapticsProvider>(context, listen: false);
                        hapticsProvider.selection();
                        showAddEventDialog();
                      },
                      heroTag: 'addEvent',
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      onPressed: () {
                        final hapticsProvider =
                            Provider.of<HapticsProvider>(context, listen: false);
                        hapticsProvider.selection();
                        _showAddCollectionDialog();
                      },
                      heroTag: 'addCollection',
                      child: const Icon(Icons.create_new_folder),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEventCard(Event event) {
    final bool isNew = event.createdAt
        .isAfter(DateTime.now().subtract(const Duration(days: 7)));
    final bool isMandatory = event.isMandatory;

    // Get color for event type
    final Color typeColor = Theme.of(context).colorScheme.primary;

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
      child: Draggable<Event>(
        data: event,
        feedback: Card(
          elevation: 4.0,
          shape: RoundedRectangleBorder(borderRadius: AppDesign.borderMedium),
          child: Container(
            padding: AppDesign.paddingMedium,
            width: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: AppDesign.borderMedium,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: typeColor.withOpacity(0.15),
                      radius: 16,
                      child: Icon(
                        getIconForType(event.type, context),
                        color: typeColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: AppDesign.borderLarge),
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                borderRadius: AppDesign.borderLarge,
                border: Border.all(
                  color: typeColor.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'Moving ${event.name}...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        onDragStarted: () => _onEventDragStarted(event),
        onDragEnd: (details) {
          if (event.collectionId != null) {
            _onEventDropped(event, null);
          }
        },
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                      const SizedBox(width: 10),

                      // Event title and date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
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

                                // Event badges
                                if (isNew)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary
                                          .withOpacity(0.1),
                                      borderRadius: AppDesign.borderSmall,
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            .withOpacity(0.2),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      'New',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                      ),
                                    ),
                                  ),

                                if (isMandatory)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiary
                                          .withOpacity(0.1),
                                      borderRadius: AppDesign.borderSmall,
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiary
                                            .withOpacity(0.2),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      'Required',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .tertiary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // Date and type on same row
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  "${DateFormat('MMM d, y').format(event.date)}",
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
                                const SizedBox(width: 6),
                                // Indicate number of time slots
                                Text(
                                  '${event.timeSlots.length} ${event.timeSlots.length == 1 ? 'slot' : 'slots'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.8),
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
                // Action buttons as trailing widgets
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        final hapticsProvider = Provider.of<HapticsProvider>(
                            context,
                            listen: false);
                        hapticsProvider.selection();
                        _showEditEventDialog(event);
                      },
                      tooltip: 'Edit Event',
                      padding: AppDesign.paddingSmall,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () {
                        final hapticsProvider = Provider.of<HapticsProvider>(
                            context,
                            listen: false);
                        hapticsProvider.selection();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Event'),
                            content: Text(
                                'Are you sure you want to delete "${event.name}"? This cannot be undone.'),
                            actions: [
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () {
                                  hapticsProvider.selection();
                                  Navigator.of(ctx).pop();
                                },
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.error,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onError,
                                ),
                                child: const Text('Delete'),
                                onPressed: () {
                                  hapticsProvider.selection();
                                  Navigator.of(ctx).pop();
                                  _deleteEvent(event);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                      tooltip: 'Delete Event',
                      padding: AppDesign.paddingSmall,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                // Time slots as children when expanded
                children: [
                  const Divider(height: 1),
                  ...event.timeSlots.map((timeSlot) {
                    return Padding(
                      padding: AppDesign.paddingSmall,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.2),
                          borderRadius: AppDesign.borderSmall,
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
                                '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}',
                                style: const TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(left: 18, top: 2),
                            child: Row(
                              children: [
                                Text(
                                  'Capacity: ${timeSlot.numberOfPeople}',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Attendees: ${timeSlot.attendees.length}',
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
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () {
                              final hapticsProvider =
                                  Provider.of<HapticsProvider>(context,
                                      listen: false);
                              hapticsProvider.selection();
                              _showEditTimeSlotDialog(event, timeSlot);
                            },
                            visualDensity: VisualDensity.standard,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildCollectionCard(Collection collection, int index) {
    final isHovered = _hoveredCollectionIndex == index;
    final eventsInCollection = _filteredEvents
        .where((event) => event.collectionId == collection.id)
        .toList();

    return DragTarget<Event>(
      onWillAccept: (data) => true,
      onAccept: (data) {
        if (data is Event) {
          _onEventDropped(data, collection.id);
        }
      },
      onLeave: (data) {
        setState(() {
          _hoveredCollectionIndex = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final colorScheme = Theme.of(context).colorScheme;
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: AppDesign.borderLarge,
            side: BorderSide(
              color: isHovered
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withOpacity(0.6),
              width: isHovered ? 2 : 1,
            ),
          ),
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isHovered
              ? colorScheme.primaryContainer.withOpacity(0.6)
              : colorScheme.secondaryContainer.withOpacity(0.4),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.secondary,
                  borderRadius: AppDesign.borderSmall,
                ),
                child: Icon(
                  Icons.folder_rounded,
                  color: colorScheme.onSecondary,
                  size: 20,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      collection.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  // Show count of events in this collection
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: eventsInCollection.isEmpty
                          ? colorScheme.surfaceVariant
                          : colorScheme.secondary,
                      borderRadius: AppDesign.borderMedium,
                    ),
                    child: Text(
                      eventsInCollection.length.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: eventsInCollection.isEmpty
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    onPressed: () {
                      final hapticsProvider =
                          Provider.of<HapticsProvider>(context, listen: false);
                      hapticsProvider.selection();
                      _showDeleteCollectionDialog(collection);
                    },
                    tooltip: 'Delete Collection',
                  ),
                  Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant),
                ],
              ),
              children: eventsInCollection.isEmpty
                  ? [
                      Padding(
                        padding: AppDesign.paddingMedium,
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No events in this collection',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Drag and drop events here',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]
                  : eventsInCollection
                      .map((event) => _buildEventCard(event))
                      .toList(),
            ),
          ),
        );
      },
    );
  }

  void showAddEventDialog() {
    final _formKey = GlobalKey<FormState>();
    String _eventName = '';
    String _eventDescription = '';
    String _location = '';
    DateTime _eventDate = DateTime.now();
    List<TimeSlot> _timeSlots = [];
    bool _isMandatory = false;
    String? _selectedEventType;
    int? _selectedCollectionId;
    bool _requiresForms = false;
    String _formLink = '';
    int swap_request_deadline_hours = 24;
    bool _hasDelay = false;
    int _delayHours = 0;
    late int _societyId =
        widget.society?.id ?? 1; // Default to society_id 1 if none selected

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Add Event'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Society Selection (if user is member of multiple societies)
                      FutureBuilder<List<HonorSociety>>(
                        future: _fetchUserSocieties(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          }

                          final societies = snapshot.data ?? [];

                          // Only show society dropdown if user is in multiple societies
                          if (societies.length > 1) {
                            return DropdownButtonFormField<int>(
                              value: _societyId,
                              items: societies
                                  .map((society) => DropdownMenuItem(
                                        value: society.id,
                                        child: Text(society.name),
                                      ))
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _societyId = value!),
                              decoration: const InputDecoration(
                                labelText: 'Society',
                                border: OutlineInputBorder(),
                                hintText: 'Select society for this event',
                              ),
                            );
                          }

                          // If only one society, show it as text
                          if (societies.isNotEmpty) {
                            _societyId = societies.first.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                children: [
                                  const Text('Society: ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(societies.first.name),
                                ],
                              ),
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 16),

                      // Event details
                      TextFormField(
                        decoration:
                            const InputDecoration(labelText: 'Event Name'),
                        validator: (value) => value!.isEmpty
                            ? 'Please enter an event name'
                            : null,
                        onSaved: (value) => _eventName = value!,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(
                            labelText: 'Event Description'),
                        validator: (value) => value!.isEmpty
                            ? 'Please enter a description'
                            : null,
                        onSaved: (value) => _eventDescription = value!,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Location (optional)',
                        ),
                        onSaved: (value) => _location = value ?? '',
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      ElevatedButton(
                        child: Text(_eventDate == null
                            ? 'Select Date'
                            : '${_eventDate.toString().substring(0, 10)}'),
                        onPressed: () async {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _eventDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _eventDate = picked);
                          }
                        },
                      ),
                      FutureBuilder<List<HourRequirement>>(
                          future: _fetchSocietyHourRequirements(_societyId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }

                            final requirements = snapshot.data ?? [];
                            final activeTypes = requirements
                                .where((req) => req.isActive)
                                .map((req) => req.type)
                                .toList();

                            // Add Meeting to the types if not already present
                            if (!activeTypes.contains('Meeting')) {
                              activeTypes.add('Meeting');
                            }

                            return DropdownButtonFormField<String>(
                              value: _selectedEventType,
                              items: activeTypes
                                  .map((type) => DropdownMenuItem(
                                      value: type, child: Text(type)))
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedEventType = value),
                              decoration: const InputDecoration(
                                  labelText: 'Event Type'),
                              validator: (value) => value == null
                                  ? 'Please select an event type'
                                  : null,
                            );
                          }),

                      // Add remaining fields from the original implementation
                      DropdownButtonFormField<int>(
                        value: _selectedCollectionId,
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('No Collection')),
                          ..._collections.map((collection) => DropdownMenuItem(
                                value: collection.id,
                                child: Text(collection.name),
                              )),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedCollectionId = value),
                        decoration:
                            const InputDecoration(labelText: 'Collection'),
                      ),
                      TextFormField(
                        initialValue: swap_request_deadline_hours.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Cancel Deadline (hours before event)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the deadline';
                          }
                          final hours = int.tryParse(value);
                          if (hours == null || hours < 0) {
                            return 'Please enter a valid number of hours';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          swap_request_deadline_hours = int.parse(value!);
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Mandatory'),
                        value: _isMandatory,
                        onChanged: (bool? value) {
                          setState(() => _isMandatory = value!);
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Requires Forms'),
                        value: _requiresForms,
                        onChanged: (bool? value) {
                          setState(() => _requiresForms = value!);
                        },
                      ),
                      if (_requiresForms)
                        TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'Form Link'),
                          validator: (value) => value!.isEmpty
                              ? 'Please enter a form link'
                              : null,
                          onSaved: (value) => _formLink = value!,
                        ),
                      CheckboxListTile(
                        title: const Text('Signup Delay'),
                        value: _hasDelay,
                        onChanged: (bool? value) {
                          setState(() => _hasDelay = value!);
                        },
                      ),
                      if (_hasDelay)
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Delay Hours Before Event',
                            helperText: 'Hours before event to allow signup',
                          ),
                          keyboardType: TextInputType.number,
                          initialValue: _delayHours.toString(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter delay hours';
                            }
                            final hours = int.tryParse(value);
                            if (hours == null || hours < 0) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _delayHours = int.parse(value!);
                          },
                        ),
                      SizedBox(
                        height: 15,
                      ),
                      ElevatedButton(
                        child: const Text('Add Time Slot'),
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          _showAddTimeSlotDialog(setState, _timeSlots);
                        },
                      ),
                      ..._timeSlots.map((timeSlot) => ListTile(
                            title: Text(
                                '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}'),
                            subtitle:
                                Text('Capacity: ${timeSlot.numberOfPeople}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                final hapticsProvider =
                                    Provider.of<HapticsProvider>(context,
                                        listen: false);
                                hapticsProvider.selection();
                                setState(() => _timeSlots.remove(timeSlot));
                              },
                            ),
                          )),
                    ],
                  ),
                ),
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
                ElevatedButton(
                  child: const Text('Add Event'),
                  onPressed: () {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      _addEvent(
                        _eventName,
                        _eventDescription,
                        _location,
                        _eventDate,
                        _selectedEventType!,
                        _isMandatory,
                        _selectedCollectionId,
                        _timeSlots,
                        _requiresForms,
                        _formLink,
                        Duration(hours: swap_request_deadline_hours),
                        _hasDelay,
                        _delayHours,
                        _societyId,
                      );
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

// Add this helper method to fetch user societies
  Future<List<HonorSociety>> _fetchUserSocieties() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final societies =
          await supabase.from('user_society_memberships').select('''
          honor_societies!inner(
            id,
            name,
            description,
            image_url,
            meeting_requirement,
            created_at
          )
        ''').eq('user_id', userId);

      return societies.map<HonorSociety>((membership) {
        final societyData = membership['honor_societies'];

        return HonorSociety(
          id: societyData['id'],
          name: societyData['name'],
          description: societyData['description'],
          imageUrl: societyData['image_url'],
          hourRequirements: [], // We'll fetch these separately if needed
          meetingRequirement: societyData['meeting_requirement'],
          createdAt: DateTime.parse(societyData['created_at']),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching user societies: $e');
      return [];
    }
  }

// Add this helper method to fetch society hour requirements
  Future<List<HourRequirement>> _fetchSocietyHourRequirements(
      int societyId) async {
    try {
      final response = await supabase
          .from('hour_requirements')
          .select()
          .eq('society_id', societyId);

      return response
          .map<HourRequirement>((json) => HourRequirement.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching society hour requirements: $e');
      return [];
    }
  }

  Future<void> _fetchDataOptimized() async {
    setState(() => _isLoading = true);

    try {
      // Get current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() {
          _events = [];
          _collections = [];
          _isLoading = false;
        });
        return;
      }

      // Execute both queries in parallel using Future.wait
      final [eventsResponse, collectionsResponse] = await Future.wait([
        // Optimized events query with nested selects
        supabase.from('Events').select('''
              id,
              name,
              description,
              date,
              type,
              isMandatory,
              created_at,
              collection_id,
              requires_forms,
              form_link,
              swap_request_deadline_hours,
              has_delay,
              delay_hours,
              society_id,
              "Time slots"(
                id,
                start_time,
                end_time,
                number_of_people,
                notes,
                created_at,
                event_id,
                Attendees!left(
                  id,
                  timeslot_id,
                  user_id,
                  is_present,
                  forms_completed,
                  profiles!inner(
                    name
                  )
                )
              )
            ''').eq('society_id', society.id).order('date'),

        // Collections query
        supabase.from('Collections').select('*').eq('society_id', society.id)
      ]);

      // Process events with nested data
      final List<Event> events = eventsResponse.map<Event>((eventData) {
        // Process time slots with attendees
        final timeSlots =
            (eventData['Time slots'] as List).map<TimeSlot>((timeSlotData) {
          // Process attendees
          final attendees = (timeSlotData['Attendees'] as List? ?? [])
              .map<Attendee>((attendeeData) {
                return Attendee(
                  id: attendeeData['id'],
                  timeSlotId: attendeeData['timeslot_id'],
                  userId: attendeeData['user_id'],
                  name: attendeeData['profiles']['name'],
                  isPresent: attendeeData['is_present'] ?? false,
                  formsCompleted: attendeeData['forms_completed'] ?? false,
                );
              })
              .where((attendee) => attendee != null)
              .cast<Attendee>()
              .toList();

          // Create time slot with attendees
          return TimeSlot.fromJson({
            ...timeSlotData,
            'attendees': attendees,
          })
            ..attendees = attendees;
        }).toList();

        // Create event with time slots
        return Event.fromJson(eventData)..timeSlots = timeSlots;
      }).toList();

      // Process collections
      final collections = collectionsResponse
          .map<Collection>((json) => Collection.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _events = events;
          _collections = collections;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in optimized fetch: $e');
    }
  }

// Also update the _fetchCollections method to filter by society if specified
  Future<void> _fetchCollections() async {
    try {
      var query = Supabase.instance.client.from('Collections').select('*');

      // If we have a society specified, filter by it
      if (widget.society != null) {
        query = query.eq('society_id', widget.society!.id);
      }

      final response = await query;

      final List<dynamic> data = response;
      if (mounted) {
        setState(() {
          _collections = data.map((json) => Collection.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching collections: $e');
    }
  }

  void _showDeleteCollectionDialog(Collection collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Text(
          'Are you sure you want to delete "${collection.name}"? Events in this collection will be uncategorized but not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final hapticsProvider =
                  Provider.of<HapticsProvider>(context, listen: false);
              hapticsProvider.selection();
              _deleteCollection(collection);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCollection(Collection collection) async {
    try {
      // First update all events in this collection to remove the collection_id
      await supabase
          .from('Events')
          .update({'collection_id': null}).eq('collection_id', collection.id);

      // Then delete the collection
      await supabase.from('Collections').delete().eq('id', collection.id);

      // Update local state
      setState(() {
        _collections.removeWhere((c) => c.id == collection.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection deleted successfully')),
      );

      // Refresh events to update their display
      _fetchDataOptimized();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting collection: $e')),
      );
    }
  }

  void _showCollectionEvents(Collection collection) {
    showDialog(
      context: context,
      builder: (context) {
        final collectionEvents = _events
            .where((event) => event.collectionId == collection.id)
            .toList();

        return AlertDialog(
          title: Text(collection.name),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: collectionEvents.length,
              itemBuilder: (context, index) {
                final event = collectionEvents[index];
                return ListTile(
                  title: Text(event.name),
                  subtitle: Text(
                    '${event.date.month}/${event.date.day}/${event.date.year}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      final hapticsProvider =
                          Provider.of<HapticsProvider>(context, listen: false);
                      hapticsProvider.selection();
                      _removeEventFromCollection(event, collection);
                    },
                  ),
                );
              },
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

  void _removeEventFromCollection(Event event, Collection collection) async {
    await Supabase.instance.client.from('Events').update({
      'collection_id': null,
    }).eq('id', event.id);
    if (mounted) {
      setState(() {
        final index = _events.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          final updatedEvent = Event(
            id: event.id,
            name: event.name,
            description: event.description,
            date: event.date,
            type: event.type,
            collectionId: null,
            createdAt: event.createdAt,
          );
          _events[index] = updatedEvent;
        }
      });
    }

    Navigator.of(context).pop();
  }

  /// Creates a card widget displaying event details.
  /// Includes event information, time slots, and action buttons.
  ///
  /// Parameters:
  /// - event: Event - Event to display
  ///
  /// Returns:
  /// - Widget
  void _onEventDragStarted(Event event) {
    setState(() {
      _draggedEvent = event;
    });
  }

  /// Handles drag-and-drop operations for events between collections.
  /// Updates database and UI state.
  ///
  /// Parameters:
  /// - event: Event - Event being moved
  /// - collectionId: int? - Target collection ID (null for uncategorized)
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _onEventDropped(Event event, int? collectionId) async {
    try {
      // Update the event in the database
      await Supabase.instance.client
          .from('Events')
          .update({'collection_id': collectionId}).eq('id', event.id);

      setState(() {
        final index = _events.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          // Create a new Event object with the updated collectionId
          _events[index] = Event(
            id: event.id,
            name: event.name,
            description: event.description,
            date: event.date,
            type: event.type,
            timeSlots: event.timeSlots,
            isMandatory: event.isMandatory,
            createdAt: event.createdAt,
            collectionId: collectionId,
          );
        }
      });

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(collectionId != null
                ? 'Event moved to collection'
                : 'Event removed from collection')),
      );
    } catch (e) {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating event: $e')),
      );
    }
  }

  /// Displays dialog for adding new time slots to an event.
  /// Handles time selection and capacity input.
  ///
  /// Parameters:
  /// - parentSetState: StateSetter - Parent widget's setState function
  /// - timeSlots: List<TimeSlot> - Current time slots list
  ///
  /// Returns:
  /// - void
  void _showAddTimeSlotDialog(
      StateSetter parentSetState, List<TimeSlot> timeSlots) {
    final _formKey = GlobalKey<FormState>();
    TimeOfDay _startTime = TimeOfDay.now();
    TimeOfDay _endTime = TimeOfDay.now();
    int _capacity = 1;
    String _notes = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Add Time Slot'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      child: Text('Start Time: ${_startTime.format(context)}'),
                      onPressed: () async {
                        final hapticsProvider = Provider.of<HapticsProvider>(
                            context,
                            listen: false);
                        hapticsProvider.selection();
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (picked != null) {
                          setState(() => _startTime = picked);
                        }
                      },
                    ),
                    SizedBox(height: 14),
                    ElevatedButton(
                      child: Text('End Time: ${_endTime.format(context)}'),
                      onPressed: () async {
                        final hapticsProvider = Provider.of<HapticsProvider>(
                            context,
                            listen: false);
                        hapticsProvider.selection();
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (picked != null) {
                          setState(() => _endTime = picked);
                        }
                      },
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Capacity'),
                      keyboardType: const TextInputType.numberWithOptions(),
                      validator: (value) => int.tryParse(value!) == null
                          ? 'Please enter a valid number'
                          : null,
                      onSaved: (value) => _capacity = int.parse(value!),
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Notes'),
                      onSaved: (value) => _notes = value!,
                    ),
                  ],
                ),
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
                ElevatedButton(
                  child: const Text('Add Time Slot'),
                  onPressed: () {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      parentSetState(() {
                        timeSlots.add(TimeSlot(
                          id: DateTime.now()
                              .millisecondsSinceEpoch, // Temporary ID
                          time: _startTime,
                          endTime: _endTime,
                          numberOfPeople: _capacity,
                          notes: _notes,
                          eventId:
                              0, // This will be set when the event is created
                          createdAt: DateTime.now(),
                          attendees: [],
                        ));
                      });
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // In AdminEventsPage class - replace the _showEditEventDialog method

  void _showEditEventDialog(Event event) {
    final _formKey = GlobalKey<FormState>();
    String _eventName = event.name;
    String _eventDescription = event.description;
    String _location = event.location ?? '';
    DateTime _eventDate = event.date;
    List<TimeSlot> _timeSlots = List.from(event.timeSlots);
    bool _isMandatory = event.isMandatory;
    String? _selectedEventType = event.type;
    int? _selectedCollectionId = event.collectionId;
    bool _requiresForms = event.requiresForms;
    String _formLink = event.formLink ?? '';
    int swapRequestDeadline = event.swapRequestDeadline.inHours;
    bool _hasDelay = event.hasDelay;
    int _delayHours = event.delayHours;

    // Get available event types from society
    List<String> availableTypes = _getAvailableEventTypes();

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: const Text('Edit Event'),
                content: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          initialValue: _eventName,
                          decoration:
                              const InputDecoration(labelText: 'Event Name'),
                          validator: (value) => value!.isEmpty
                              ? 'Please enter an event name'
                              : null,
                          onSaved: (value) => _eventName = value!,
                        ),
                        TextFormField(
                          initialValue: _eventDescription,
                          decoration: const InputDecoration(
                              labelText: 'Event Description'),
                          validator: (value) => value!.isEmpty
                              ? 'Please enter a description'
                              : null,
                          onSaved: (value) => _eventDescription = value!,
                        ),
                        TextFormField(
                          initialValue: _location,
                          decoration: const InputDecoration(
                            labelText: 'Location (optional)',
                          ),
                          onSaved: (value) => _location = value ?? '',
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        ElevatedButton(
                          child: Text(
                              'Date: ${_eventDate.toString().substring(0, 10)}'),
                          onPressed: () async {
                            final hapticsProvider =
                                Provider.of<HapticsProvider>(context,
                                    listen: false);
                            hapticsProvider.selection();
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _eventDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _eventDate = picked);
                            }
                          },
                        ),
                        DropdownButtonFormField<String>(
                          value: availableTypes.contains(_selectedEventType)
                              ? _selectedEventType
                              : availableTypes.first,
                          items: availableTypes
                              .map((type) => DropdownMenuItem(
                                  value: type, child: Text(type)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedEventType = value),
                          decoration:
                              const InputDecoration(labelText: 'Event Type'),
                          validator: (value) => value == null
                              ? 'Please select an event type'
                              : null,
                        ),
                        TextFormField(
                          initialValue: swapRequestDeadline.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Cancel Deadline (hours before Event)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the deadline';
                            }
                            final hours = int.tryParse(value);
                            if (hours == null || hours < 0) {
                              return 'Please enter a valid number of hours';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            swapRequestDeadline = int.parse(value!);
                          },
                        ),
                        DropdownButtonFormField<int>(
                          value: _selectedCollectionId,
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('No Collection')),
                            ..._collections
                                .map((collection) => DropdownMenuItem(
                                      value: collection.id,
                                      child: Text(collection.name),
                                    )),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedCollectionId = value),
                          decoration:
                              const InputDecoration(labelText: 'Collection'),
                        ),
                        CheckboxListTile(
                          title: const Text('Mandatory'),
                          value: _isMandatory,
                          onChanged: (bool? value) {
                            setState(() => _isMandatory = value!);
                          },
                        ),
                        CheckboxListTile(
                          title: const Text('Requires Forms'),
                          value: _requiresForms,
                          onChanged: (bool? value) {
                            setState(() => _requiresForms = value!);
                          },
                        ),
                        if (_requiresForms)
                          TextFormField(
                            initialValue: _formLink,
                            decoration:
                                const InputDecoration(labelText: 'Form Link'),
                            validator: (value) => value!.isEmpty
                                ? 'Please enter a form link'
                                : null,
                            onSaved: (value) => _formLink = value!,
                          ),
                        CheckboxListTile(
                          title: const Text('Signup Delay'),
                          value: _hasDelay,
                          onChanged: (bool? value) {
                            setState(() => _hasDelay = value!);
                          },
                        ),
                        if (_hasDelay)
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Delay Hours Before Event',
                              helperText: 'Hours before event to allow signup',
                            ),
                            keyboardType: TextInputType.number,
                            initialValue: _delayHours.toString(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter delay hours';
                              }
                              final hours = int.tryParse(value);
                              if (hours == null || hours < 0) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              _delayHours = int.parse(value!);
                            },
                          ),
                        ElevatedButton(
                          child: const Text('Add Time Slot'),
                          onPressed: () {
                            final hapticsProvider =
                                Provider.of<HapticsProvider>(context,
                                    listen: false);
                            hapticsProvider.selection();
                            _showAddTimeSlotDialog(setState, _timeSlots);
                          },
                        ),
                        ..._timeSlots.map((timeSlot) => ListTile(
                              title: Text(
                                  '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}'),
                              subtitle:
                                  Text('Capacity: ${timeSlot.numberOfPeople}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  final hapticsProvider =
                                      Provider.of<HapticsProvider>(context,
                                          listen: false);
                                  hapticsProvider.selection();
                                  setState(() => _timeSlots.remove(timeSlot));
                                },
                              ),
                            )),
                      ],
                    ),
                  ),
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
                  ElevatedButton(
                    child: const Text('Update'),
                    onPressed: () {
                      final hapticsProvider =
                          Provider.of<HapticsProvider>(context, listen: false);
                      hapticsProvider.selection();
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        final society =
                            Provider.of<SocietyProvider>(context, listen: false)
                                .currentSociety;
                        if (society == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('No society selected')),
                          );
                          return;
                        }
                        _updateEvent(
                            event.id,
                            _eventName,
                            _eventDescription,
                            _location,
                            _eventDate,
                            _selectedEventType!,
                            _isMandatory,
                            _selectedCollectionId,
                            _timeSlots,
                            _requiresForms,
                            _formLink,
                            Duration(hours: swapRequestDeadline),
                            _hasDelay,
                            _delayHours,
                            society.id);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              );
            },
          );
        });
  }

// In AdminEventsPage class - add this helper method for getting available event types
  List<String> _getAvailableEventTypes() {
    // Get the current society
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null) {
      // Default fallback types if no society is available
      return ['Service', 'Tutoring', 'Meeting'];
    }

    // Always include Meeting as a type
    final types = ['Meeting'];

    // Add all active requirement types
    for (final req in society.hourRequirements) {
      if (req.isActive && !types.contains(req.type)) {
        types.add(req.type);
      }
    }

    // If somehow we still don't have any types, add default ones
    if (types.isEmpty) {
      types.addAll(['Service', 'Tutoring', 'Meeting']);
    }

    return types;
  }

// In AdminEventsPage class - update the showAddEventDialog method

// Update the _addEvent method to include societyId
  Future<void> _addEvent(
    String name,
    String description,
    String location,
    DateTime date,
    String type,
    bool isMandatory,
    int? collectionId,
    List<TimeSlot> timeSlots,
    bool requiresForms,
    String formLink,
    Duration swapRequestDeadline,
    bool hasDelay,
    int delayHours,
    int societyId,
  ) async {
    try {
      // Insert the event
      final eventResponse = await Supabase.instance.client
          .from('Events')
          .insert({
            'name': name,
            'description': description,
            'location': location.isEmpty ? null : location,
            'date': date.toIso8601String(),
            'type': type,
            'isMandatory': isMandatory,
            'collection_id': collectionId,
            'created_at': DateTime.now().toIso8601String(),
            'requires_forms': requiresForms,
            'form_link': requiresForms ? formLink : null,
            'swap_request_deadline_hours': swapRequestDeadline.inHours,
            'has_delay': hasDelay,
            'delay_hours': delayHours,
            'society_id': societyId,
          })
          .select()
          .single();

      final newEventId = eventResponse['id'];

      // Bulk-insert every time slot in one round-trip.
      final nowIso = DateTime.now().toIso8601String();
      final timeSlotRows = timeSlots
          .map((ts) => {
                'event_id': newEventId,
                'start_time': DateTime(DateTime.now().year, date.month,
                        date.day, ts.time.hour, ts.time.minute)
                    .toIso8601String(),
                'end_time': DateTime(DateTime.now().year, date.month, date.day,
                        ts.endTime.hour, ts.endTime.minute)
                    .toIso8601String(),
                'number_of_people': ts.numberOfPeople,
                'notes': ts.notes,
                'created_at': nowIso,
              })
          .toList();

      final List<int> newTimeSlotIds = [];
      if (timeSlotRows.isNotEmpty) {
        final inserted = await Supabase.instance.client
            .from('Time slots')
            .insert(timeSlotRows)
            .select('id');
        for (final row in inserted as List) {
          newTimeSlotIds.add(row['id'] as int);
        }
      }

      // If the event is mandatory, attach every member of the society as an
      // attendee for every new time slot — one batched insert instead of
      // (slots × members) round-trips.
      if ((isMandatory || type == "Meeting") && newTimeSlotIds.isNotEmpty) {
        final usersResponse = await Supabase.instance.client
            .from('user_society_memberships')
            .select('user_id')
            .eq('society_id', societyId);

        final attendeeRows = <Map<String, dynamic>>[];
        for (final slotId in newTimeSlotIds) {
          for (final user in usersResponse as List) {
            attendeeRows.add({
              'timeslot_id': slotId,
              'user_id': user['user_id'],
              'is_present': false,
            });
          }
        }
        if (attendeeRows.isNotEmpty) {
          await Supabase.instance.client
              .from('Attendees')
              .insert(attendeeRows);
        }
      }

      // Refresh the events list
      await _fetchDataOptimized();

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event added successfully')),
      );
    } catch (e) {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding event: $e')),
      );
    }
  }

  void _showAddCollectionDialog() async {
    String collectionName = '';

    final result = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Collection Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the collection name';
                  }
                  return null;
                },
                onChanged: (value) {
                  collectionName = value;
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
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                if (collectionName.isNotEmpty) {
                  _addCollection(collectionName);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Creates a new collection in the database.
  ///
  /// Parameters:
  /// - name: String - Name of the new collection
  ///
  /// Returns:
  /// - Future<void>
  ///
  /// Throws:
  /// - DatabaseException if collection creation fails
  Future<void> _addCollection(String name) async {
    final response = await Supabase.instance.client.from('Collections').insert({
      'name': name,
      'event_ids': [],
      'society_id': Provider.of<SocietyProvider>(context, listen: false)
          .currentSociety!
          .id
    });

    if (response != null) {
      final newCollection = Collection.fromJson(response[0]);
      setState(() {
        _collections.add(newCollection);
      });
    } else {
      // Handle error
      debugPrint('Failed to add collection');
    }
  }

  /// Updates an existing event's details and time slots.
  /// Handles changes in mandatory status and form requirements.
  ///
  /// Parameters:
  /// - eventId: int - ID of event to update
  /// - name: String - Updated event name
  /// - description: String - Updated description
  /// - date: DateTime - Updated date
  /// - type: String - Updated event type
  /// - isMandatory: bool - Updated mandatory status
  /// - collectionId: int? - Updated collection association
  /// - timeSlots: List<TimeSlot> - Updated time slots
  /// - requiresForms: bool - Updated forms requirement
  /// - formLink: String - Updated form link
  /// - swapRequestDeadline: Duration - Updated swap deadline
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _updateEvent(
    int eventId,
    String name,
    String description,
    String location,
    DateTime date,
    String type,
    bool isMandatory,
    int? collectionId,
    List<TimeSlot> timeSlots,
    bool requiresForms,
    String formLink,
    Duration swapRequestDeadline,
    bool hasDelay,
    int delayHours,
    int societyId,
  ) async {
    try {
      // Update the event
      await Supabase.instance.client.from('Events').update({
        'name': name,
        'description': description,
        'location': location.isEmpty ? null : location,
        'date': date.toIso8601String(),
        'type': type,
        'isMandatory': isMandatory,
        'collection_id': collectionId,
        'requires_forms': requiresForms,
        'form_link': requiresForms ? formLink : null,
        'swap_request_deadline_hours': swapRequestDeadline.inHours,
        'has_delay': hasDelay,
        'delay_hours': delayHours,
      }).eq('id', eventId);

      // Fetch existing time slots once.
      final existingTimeSlotsResponse = await Supabase.instance.client
          .from('Time slots')
          .select()
          .eq('event_id', eventId);

      final existingTimeSlots = (existingTimeSlotsResponse as List)
          .map((slot) => TimeSlot.fromJson(slot))
          .toList();

      final Set<int> incomingIds =
          timeSlots.map((s) => s.id).whereType<int>().toSet();

      // Categorize incoming slots into updates vs. inserts.
      final List<TimeSlot> toUpdate = [];
      final List<TimeSlot> toInsert = [];
      for (final ts in timeSlots) {
        if (ts.id != null && existingTimeSlots.any((e) => e.id == ts.id)) {
          toUpdate.add(ts);
        } else {
          toInsert.add(ts);
        }
      }

      final nowIso = DateTime.now().toIso8601String();

      // Run all existing-slot updates in parallel (no true bulk update for
      // per-row payloads in PostgREST, but parallelism turns N RTTs into 1).
      await Future.wait(toUpdate.map((ts) {
        return Supabase.instance.client.from('Time slots').update({
          'start_time': DateTime(DateTime.now().year, date.month, date.day,
                  ts.time.hour, ts.time.minute)
              .toIso8601String(),
          'end_time': DateTime(DateTime.now().year, date.month, date.day,
                  ts.endTime.hour, ts.endTime.minute)
              .toIso8601String(),
          'number_of_people': ts.numberOfPeople,
          'notes': ts.notes,
        }).eq('id', ts.id!);
      }));

      // Bulk-insert any brand-new slots.
      final List<int> insertedSlotIds = [];
      if (toInsert.isNotEmpty) {
        final insertRows = toInsert
            .map((ts) => {
                  'event_id': eventId,
                  'start_time': DateTime(DateTime.now().year, date.month,
                          date.day, ts.time.hour, ts.time.minute)
                      .toIso8601String(),
                  'end_time': DateTime(DateTime.now().year, date.month,
                          date.day, ts.endTime.hour, ts.endTime.minute)
                      .toIso8601String(),
                  'number_of_people': ts.numberOfPeople,
                  'notes': ts.notes,
                  'created_at': nowIso,
                })
            .toList();
        final inserted = await Supabase.instance.client
            .from('Time slots')
            .insert(insertRows)
            .select('id');
        for (final row in inserted as List) {
          insertedSlotIds.add(row['id'] as int);
        }
      }

      // Delete every slot that's no longer in the incoming set, plus their
      // attendees, in two batched calls.
      final deletedSlotIds = existingTimeSlots
          .map((e) => e.id)
          .whereType<int>()
          .where((id) => !incomingIds.contains(id))
          .toList();
      if (deletedSlotIds.isNotEmpty) {
        await Supabase.instance.client
            .from('Attendees')
            .delete()
            .inFilter('timeslot_id', deletedSlotIds);
        await Supabase.instance.client
            .from('Time slots')
            .delete()
            .inFilter('id', deletedSlotIds);
      }

      // If the event is mandatory, make sure every member is an attendee on
      // every (still-existing or newly-inserted) time slot — without firing
      // (slots × users) duplicate-check queries.
      if (isMandatory) {
        final List<int> allSlotIds = [
          ...existingTimeSlots
              .map((e) => e.id)
              .whereType<int>()
              .where((id) => incomingIds.contains(id)),
          ...insertedSlotIds,
        ];

        if (allSlotIds.isNotEmpty) {
          // Pull members of THIS society — previously this hit `profiles`
          // with no filter, which silently added attendee rows for users
          // from every other society too.
          final usersResponse = await Supabase.instance.client
              .from('user_society_memberships')
              .select('user_id')
              .eq('society_id', societyId);

          // What attendee rows already exist for these slots?
          final existingAttendeesResp = await Supabase.instance.client
              .from('Attendees')
              .select('timeslot_id, user_id')
              .inFilter('timeslot_id', allSlotIds);

          final Set<String> existingPairs = {
            for (final a in existingAttendeesResp as List)
              '${a['timeslot_id']}|${a['user_id']}'
          };

          final attendeeRows = <Map<String, dynamic>>[];
          for (final slotId in allSlotIds) {
            for (final user in usersResponse as List) {
              final key = '$slotId|${user['user_id']}';
              if (!existingPairs.contains(key)) {
                attendeeRows.add({
                  'timeslot_id': slotId,
                  'user_id': user['user_id'],
                  'is_present': false,
                });
              }
            }
          }
          if (attendeeRows.isNotEmpty) {
            await Supabase.instance.client
                .from('Attendees')
                .insert(attendeeRows);
          }
        }
      }

      // Refresh the events list
      await _fetchDataOptimized();

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated successfully')),
      );
    } catch (e) {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating event: $e')),
      );
    }
  }

  /// Displays dialog for editing existing time slot details.
  ///
  /// Parameters:
  /// - event: Event - Parent event
  /// - timeSlot: TimeSlot - Time slot to edit
  ///
  /// Returns:
  /// - void
  void _showEditTimeSlotDialog(Event event, TimeSlot timeSlot) {
    final _formKey = GlobalKey<FormState>();
    TimeOfDay _startTime = timeSlot.time;
    TimeOfDay _endTime = timeSlot.endTime;
    int _capacity = timeSlot.numberOfPeople;
    String _notes = timeSlot.notes;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Time Slot'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  child: Text('Start Time: ${_startTime.format(context)}'),
                  onPressed: () async {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _startTime,
                    );
                    if (picked != null) {
                      setState(() => _startTime = picked);
                    }
                  },
                ),
                SizedBox(height: 14),
                ElevatedButton(
                  child: Text('End Time: ${_endTime.format(context)}'),
                  onPressed: () async {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _endTime,
                    );
                    if (picked != null) {
                      setState(() => _endTime = picked);
                    }
                  },
                ),
                TextFormField(
                  initialValue: _capacity.toString(),
                  decoration: const InputDecoration(labelText: 'Capacity'),
                  keyboardType: const TextInputType.numberWithOptions(),
                  validator: (value) => int.tryParse(value!) == null
                      ? 'Please enter a valid number'
                      : null,
                  onSaved: (value) => _capacity = int.parse(value!),
                ),
                TextFormField(
                  initialValue: _notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  onSaved: (value) => _notes = value!,
                ),
              ],
            ),
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
            ElevatedButton(
              child: const Text('Update Time Slot'),
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  _updateTimeSlot(
                      event, timeSlot, _startTime, _endTime, _capacity, _notes);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Updates existing time slot information.
  ///
  /// Parameters:
  /// - event: Event - Parent event
  /// - timeSlot: TimeSlot - Time slot to update
  /// - startTime: TimeOfDay - New start time
  /// - endTime: TimeOfDay - New end time
  /// - capacity: int - New capacity
  /// - notes: String - Updated notes
  ///
  /// Returns:
  /// - Future<void>
  Future<void> _updateTimeSlot(
      Event event,
      TimeSlot timeSlot,
      TimeOfDay startTime,
      TimeOfDay endTime,
      int capacity,
      String notes) async {
    try {
      // Update the time slot in the database
      await Supabase.instance.client.from('Time slots').update({
        'start_time': DateTime(DateTime.now().year, event.date.month,
                event.date.day, startTime.hour, startTime.minute)
            .toIso8601String(),
        'end_time': DateTime(DateTime.now().year, event.date.month,
                event.date.day, endTime.hour, endTime.minute)
            .toIso8601String(),
        'number_of_people': capacity,
        'notes': notes,
      }).eq('id', timeSlot.id ?? 0);

      // Update the time slot in the local state
      setState(() {
        final updatedTimeSlot = timeSlot.copyWith(
          time: startTime,
          endTime: endTime,
          numberOfPeople: capacity,
          notes: notes,
        );

        final eventIndex = _events.indexWhere((e) => e.id == event.id);
        if (eventIndex != -1) {
          final timeSlotIndex = _events[eventIndex]
              .timeSlots
              .indexWhere((ts) => ts.id == timeSlot.id);
          if (timeSlotIndex != -1) {
            _events[eventIndex].timeSlots[timeSlotIndex] = updatedTimeSlot;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time slot updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating time slot: $e')),
      );
    }
  }

  /// Creates a new event in the database with specified parameters.
  /// Handles mandatory and meeting events by automatically adding all users as attendees.
  ///
  /// Parameters:
  /// - name: String - Event name
  /// - description: String - Event description
  /// - date: DateTime - Event date
  /// - type: String - Event type (Service/Tutoring/Meeting)
  /// - isMandatory: bool - Whether attendance is required
  /// - collectionId: int? - Optional collection association
  /// - timeSlots: List<TimeSlot> - Available time slots
  /// - requiresForms: bool - Whether forms are required
  /// - formLink: String - Link to required forms
  /// - swapRequestDeadline: Duration - Deadline for swap requests
  ///
  /// Returns:
  /// - Future<void>

  /// Registers a user for a specific time slot in an event.
  /// Checks capacity and existing registration.
  ///
  /// Parameters:
  /// - event: Event - Target event
  /// - timeSlot: TimeSlot - Selected time slot
  ///
  /// Returns:
  /// - Future<void>
  void _deleteEvent(Event event) async {
    setState(() {
      _events.remove(event);
    });
    await Supabase.instance.client.from('Events').delete().eq('id', event.id);
  }

  // =========================================================================
  // Continuous (ongoing / external) events
  // =========================================================================

  Future<void> _fetchContinuousEvents() async {
    setState(() => _isLoadingContinuous = true);
    try {
      final societyId =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety?.id;
      if (societyId == null) {
        setState(() {
          _continuousEvents = [];
          _continuousPendingCounts = {};
          _isLoadingContinuous = false;
        });
        return;
      }

      final eventRows = await supabase
          .from('continuous_events')
          .select()
          .eq('society_id', societyId)
          .order('created_at', ascending: false);

      final parsed = (eventRows as List)
          .map((e) => ContinuousEvent.fromJson(e as Map<String, dynamic>))
          .toList();

      // Fetch pending counts in one batch.
      Map<int, int> counts = {};
      if (parsed.isNotEmpty) {
        final pendingRows = await supabase
            .from('continuous_event_submissions')
            .select('continuous_event_id')
            .eq('society_id', societyId)
            .eq('status', 'pending');

        for (final row in (pendingRows as List)) {
          final id = (row['continuous_event_id'] as num).toInt();
          counts[id] = (counts[id] ?? 0) + 1;
        }
      }

      setState(() {
        _continuousEvents = parsed;
        _continuousPendingCounts = counts;
        _isLoadingContinuous = false;
      });
    } catch (e) {
      setState(() => _isLoadingContinuous = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load ongoing events: $e')),
        );
      }
    }
  }

  Widget _buildContinuousEventsBody(bool isWideScreen) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isLoadingContinuous
                    ? 'Loading ongoing events...'
                    : '${_continuousEvents.length} ongoing '
                        '${_continuousEvents.length == 1 ? 'opportunity' : 'opportunities'}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (isWideScreen)
                ElevatedButton.icon(
                  onPressed: () {
                    Provider.of<HapticsProvider>(context, listen: false)
                        .selection();
                    showAddContinuousEventDialog();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Ongoing'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingContinuous
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchContinuousEvents,
                  child: _continuousEvents.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 96),
                              child: Column(
                                children: [
                                  Icon(Icons.repeat,
                                      size: 64,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No ongoing opportunities yet',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap + to create one.',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _continuousEvents.length,
                          itemBuilder: (context, i) =>
                              _buildContinuousEventCard(_continuousEvents[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildContinuousEventCard(ContinuousEvent ce) {
    final scheme = Theme.of(context).colorScheme;
    final pendingCount = _continuousPendingCounts[ce.id] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppDesign.borderLarge,
        border: Border.all(
          color: ce.isActive
              ? scheme.outlineVariant
              : scheme.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: AppDesign.paddingMedium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primary.withOpacity(0.15),
                  child: Icon(getIconForType(ce.type, context),
                      color: scheme.primary),
                ),
                const SizedBox(width: AppDesign.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ce.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: ce.isActive
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${ce.type} • ${ce.steps.length} step${ce.steps.length == 1 ? '' : 's'}'
                        '${ce.allowMultipleSubmissions ? ' • multiple submissions' : ' • single submission'}',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!ce.isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: AppDesign.borderRound,
                    ),
                    child: const Text('Inactive',
                        style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
            if (ce.description.isNotEmpty) ...[
              const SizedBox(height: AppDesign.spacingS),
              Text(
                ce.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppDesign.spacingM),
            Row(
              children: [
                ActionChip(
                  avatar: Icon(
                    pendingCount > 0
                        ? Icons.notifications_active
                        : Icons.inbox_outlined,
                    size: 18,
                    color: pendingCount > 0 ? scheme.primary : null,
                  ),
                  label: Text('Pending ($pendingCount)'),
                  onPressed: () async {
                    Provider.of<HapticsProvider>(context, listen: false)
                        .selection();
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ContinuousEventSubmissionsPage(event: ce),
                      ),
                    );
                    _fetchContinuousEvents();
                  },
                ),
                const Spacer(),
                IconButton(
                  tooltip: ce.isActive ? 'Deactivate' : 'Activate',
                  icon: Icon(ce.isActive
                      ? Icons.visibility
                      : Icons.visibility_off_outlined),
                  onPressed: () => _toggleContinuousActive(ce),
                ),
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit),
                  onPressed: () => showAddContinuousEventDialog(existing: ce),
                ),
                IconButton(
                  tooltip: 'Delete permanently',
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: () => _confirmDeleteContinuous(ce),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleContinuousActive(ContinuousEvent ce) async {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    try {
      await supabase
          .from('continuous_events')
          .update({
            'is_active': !ce.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', ce.id);
      haptics.success();
      await _fetchContinuousEvents();
    } catch (e) {
      haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteContinuous(ContinuousEvent ce) async {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    haptics.selection();

    final countRows = await supabase
        .from('continuous_event_submissions')
        .select('id')
        .eq('continuous_event_id', ce.id);
    final submissionCount = (countRows as List).length;

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete permanently?'),
          content: Text(
            submissionCount == 0
                ? 'Delete "${ce.name}"? This cannot be undone.'
                : 'Delete "${ce.name}"? This will also delete '
                    '$submissionCount submission${submissionCount == 1 ? '' : 's'} '
                    '(approved hours already credited will remain). '
                    'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await supabase.from('continuous_events').delete().eq('id', ce.id);
      haptics.success();
      await _fetchContinuousEvents();
    } catch (e) {
      haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  void showAddContinuousEventDialog({ContinuousEvent? existing}) {
    final formKey = GlobalKey<FormState>();
    String name = existing?.name ?? '';
    String description = existing?.description ?? '';
    String? selectedType = existing?.type;
    bool allowMultiple = existing?.allowMultipleSubmissions ?? true;
    bool isActive = existing?.isActive ?? true;
    final steps = List<ContinuousEventStep>.from(existing?.steps ?? const []);
    final societyProvider =
        Provider.of<SocietyProvider>(context, listen: false);
    final societyId =
        existing?.societyId ?? societyProvider.currentSociety?.id ?? 1;
    final hourReqs = societyProvider.currentSociety?.hourRequirements ?? [];

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSt) {
            void addOrEditStep({ContinuousEventStep? edit, int? index}) {
              final descCtl =
                  TextEditingController(text: edit?.description ?? '');
              final linkCtl = TextEditingController(text: edit?.link ?? '');
              showDialog(
                context: ctx,
                builder: (sCtx) {
                  return AlertDialog(
                    title: Text(edit == null ? 'Add Step' : 'Edit Step'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: descCtl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: linkCtl,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Link (optional)',
                            hintText: 'https://...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(sCtx).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final desc = descCtl.text.trim();
                          if (desc.isEmpty) return;
                          final link = linkCtl.text.trim();
                          setSt(() {
                            final step = ContinuousEventStep(
                              order: index ?? steps.length,
                              description: desc,
                              link: link.isEmpty ? null : link,
                            );
                            if (index != null) {
                              steps[index] = step;
                            } else {
                              steps.add(step);
                            }
                          });
                          Navigator.of(sCtx).pop();
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  );
                },
              );
            }

            final activeTypes = hourReqs
                .where((r) => r.isActive || r.type == selectedType)
                .map((r) => r.type)
                .toSet()
                .toList();
            if (selectedType != null && !activeTypes.contains(selectedType)) {
              activeTypes.add(selectedType!);
            }

            return AlertDialog(
              title: Text(existing == null
                  ? 'Add Ongoing Opportunity'
                  : 'Edit Ongoing Opportunity'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        initialValue: name,
                        decoration:
                            const InputDecoration(labelText: 'Name'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                        onSaved: (v) => name = v!.trim(),
                      ),
                      TextFormField(
                        initialValue: description,
                        decoration: const InputDecoration(
                            labelText: 'Description'),
                        maxLines: 3,
                        onSaved: (v) => description = (v ?? '').trim(),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        items: activeTypes
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t),
                                ))
                            .toList(),
                        onChanged: (v) => setSt(() => selectedType = v),
                        decoration:
                            const InputDecoration(labelText: 'Hour Type'),
                        validator: (v) => v == null ? 'Pick a type' : null,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: allowMultiple,
                        onChanged: (v) =>
                            setSt(() => allowMultiple = v ?? true),
                        title: const Text('Allow multiple submissions'),
                        subtitle: const Text(
                            'Members can log hours more than once'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (existing != null)
                        CheckboxListTile(
                          value: isActive,
                          onChanged: (v) =>
                              setSt(() => isActive = v ?? true),
                          title: const Text('Active'),
                          subtitle: const Text('Visible to members'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Steps (${steps.length}/10)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Step'),
                            onPressed: steps.length >= 10
                                ? null
                                : () => addOrEditStep(),
                          ),
                        ],
                      ),
                      if (steps.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            'No steps yet. Add up to 10 so members know what to do.',
                            style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < steps.length; i++)
                              Padding(
                                key: ValueKey('step-$i-${steps[i].description}'),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          child: Text('${i + 1}',
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                steps[i].description,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                              if (steps[i].link != null)
                                                Text(
                                                  steps[i].link!,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Move up',
                                          icon: const Icon(Icons.arrow_upward,
                                              size: 20),
                                          onPressed: i == 0
                                              ? null
                                              : () => setSt(() {
                                                    final item =
                                                        steps.removeAt(i);
                                                    steps.insert(i - 1, item);
                                                    for (var j = 0;
                                                        j < steps.length;
                                                        j++) {
                                                      steps[j] = steps[j]
                                                          .copyWith(order: j);
                                                    }
                                                  }),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Move down',
                                          icon: const Icon(
                                              Icons.arrow_downward,
                                              size: 20),
                                          onPressed: i == steps.length - 1
                                              ? null
                                              : () => setSt(() {
                                                    final item =
                                                        steps.removeAt(i);
                                                    steps.insert(i + 1, item);
                                                    for (var j = 0;
                                                        j < steps.length;
                                                        j++) {
                                                      steps[j] = steps[j]
                                                          .copyWith(order: j);
                                                    }
                                                  }),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Edit',
                                          icon: const Icon(Icons.edit,
                                              size: 20),
                                          onPressed: () => addOrEditStep(
                                              edit: steps[i], index: i),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Delete',
                                          icon: const Icon(Icons.delete,
                                              size: 20),
                                          onPressed: () => setSt(() {
                                            steps.removeAt(i);
                                            for (var j = 0;
                                                j < steps.length;
                                                j++) {
                                              steps[j] = steps[j]
                                                  .copyWith(order: j);
                                            }
                                          }),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 1),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    formKey.currentState!.save();
                    Navigator.of(ctx).pop();
                    await _saveContinuousEvent(
                      existing: existing,
                      societyId: societyId,
                      name: name,
                      description: description,
                      type: selectedType!,
                      allowMultiple: allowMultiple,
                      isActive: isActive,
                      steps: steps,
                    );
                  },
                  child: Text(existing == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveContinuousEvent({
    ContinuousEvent? existing,
    required int societyId,
    required String name,
    required String description,
    required String type,
    required bool allowMultiple,
    required bool isActive,
    required List<ContinuousEventStep> steps,
  }) async {
    final haptics = Provider.of<HapticsProvider>(context, listen: false);
    final reorderedSteps = [
      for (int i = 0; i < steps.length; i++) steps[i].copyWith(order: i)
    ];

    try {
      final Map<String, dynamic> payload = {
        'name': name,
        'description': description,
        'type': type,
        'allow_multiple_submissions': allowMultiple,
        'is_active': isActive,
        'steps': reorderedSteps.map((s) => s.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existing == null) {
        payload['society_id'] = societyId;
        payload['created_by'] = supabase.auth.currentUser?.id;
        await supabase.from('continuous_events').insert(payload);
      } else {
        await supabase
            .from('continuous_events')
            .update(payload)
            .eq('id', existing.id);
      }
      haptics.success();
      await _fetchContinuousEvents();
    } catch (e) {
      haptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }
}
