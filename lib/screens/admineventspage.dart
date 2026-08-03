import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import '../common/app_widgets.dart';
import '../common/app_form.dart';
import '../common/nhsformatutils.dart';
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
import '../data/supabase_client.dart';


class AdminEventsPage extends StatefulWidget {
  final HonorSociety? society;
  const AdminEventsPage({super.key, this.society});

  @override
  _AdminEventsPageState createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchDataOptimized();
    _fetchContinuousEvents();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // Keep _listMode (which drives the FAB) in sync with the active tab.
  void _handleTabChange() {
    final mode = _tabController.index == 0 ? 'Events' : 'Ongoing';
    if (mode != _listMode) {
      Provider.of<HapticsProvider>(context, listen: false).selection();
      setState(() => _listMode = mode);
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
        backgroundColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Events'),
            Tab(text: 'Ongoing'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Events tab
          Row(
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
                                      Icon(
                                        Icons.event_busy,
                                        size: 64,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
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
          // Ongoing tab
          _buildContinuousEventsBody(isWideScreen),
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
                      icon: const Icon(Icons.delete_outline, size: 20),
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
                    icon: const Icon(Icons.delete_outline),
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
    final formKey = GlobalKey<_EventFormBodyState>();
    final currentSocietyId =
        widget.society?.id ?? _currentSociety?.id ?? 1;

    showAppForm<void>(
      context: context,
      title: 'Add Event',
      icon: Icons.event,
      body: (ctx) => _EventFormBody(
        key: formKey,
        defaultSocietyId: currentSocietyId,
        collections: _collections,
        fetchSocieties: _fetchUserSocieties,
        fetchRequirements: _fetchSocietyHourRequirements,
        editTimeSlot: _showTimeSlotForm,
        onSubmit: (data) => _addEvent(
          data.name,
          data.description,
          data.location,
          data.date,
          data.type,
          data.isMandatory,
          data.collectionId,
          data.timeSlots,
          data.requiresForms,
          data.formLink,
          Duration(hours: data.deadlineHours),
          data.hasDelay,
          data.delayHours,
          data.societyId,
        ),
      ),
      footer: (ctx) => _formFooter(
        ctx,
        submitLabel: 'Add Event',
        onSubmit: () => formKey.currentState?.submit() ?? false,
      ),
    );
  }

  /// Convenience accessor for the current society.
  HonorSociety? get _currentSociety =>
      Provider.of<SocietyProvider>(context, listen: false).currentSociety;

  /// Standard Cancel / Save footer for the shared form sheets. [onSubmit]
  /// returns true when the form is valid and was submitted, in which case the
  /// sheet is dismissed.
  List<Widget> _formFooter(
    BuildContext ctx, {
    required String submitLabel,
    required bool Function() onSubmit,
  }) {
    return [
      OutlinedButton(
        onPressed: () {
          Provider.of<HapticsProvider>(context, listen: false).selection();
          Navigator.of(ctx).pop();
        },
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          Provider.of<HapticsProvider>(context, listen: false).selection();
          if (onSubmit()) Navigator.of(ctx).pop();
        },
        child: Text(submitLabel),
      ),
    ];
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
      var query = supabase.from('Collections').select('*');

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
                    icon: const Icon(Icons.delete_outline),
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
    await supabase.from('Events').update({
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
      await supabase
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
  /// Presents the shared time-slot form (responsive dialog / bottom sheet) and
  /// resolves to the created/edited [TimeSlot], or null if cancelled. Used both
  /// when building an event's slot list and when editing a saved slot.
  Future<TimeSlot?> _showTimeSlotForm({TimeSlot? initial}) {
    final formKey = GlobalKey<FormState>();
    TimeOfDay startTime = initial?.time ?? TimeOfDay.now();
    TimeOfDay endTime = initial?.endTime ?? TimeOfDay.now();
    final capacityC =
        TextEditingController(text: (initial?.numberOfPeople ?? 1).toString());
    final notesC = TextEditingController(text: initial?.notes ?? '');

    return showAppForm<TimeSlot>(
      context: context,
      title: initial == null ? 'Add Time Slot' : 'Edit Time Slot',
      icon: Icons.schedule,
      body: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPickerField(
                label: 'Start time',
                value: NhsFormatUtils.formatTimeOfDay(startTime, ctx),
                icon: Icons.play_arrow,
                onTap: () async {
                  final picked = await showTimePicker(
                      context: ctx, initialTime: startTime);
                  if (picked != null) setSheetState(() => startTime = picked);
                },
              ),
              const SizedBox(height: AppDesign.spacingM),
              AppPickerField(
                label: 'End time',
                value: NhsFormatUtils.formatTimeOfDay(endTime, ctx),
                icon: Icons.stop,
                onTap: () async {
                  final picked =
                      await showTimePicker(context: ctx, initialTime: endTime);
                  if (picked != null) setSheetState(() => endTime = picked);
                },
              ),
              const SizedBox(height: AppDesign.spacingM),
              AppTextField(
                label: 'Capacity',
                controller: capacityC,
                keyboardType: const TextInputType.numberWithOptions(),
                validator: (value) =>
                    int.tryParse(value ?? '') == null ? 'Enter a number' : null,
              ),
              const SizedBox(height: AppDesign.spacingM),
              AppTextField(
                label: 'Notes (optional)',
                controller: notesC,
              ),
            ],
          ),
        ),
      ),
      footer: (ctx) => [
        OutlinedButton(
          onPressed: () {
            Provider.of<HapticsProvider>(context, listen: false).selection();
            Navigator.of(ctx).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Provider.of<HapticsProvider>(context, listen: false).selection();
            if (formKey.currentState!.validate()) {
              Navigator.of(ctx).pop(TimeSlot(
                id: initial?.id ?? DateTime.now().millisecondsSinceEpoch,
                time: startTime,
                endTime: endTime,
                numberOfPeople: int.parse(capacityC.text),
                notes: notesC.text,
                eventId: initial?.eventId ?? 0,
                createdAt: initial?.createdAt ?? DateTime.now(),
                attendees: initial?.attendees ?? [],
              ));
            }
          },
          child: Text(initial == null ? 'Add' : 'Save'),
        ),
      ],
      onDispose: () {
        capacityC.dispose();
        notesC.dispose();
      },
    );
  }

  // In AdminEventsPage class - replace the _showEditEventDialog method

  void _showEditEventDialog(Event event) {
    final formKey = GlobalKey<_EventFormBodyState>();
    final societyId = _currentSociety?.id ?? widget.society?.id ?? 1;

    showAppForm<void>(
      context: context,
      title: 'Edit Event',
      icon: Icons.edit_calendar,
      body: (ctx) => _EventFormBody(
        key: formKey,
        existing: event,
        defaultSocietyId: societyId,
        collections: _collections,
        fetchSocieties: _fetchUserSocieties,
        fetchRequirements: _fetchSocietyHourRequirements,
        editTimeSlot: _showTimeSlotForm,
        onSubmit: (data) {
          final society = _currentSociety;
          if (society == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No society selected')),
            );
            return;
          }
          _updateEvent(
            event.id,
            data.name,
            data.description,
            data.location,
            data.date,
            data.type,
            data.isMandatory,
            data.collectionId,
            data.timeSlots,
            data.requiresForms,
            data.formLink,
            Duration(hours: data.deadlineHours),
            data.hasDelay,
            data.delayHours,
            society.id,
          );
        },
      ),
      footer: (ctx) => _formFooter(
        ctx,
        submitLabel: 'Save',
        onSubmit: () => formKey.currentState?.submit() ?? false,
      ),
    );
  }

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
      final eventResponse = await supabase
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
        final inserted = await supabase
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
        final usersResponse = await supabase
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
          await supabase
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

  void _showAddCollectionDialog() {
    final formKey = GlobalKey<FormState>();
    final nameC = TextEditingController();

    showAppForm<void>(
      context: context,
      title: 'Add Collection',
      icon: Icons.folder_outlined,
      body: (ctx) => Form(
        key: formKey,
        child: AppTextField(
          label: 'Collection name',
          controller: nameC,
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Please enter the collection name'
              : null,
        ),
      ),
      footer: (ctx) => _formFooter(
        ctx,
        submitLabel: 'Add',
        onSubmit: () {
          if (!(formKey.currentState?.validate() ?? false)) return false;
          _addCollection(nameC.text.trim());
          return true;
        },
      ),
      onDispose: nameC.dispose,
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
    final response = await supabase.from('Collections').insert({
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
      await supabase.from('Events').update({
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
      final existingTimeSlotsResponse = await supabase
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
        return supabase.from('Time slots').update({
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
        final inserted = await supabase
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
        await supabase
            .from('Attendees')
            .delete()
            .inFilter('timeslot_id', deletedSlotIds);
        await supabase
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
          final usersResponse = await supabase
              .from('user_society_memberships')
              .select('user_id')
              .eq('society_id', societyId);

          // What attendee rows already exist for these slots?
          final existingAttendeesResp = await supabase
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
            await supabase
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
  void _showEditTimeSlotDialog(Event event, TimeSlot timeSlot) async {
    final updated = await _showTimeSlotForm(initial: timeSlot);
    if (updated != null) {
      _updateTimeSlot(event, timeSlot, updated.time, updated.endTime,
          updated.numberOfPeople, updated.notes);
    }
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
      await supabase.from('Time slots').update({
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
    await supabase.from('Events').delete().eq('id', event.id);
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
                  icon: const Icon(Icons.delete_outline),
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
    final nameC = TextEditingController(text: existing?.name ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    String? selectedType = existing?.type;
    bool allowMultiple = existing?.allowMultipleSubmissions ?? true;
    bool isActive = existing?.isActive ?? true;
    final steps = List<ContinuousEventStep>.from(existing?.steps ?? const []);
    final societyProvider =
        Provider.of<SocietyProvider>(context, listen: false);
    final societyId =
        existing?.societyId ?? societyProvider.currentSociety?.id ?? 1;
    final hourReqs = societyProvider.currentSociety?.hourRequirements ?? [];

    showAppForm<void>(
      context: context,
      title: existing == null
          ? 'Add Ongoing Opportunity'
          : 'Edit Ongoing Opportunity',
      icon: Icons.repeat,
      body: (ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSt) {
          Future<void> addOrEditStep({ContinuousEventStep? edit, int? index}) async {
            final result = await _showStepForm(
                initial: edit, order: index ?? steps.length);
            if (result != null) {
              setSt(() {
                if (index != null) {
                  steps[index] = result;
                } else {
                  steps.add(result);
                }
              });
            }
          }

          final activeTypes = hourReqs
              .where((r) => r.isActive || r.type == selectedType)
              .map((r) => r.type)
              .toSet()
              .toList();
          if (selectedType != null && !activeTypes.contains(selectedType)) {
            activeTypes.add(selectedType!);
          }

          return Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFormSection(
                  title: 'Details',
                  icon: Icons.info_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: 'Name',
                        controller: nameC,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter a name'
                            : null,
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      AppTextField(
                        label: 'Description',
                        controller: descC,
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppDesign.spacingM),
                      AppDropdownField<String>(
                        label: 'Hour type',
                        value: activeTypes.contains(selectedType)
                            ? selectedType
                            : null,
                        items: activeTypes
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) => setSt(() => selectedType = v),
                        validator: (v) => v == null ? 'Pick a type' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDesign.spacingL),
                AppFormSection(
                  title: 'Options',
                  icon: Icons.tune,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSwitchRow(
                        title: 'Allow multiple submissions',
                        subtitle: 'Members can log hours more than once',
                        value: allowMultiple,
                        onChanged: (v) => setSt(() => allowMultiple = v),
                      ),
                      if (existing != null)
                        AppSwitchRow(
                          title: 'Active',
                          subtitle: 'Visible to members',
                          value: isActive,
                          onChanged: (v) => setSt(() => isActive = v),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDesign.spacingL),
                AppFormSection(
                  title: 'Steps (${steps.length}/10)',
                  icon: Icons.checklist,
                  subtitle: 'Tell members what to do, up to 10 steps',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (steps.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppDesign.spacingS),
                          child: Text(
                            'No steps yet.',
                            style: Theme.of(ctx)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        )
                      else
                        for (int i = 0; i < steps.length; i++)
                          _buildStepRow(ctx, steps, i, setSt, addOrEditStep),
                      const SizedBox(height: AppDesign.spacingS),
                      OutlinedButton.icon(
                        onPressed:
                            steps.length >= 10 ? null : () => addOrEditStep(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add step'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      footer: (ctx) => [
        OutlinedButton(
          onPressed: () {
            Provider.of<HapticsProvider>(context, listen: false).selection();
            Navigator.of(ctx).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            Provider.of<HapticsProvider>(context, listen: false).selection();
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.of(ctx).pop();
            await _saveContinuousEvent(
              existing: existing,
              societyId: societyId,
              name: nameC.text.trim(),
              description: descC.text.trim(),
              type: selectedType!,
              allowMultiple: allowMultiple,
              isActive: isActive,
              steps: steps,
            );
          },
          child: Text(existing == null ? 'Create' : 'Save'),
        ),
      ],
      onDispose: () {
        nameC.dispose();
        descC.dispose();
      },
    );
  }

  /// One step row in the ongoing-opportunity form: numbered, with reorder /
  /// edit / delete controls.
  Widget _buildStepRow(
    BuildContext ctx,
    List<ContinuousEventStep> steps,
    int i,
    StateSetter setSt,
    Future<void> Function({ContinuousEventStep? edit, int? index}) addOrEditStep,
  ) {
    void renumber() {
      for (var j = 0; j < steps.length; j++) {
        steps[j] = steps[j].copyWith(order: j);
      }
    }

    return Padding(
      key: ValueKey('step-$i-${steps[i].description}'),
      padding: const EdgeInsets.symmetric(vertical: AppDesign.spacingXS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                child: Text('${i + 1}', style: const TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: AppDesign.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[i].description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (steps[i].link != null)
                      Text(
                        steps[i].link!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Move up',
                icon: const Icon(Icons.arrow_upward, size: 20),
                onPressed: i == 0
                    ? null
                    : () => setSt(() {
                          final item = steps.removeAt(i);
                          steps.insert(i - 1, item);
                          renumber();
                        }),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Move down',
                icon: const Icon(Icons.arrow_downward, size: 20),
                onPressed: i == steps.length - 1
                    ? null
                    : () => setSt(() {
                          final item = steps.removeAt(i);
                          steps.insert(i + 1, item);
                          renumber();
                        }),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit',
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => addOrEditStep(edit: steps[i], index: i),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => setSt(() {
                  steps.removeAt(i);
                  renumber();
                }),
              ),
            ],
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  /// Presents the add/edit-step form and resolves to the created/edited step,
  /// or null if cancelled.
  Future<ContinuousEventStep?> _showStepForm({
    ContinuousEventStep? initial,
    required int order,
  }) {
    final formKey = GlobalKey<FormState>();
    final descC = TextEditingController(text: initial?.description ?? '');
    final linkC = TextEditingController(text: initial?.link ?? '');

    return showAppForm<ContinuousEventStep>(
      context: context,
      title: initial == null ? 'Add Step' : 'Edit Step',
      icon: Icons.checklist,
      body: (ctx) => Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Description',
              controller: descC,
              maxLines: 3,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a description' : null,
            ),
            const SizedBox(height: AppDesign.spacingM),
            AppTextField(
              label: 'Link (optional)',
              controller: linkC,
              hint: 'https://...',
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
      footer: (ctx) => [
        OutlinedButton(
          onPressed: () {
            Provider.of<HapticsProvider>(context, listen: false).selection();
            Navigator.of(ctx).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Provider.of<HapticsProvider>(context, listen: false).selection();
            if (formKey.currentState!.validate()) {
              final link = linkC.text.trim();
              Navigator.of(ctx).pop(ContinuousEventStep(
                order: order,
                description: descC.text.trim(),
                link: link.isEmpty ? null : link,
              ));
            }
          },
          child: const Text('Save'),
        ),
      ],
      onDispose: () {
        descC.dispose();
        linkC.dispose();
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

/// Result payload emitted by [_EventFormBody] on submit.
class _EventFormData {
  final String name;
  final String description;
  final String location;
  final DateTime date;
  final String type;
  final bool isMandatory;
  final int? collectionId;
  final List<TimeSlot> timeSlots;
  final bool requiresForms;
  final String formLink;
  final int deadlineHours;
  final bool hasDelay;
  final int delayHours;
  final int societyId;

  _EventFormData({
    required this.name,
    required this.description,
    required this.location,
    required this.date,
    required this.type,
    required this.isMandatory,
    required this.collectionId,
    required this.timeSlots,
    required this.requiresForms,
    required this.formLink,
    required this.deadlineHours,
    required this.hasDelay,
    required this.delayHours,
    required this.societyId,
  });
}

/// Shared, sectioned event form used by both the Add and Edit flows. Present it
/// through [showAppForm] and trigger [submit] from the footer's Save button via
/// a `GlobalKey<_EventFormBodyState>`.
class _EventFormBody extends StatefulWidget {
  final Event? existing;
  final int defaultSocietyId;
  final List<Collection> collections;
  final Future<List<HonorSociety>> Function() fetchSocieties;
  final Future<List<HourRequirement>> Function(int societyId) fetchRequirements;
  final Future<TimeSlot?> Function({TimeSlot? initial}) editTimeSlot;
  final void Function(_EventFormData data) onSubmit;

  const _EventFormBody({
    super.key,
    this.existing,
    required this.defaultSocietyId,
    required this.collections,
    required this.fetchSocieties,
    required this.fetchRequirements,
    required this.editTimeSlot,
    required this.onSubmit,
  });

  @override
  State<_EventFormBody> createState() => _EventFormBodyState();
}

class _EventFormBodyState extends State<_EventFormBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _descC;
  late final TextEditingController _locationC;
  late final TextEditingController _formLinkC;
  late final TextEditingController _deadlineC;
  late final TextEditingController _delayC;

  late DateTime _date;
  String? _type;
  int? _collectionId;
  bool _mandatory = false;
  bool _requiresForms = false;
  bool _hasDelay = false;
  late int _societyId;
  late List<TimeSlot> _timeSlots;

  // Cached async lookups so a stray rebuild (toggling a switch, etc.) doesn't
  // re-hit the network or flash the dropdowns. The type list is re-fetched only
  // when the selected society changes.
  late Future<List<HonorSociety>> _societiesFuture;
  Future<List<HourRequirement>>? _typesFuture;
  int? _typesFutureSocietyId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameC = TextEditingController(text: e?.name ?? '');
    _descC = TextEditingController(text: e?.description ?? '');
    _locationC = TextEditingController(text: e?.location ?? '');
    _formLinkC = TextEditingController(text: e?.formLink ?? '');
    _deadlineC = TextEditingController(
        text: (e?.swapRequestDeadline.inHours ?? 24).toString());
    _delayC = TextEditingController(text: (e?.delayHours ?? 0).toString());
    _date = e?.date ?? DateTime.now();
    _type = e?.type;
    _collectionId = e?.collectionId;
    _mandatory = e?.isMandatory ?? false;
    _requiresForms = e?.requiresForms ?? false;
    _hasDelay = e?.hasDelay ?? false;
    _societyId = widget.defaultSocietyId;
    _timeSlots = List<TimeSlot>.from(e?.timeSlots ?? const []);
    _societiesFuture = widget.fetchSocieties();
    // Once societies load, make sure _societyId points at one of them so the
    // selector's displayed value and the value actually submitted stay in sync
    // (the selector otherwise falls back to the first society visually only).
    _societiesFuture.then((societies) {
      if (!mounted) return;
      if (societies.isNotEmpty && !societies.any((s) => s.id == _societyId)) {
        setState(() => _societyId = societies.first.id);
      }
    });
  }

  Future<List<HourRequirement>> _typesFor(int societyId) {
    if (_typesFuture == null || _typesFutureSocietyId != societyId) {
      _typesFuture = widget.fetchRequirements(societyId);
      _typesFutureSocietyId = societyId;
    }
    return _typesFuture!;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _descC.dispose();
    _locationC.dispose();
    _formLinkC.dispose();
    _deadlineC.dispose();
    _delayC.dispose();
    super.dispose();
  }

  /// Validates and, when valid, emits the form data. Returns true on success.
  bool submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (_type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event type')),
      );
      return false;
    }
    widget.onSubmit(_EventFormData(
      name: _nameC.text.trim(),
      description: _descC.text.trim(),
      location: _locationC.text.trim(),
      date: _date,
      type: _type!,
      isMandatory: _mandatory,
      collectionId: _collectionId,
      timeSlots: _timeSlots,
      requiresForms: _requiresForms,
      formLink: _formLinkC.text.trim(),
      deadlineHours: int.tryParse(_deadlineC.text) ?? 24,
      hasDelay: _hasDelay,
      delayHours: int.tryParse(_delayC.text) ?? 0,
      societyId: _societyId,
    ));
    return true;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Allow editing events whose date is already in the past without crashing.
    final first = _date.isBefore(now) ? _date : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addSlot() async {
    final slot = await widget.editTimeSlot();
    if (slot != null) setState(() => _timeSlots.add(slot));
  }

  Future<void> _editSlot(TimeSlot slot) async {
    final updated = await widget.editTimeSlot(initial: slot);
    if (updated != null && mounted) {
      setState(() {
        final i = _timeSlots.indexOf(slot);
        if (i >= 0) _timeSlots[i] = updated;
      });
    }
  }

  String? _validateNonNegativeInt(String? value) {
    if (value == null || value.isEmpty) return 'Enter a number';
    final n = int.tryParse(value);
    if (n == null || n < 0) return 'Enter a valid number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFormSection(
            title: 'Details',
            icon: Icons.info_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isEditing) _buildSocietySelector(),
                AppTextField(
                  label: 'Event name',
                  controller: _nameC,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter an event name'
                      : null,
                ),
                const SizedBox(height: AppDesign.spacingM),
                AppTextField(
                  label: 'Description',
                  controller: _descC,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a description'
                      : null,
                ),
                const SizedBox(height: AppDesign.spacingM),
                AppTextField(
                  label: 'Location (optional)',
                  controller: _locationC,
                ),
                const SizedBox(height: AppDesign.spacingM),
                _buildTypeDropdown(),
                const SizedBox(height: AppDesign.spacingM),
                _buildCollectionDropdown(),
              ],
            ),
          ),
          const SizedBox(height: AppDesign.spacingL),
          AppFormSection(
            title: 'Schedule',
            icon: Icons.event,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPickerField(
                  label: 'Date',
                  value: NhsFormatUtils.formatDate(_date),
                  icon: Icons.calendar_today,
                  onTap: _pickDate,
                ),
                if (_timeSlots.isNotEmpty) ...[
                  const SizedBox(height: AppDesign.spacingS),
                  ..._timeSlots.map(_buildSlotTile),
                ],
                const SizedBox(height: AppDesign.spacingS),
                OutlinedButton.icon(
                  onPressed: _addSlot,
                  icon: const Icon(Icons.add),
                  label: const Text('Add time slot'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesign.spacingL),
          AppFormSection(
            title: 'Options',
            icon: Icons.tune,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSwitchRow(
                  title: 'Mandatory',
                  value: _mandatory,
                  onChanged: (v) => setState(() => _mandatory = v),
                ),
                AppSwitchRow(
                  title: 'Requires forms',
                  value: _requiresForms,
                  onChanged: (v) => setState(() => _requiresForms = v),
                ),
                if (_requiresForms) ...[
                  const SizedBox(height: AppDesign.spacingS),
                  AppTextField(
                    label: 'Form link',
                    controller: _formLinkC,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a form link'
                        : null,
                  ),
                ],
                AppSwitchRow(
                  title: 'Signup delay',
                  subtitle: 'Hold sign-ups until closer to the event',
                  value: _hasDelay,
                  onChanged: (v) => setState(() => _hasDelay = v),
                ),
                if (_hasDelay) ...[
                  const SizedBox(height: AppDesign.spacingS),
                  AppTextField(
                    label: 'Delay hours before event',
                    controller: _delayC,
                    keyboardType: TextInputType.number,
                    validator: _validateNonNegativeInt,
                  ),
                ],
                const SizedBox(height: AppDesign.spacingM),
                AppTextField(
                  label: 'Cancel deadline (hours before event)',
                  controller: _deadlineC,
                  keyboardType: const TextInputType.numberWithOptions(),
                  validator: _validateNonNegativeInt,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocietySelector() {
    return FutureBuilder<List<HonorSociety>>(
      future: _societiesFuture,
      builder: (context, snapshot) {
        final societies = snapshot.data ?? [];
        if (societies.length <= 1) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDesign.spacingM),
          child: AppDropdownField<int>(
            label: 'Society',
            value: societies.any((s) => s.id == _societyId)
                ? _societyId
                : societies.first.id,
            items: societies
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _societyId = v!),
          ),
        );
      },
    );
  }

  Widget _buildTypeDropdown() {
    return FutureBuilder<List<HourRequirement>>(
      future: _typesFor(_societyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDesign.spacingS),
            child: LinearProgressIndicator(),
          );
        }
        final types = snapshot.data
                ?.where((req) => req.isActive)
                .map((req) => req.type)
                .toList() ??
            <String>[];
        if (!types.contains('Meeting')) types.add('Meeting');
        return AppDropdownField<String>(
          label: 'Event type',
          value: types.contains(_type) ? _type : null,
          items: types
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _type = v),
          validator: (v) => v == null ? 'Please select an event type' : null,
        );
      },
    );
  }

  Widget _buildCollectionDropdown() {
    // Fall back to 'No collection' if the event points at a collection that is
    // no longer in the list, otherwise the dropdown asserts on a missing value.
    final hasCollection =
        widget.collections.any((c) => c.id == _collectionId);
    return AppDropdownField<int?>(
      label: 'Collection',
      value: hasCollection ? _collectionId : null,
      items: [
        const DropdownMenuItem(value: null, child: Text('No collection')),
        ...widget.collections.map(
          (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
        ),
      ],
      onChanged: (v) => setState(() => _collectionId = v),
    );
  }

  Widget _buildSlotTile(TimeSlot slot) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDesign.spacingS),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppDesign.borderMedium,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: AppDesign.borderMedium),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDesign.spacingM, vertical: AppDesign.spacingXS),
          title: Text(NhsFormatUtils.formatTimeSlot(slot, context)),
          subtitle: Text('Capacity: ${slot.numberOfPeople}'),
          onTap: () => _editSlot(slot),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
            onPressed: () {
              Provider.of<HapticsProvider>(context, listen: false).selection();
              setState(() => _timeSlots.remove(slot));
            },
          ),
        ),
      ),
    );
  }
}
