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
import '../common/normalizetype.dart';
import '../common/iconutils.dart';


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

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _fetchCollections();
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
                      onTap: _showAddEventDialog,
                      dense: true,
                    ),
                    ListTile(
                      leading: Icon(Icons.create_new_folder,
                          color: Theme.of(context).colorScheme.primary),
                      title: const Text('Add Collection'),
                      onTap: _showAddCollectionDialog,
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
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                ),

                // Main event list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _fetchEvents();
                            await _fetchCollections();
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
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: _showAddEventDialog,
                  heroTag: 'addEvent',
                  child: const Icon(Icons.add),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: _showAddCollectionDialog,
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
    final Color typeColor = _getColorForEventType(event.type, context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppDesign.borderMedium),
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Draggable<Event>(
        data: event,
        feedback: Card(
          elevation: 4.0,
          shape:
              RoundedRectangleBorder(borderRadius: AppDesign.borderMedium),
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
            shape:
                RoundedRectangleBorder(borderRadius: AppDesign.borderLarge),
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
        child: Stack(
          children: [
            // Type indicator side bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(color: typeColor),
            ),

            // Main content with full expansion
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
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
                      onPressed: () => _showEditEventDialog(event),
                      tooltip: 'Edit Event',
                      padding: AppDesign.paddingSmall,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _deleteEvent(event),
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
                            onPressed: () =>
                                _showEditTimeSlotDialog(event, timeSlot),
                            visualDensity: VisualDensity.standard,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
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
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: AppDesign.borderLarge),
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isHovered
              ? Theme.of(context).colorScheme.surfaceVariant
              : Theme.of(context).colorScheme.surface,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(
                Icons.folder,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      collection.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                  // Show count of events in this collection
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: eventsInCollection.isEmpty
                          ? Theme.of(context).colorScheme.surfaceVariant
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: AppDesign.borderMedium,
                    ),
                    child: Text(
                      eventsInCollection.length.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: eventsInCollection.isEmpty
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _showDeleteCollectionDialog(collection),
                    tooltip: 'Delete Collection',
                  ),
                  const Icon(Icons.expand_more),
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

  void _showAddEventDialog() {
    final _formKey = GlobalKey<FormState>();
    String _eventName = '';
    String _eventDescription = '';
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
                      SizedBox(
                        height: 15,
                      ),
                      ElevatedButton(
                        child: Text(_eventDate == null
                            ? 'Select Date'
                            : '${_eventDate.toString().substring(0, 10)}'),
                        onPressed: () async {
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
                        onPressed: () =>
                            _showAddTimeSlotDialog(setState, _timeSlots),
                      ),
                      ..._timeSlots.map((timeSlot) => ListTile(
                            title: Text(
                                '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}'),
                            subtitle:
                                Text('Capacity: ${timeSlot.numberOfPeople}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () =>
                                  setState(() => _timeSlots.remove(timeSlot)),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Add Event'),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      _addEvent(
                        _eventName,
                        _eventDescription,
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
      print('Error fetching user societies: $e');
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
      print('Error fetching society hour requirements: $e');
      return [];
    }
  }

// Update _fetchEvents to filter by society if specified
// In AdminEventsPage class - replace the current _fetchEvents method

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

      // 1. Fetch events for this society
      final eventsResponse = await supabase
          .from('Events')
          .select()
          .eq('society_id', society.id)
          .order('date');

      // Create events with empty time slots first
      List<Event> events =
          eventsResponse.map<Event>((json) => Event.fromJson(json)).toList();

      // 2. Fetch time slots for all events in a single query
      final eventIds = events.map((e) => e.id).toList();
      if (eventIds.isEmpty) {
        setState(() {
          _events = [];
          _isLoading = false;
        });
        return;
      }

      final timeSlotsResponse = await supabase
          .from('Time slots')
          .select()
          .inFilter('event_id', eventIds);

      // Create a map of event_id -> List<TimeSlot>
      Map<int, List<TimeSlot>> timeSlotsByEvent = {};
      for (var json in timeSlotsResponse) {
        final timeSlot = TimeSlot.fromJson(json);
        final eventId = timeSlot.eventId;

        if (!timeSlotsByEvent.containsKey(eventId)) {
          timeSlotsByEvent[eventId] = [];
        }
        timeSlotsByEvent[eventId]!.add(timeSlot);
      }

      // 3. Fetch attendees for all time slots
      final timeSlotIds =
          timeSlotsResponse.map<int>((json) => json['id']).toList();

      if (timeSlotIds.isNotEmpty) {
        final attendeesResponse = await supabase
            .from('Attendees')
            .select('*, profiles:user_id(name)')
            .inFilter('timeslot_id', timeSlotIds);

        // Create a map of timeslot_id -> List<Attendee>
        Map<int, List<Attendee>> attendeesByTimeSlot = {};
        for (var json in attendeesResponse) {
          final attendee = Attendee(
            id: json['id'],
            timeSlotId: json['timeslot_id'],
            userId: json['user_id'],
            name: json['profiles']['name'],
            isPresent: json['is_present'] ?? false,
            formsCompleted: json['forms_completed'] ?? false,
          );

          final timeSlotId = attendee.timeSlotId;
          if (!attendeesByTimeSlot.containsKey(timeSlotId)) {
            attendeesByTimeSlot[timeSlotId] = [];
          }
          attendeesByTimeSlot[timeSlotId]!.add(attendee);
        }

        // Now assign attendees to time slots
        for (var timeSlotList in timeSlotsByEvent.values) {
          for (var timeSlot in timeSlotList) {
            if (attendeesByTimeSlot.containsKey(timeSlot.id)) {
              timeSlot.attendees = attendeesByTimeSlot[timeSlot.id]!;
            }
          }
        }
      }

      // Finally, assign time slots to events
      for (var event in events) {
        if (timeSlotsByEvent.containsKey(event.id)) {
          event.timeSlots = timeSlotsByEvent[event.id]!;
        }
      }

      // Update state with the fully assembled events
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching events: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: $e')),
        );
        setState(() => _isLoading = false);
      }
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
      print('Error fetching collections: $e');
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _deleteCollection(collection);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
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
      _fetchEvents();
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Add Time Slot'),
                  onPressed: () {
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
                        SizedBox(
                          height: 10,
                        ),
                        ElevatedButton(
                          child: Text(
                              'Date: ${_eventDate.toString().substring(0, 10)}'),
                          onPressed: () async {
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
                          onPressed: () =>
                              _showAddTimeSlotDialog(setState, _timeSlots),
                        ),
                        ..._timeSlots.map((timeSlot) => ListTile(
                              title: Text(
                                  '${timeSlot.time.format(context)} - ${timeSlot.endTime.format(context)}'),
                              subtitle:
                                  Text('Capacity: ${timeSlot.numberOfPeople}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () =>
                                    setState(() => _timeSlots.remove(timeSlot)),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  ElevatedButton(
                    child: const Text('Update'),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        _updateEvent(
                            event.id,
                            _eventName,
                            _eventDescription,
                            _eventDate,
                            _selectedEventType!,
                            _isMandatory,
                            _selectedCollectionId,
                            _timeSlots,
                            _requiresForms,
                            _formLink,
                            Duration(hours: swapRequestDeadline),
                            _hasDelay,
                            _delayHours);
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

// In AdminEventsPage class - update the _showAddEventDialog method

// Update the _addEvent method to include societyId
  Future<void> _addEvent(
    String name,
    String description,
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
    int societyId, // Add new parameter
  ) async {
    try {
      // Insert the event
      final eventResponse = await Supabase.instance.client
          .from('Events')
          .insert({
            'name': name,
            'description': description,
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
            'society_id': societyId, // Add society_id
          })
          .select()
          .single();

      final newEventId = eventResponse['id'];

      // Insert time slots
      for (var timeSlot in timeSlots) {
        final timeSlotResponse = await Supabase.instance.client
            .from('Time slots')
            .insert({
              'event_id': newEventId,
              'start_time': DateTime(DateTime.now().year, date.month, date.day,
                      timeSlot.time.hour, timeSlot.time.minute)
                  .toIso8601String(),
              'end_time': DateTime(DateTime.now().year, date.month, date.day,
                      timeSlot.endTime.hour, timeSlot.endTime.minute)
                  .toIso8601String(),
              'number_of_people': timeSlot.numberOfPeople,
              'notes': timeSlot.notes,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        final newTimeSlotId = timeSlotResponse['id'];

        // If the event is mandatory, add all users of the society as attendees
        if (isMandatory || type == "Meeting") {
          final usersResponse = await Supabase.instance.client
              .from('user_society_memberships')
              .select('user_id')
              .eq('society_id', societyId);

          for (var user in usersResponse) {
            await Supabase.instance.client.from('Attendees').insert({
              'timeslot_id': newTimeSlotId,
              'user_id': user['user_id'],
              'is_present': false,
            });
          }
        }
      }

      // Refresh the events list
      await _fetchEvents();

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
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () {
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
    final response = await Supabase.instance.client
        .from('Collections')
        .insert({'name': name, 'event_ids': []});

    if (response != null) {
      final newCollection = Collection.fromJson(response[0]);
      setState(() {
        _collections.add(newCollection);
      });
    } else {
      // Handle error
      print('Failed to add collection');
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
  ) async {
    try {
      // Update the event
      await Supabase.instance.client.from('Events').update({
        'name': name,
        'description': description,
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

      // Fetch existing time slots
      final existingTimeSlotsResponse = await Supabase.instance.client
          .from('Time slots')
          .select()
          .eq('event_id', eventId);

      final existingTimeSlots = existingTimeSlotsResponse
          .map((slot) => TimeSlot.fromJson(slot))
          .toList();

      // Update, add, or delete time slots
      for (var timeSlot in timeSlots) {
        // Check if this timeSlot exists in our existingTimeSlots list
        if (existingTimeSlots.any((slot) => slot.id == timeSlot.id)) {
          // Update existing time slot
          await Supabase.instance.client.from('Time slots').update({
            'start_time': DateTime(DateTime.now().year, date.month, date.day,
                    timeSlot.time.hour, timeSlot.time.minute)
                .toIso8601String(),
            'end_time': DateTime(DateTime.now().year, date.month, date.day,
                    timeSlot.endTime.hour, timeSlot.endTime.minute)
                .toIso8601String(),
            'number_of_people': timeSlot.numberOfPeople,
            'notes': timeSlot.notes,
          }).eq('id', timeSlot.id ?? 0);

          // Remove from existingTimeSlots list
          existingTimeSlots.removeWhere((slot) => slot.id == timeSlot.id);
        } else {
          // Add new time slot
          final newTimeSlotResponse = await Supabase.instance.client
              .from('Time slots')
              .insert({
                'event_id': eventId,
                'start_time': DateTime(DateTime.now().year, date.month,
                        date.day, timeSlot.time.hour, timeSlot.time.minute)
                    .toIso8601String(),
                'end_time': DateTime(DateTime.now().year, date.month, date.day,
                        timeSlot.endTime.hour, timeSlot.endTime.minute)
                    .toIso8601String(),
                'number_of_people': timeSlot.numberOfPeople,
                'notes': timeSlot.notes,
                'created_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

          final newTimeSlotId = newTimeSlotResponse['id'];

          // If the event is mandatory, add all users as attendees for the new time slot
          if (isMandatory) {
            final usersResponse = await Supabase.instance.client
                .from('profiles')
                .select('user_id');

            for (var user in usersResponse) {
              await Supabase.instance.client.from('Attendees').insert({
                'timeslot_id': newTimeSlotId,
                'user_id': user['user_id'],
                'is_present': false,
              });
            }
          }
        }
      }

      // Delete time slots that are no longer present
      for (var slotToDelete in existingTimeSlots) {
        await Supabase.instance.client
            .from('Time slots')
            .delete()
            .eq('id', slotToDelete.id ?? 0);

        // Also delete associated attendees
        await Supabase.instance.client
            .from('Attendees')
            .delete()
            .eq('timeslot_id', slotToDelete.id ?? 0);
      }

      // If the event has become mandatory, add all users to all time slots
      if (isMandatory) {
        final allTimeSlots = await Supabase.instance.client
            .from('Time slots')
            .select()
            .eq('event_id', eventId);

        final usersResponse =
            await Supabase.instance.client.from('profiles').select('user_id');

        for (var timeSlot in allTimeSlots) {
          for (var user in usersResponse) {
            // Check if the user is already an attendee
            final existingAttendee = await Supabase.instance.client
                .from('Attendees')
                .select()
                .eq('timeslot_id', timeSlot['id'])
                .eq('user_id', user['user_id'])
                .maybeSingle();

            if (existingAttendee == null) {
              await Supabase.instance.client.from('Attendees').insert({
                'timeslot_id': timeSlot['id'],
                'user_id': user['user_id'],
                'is_present': false,
              });
            }
          }
        }
      }

      // Refresh the events list
      await _fetchEvents();

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
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Update Time Slot'),
              onPressed: () {
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
}
