import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'providers/societyprovider.dart';
import 'common/app_design.dart';
import 'models/affecteduser.dart';
import 'models/customeventgroup.dart';
import 'models/logactivity.dart';
import '../providers/hapticsprovider.dart';

final supabase = Supabase.instance.client;

class BulkEditEventsPage extends StatefulWidget {
  const BulkEditEventsPage({super.key});

  @override
  _BulkEditEventsPageState createState() => _BulkEditEventsPageState();
}

class _BulkEditEventsPageState extends State<BulkEditEventsPage> {
  final _formKey = GlobalKey<FormState>();
  List<CustomEventGroup> _eventGroups = [];
  Set<String> _selectedEvents = {};
  String _searchQuery = '';
  bool _isLoading = true;

  String _newEventName = '';
  String _newStartTime = '';
  double _newHours = 0;
  String _newType = 'Service';

  @override
  void initState() {
    super.initState();
    _fetchCustomEvents();
  }

  Future<void> _fetchCustomEvents() async {
    setState(() => _isLoading = true);

    try {
      // Get current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get all events for this society with related profile info in a single query
      final response = await supabase.from('Service hours').select('''
            *,
            profiles:user_id(name)
          ''').eq('society_id', society.id).order('event_name');

      // Process and group the events
      final Map<String, Map<String, dynamic>> groupedEvents = {};

      for (final record in response) {
        final eventName = record['event_name'] as String;
        if (!groupedEvents.containsKey(eventName)) {
          groupedEvents[eventName] = {
            'users': <AffectedUser>[],
            'type': record['type'],
            'hours': record['hours'],
            'timeSlot': record['timeslot'] ?? '',
          };
        }

        groupedEvents[eventName]!['users']!.add(
          AffectedUser(
            id: record['user_id'],
            name: record['profiles']['name'],
          ),
        );
      }

      // Convert to CustomEventGroup objects
      final List<CustomEventGroup> eventGroups =
          groupedEvents.entries.map((entry) {
        final eventData = entry.value;
        return CustomEventGroup(
          eventName: entry.key,
          userCount: (eventData['users'] as List).length,
          type: eventData['type'] as String,
          hours: (eventData['hours'] as num).toDouble(),
          timeSlot: eventData['timeSlot'] as String,
          affectedUsers: (eventData['users'] as List<AffectedUser>).toList(),
        );
      }).toList();

      // Sort event groups by name
      eventGroups.sort((a, b) => a.eventName.compareTo(b.eventName));

      setState(() {
        _eventGroups = eventGroups;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching custom events: $e');
      setState(() => _isLoading = false);
    }
  }

  List<CustomEventGroup> get _filteredEventGroups {
    if (_searchQuery.isEmpty) return _eventGroups;

    final query = _searchQuery.toLowerCase();
    return _eventGroups
        .where((group) =>
            group.eventName.toLowerCase().contains(query) ||
            group.type.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _updateSelectedEvents() async {
    if (_selectedEvents.isEmpty) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Get the current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No society selected')),
        );
        return;
      }

      // Format time for database
      String? formattedTime;
      if (_newStartTime.isNotEmpty) {
        // Format time as HH:MM:00 for Supabase time column
        formattedTime = '$_newStartTime:00';
      }

      // For each selected event, update all associated records
      for (var eventName in _selectedEvents) {
        final group = _eventGroups.firstWhere((g) => g.eventName == eventName);

        // Build update data
        final updateData = <String, dynamic>{};

        if (_newEventName.isNotEmpty) {
          updateData['event_name'] = _newEventName;
        }
        if (formattedTime != null) {
          updateData['timeslot'] = formattedTime;
        }
        if (_newHours > 0) {
          updateData['hours'] = _newHours;
        }

        updateData['type'] = _newType;

        // Update all records for this event in this society
        await supabase
            .from('Service hours')
            .update(updateData)
            .eq('event_name', eventName)
            .eq('society_id',
                society.id); // Important: Scope to current society
      }

      // Hide loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully updated ${_selectedEvents.length} events',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Log the bulk update activity
      final timeSlotDisplay =
          _newStartTime.isNotEmpty ? _newStartTime : 'Various Times';
      final userId = supabase.auth.currentUser?.id;

      if (userId != null && society != null) {
        await logactivity(
          _newEventName.isEmpty ? 'Multiple Events' : _newEventName,
          timeSlotDisplay,
          _newHours == 0 ? 0 : _newHours,
          'bulk_update',
          userId,
          societyId: society.id,
        );
      }

      // Clear selection and refresh the events list
      setState(() {
        _selectedEvents.clear();
      });
      await _fetchCustomEvents();
    } catch (e) {
      // Hide loading indicator if still showing
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating events: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedEvents() async {
    if (_selectedEvents.isEmpty) return;

    try {
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No society selected')),
        );
        return;
      }

      // Delete all selected events in a single query, scoped to current society
      await supabase
          .from('Service hours')
          .delete()
          .inFilter('event_name', _selectedEvents.toList())
          .eq('society_id', society.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Events deleted successfully')),
      );

      _selectedEvents.clear();
      await _fetchCustomEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting events: $e')),
      );
    }
  }

  void _showUpdateDialog() {
    TimeOfDay? selectedTime;
    String tempEventName = '';
    String tempHours = '';
    String tempType = _newType;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update Selected Events'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'New Event Name (Optional)',
                      hintText: 'Leave blank to keep current names',
                    ),
                    onChanged: (value) => tempEventName = value,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      selectedTime == null
                          ? 'Select Time'
                          : selectedTime!.format(context),
                    ),
                    onPressed: () async {
                      final hapticsProvider =
                          Provider.of<HapticsProvider>(context, listen: false);
                      hapticsProvider.selection();
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() => selectedTime = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'New Hours (Optional)',
                      hintText: 'Leave blank to keep current hours',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true, decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return null; // Optional field
                      }
                      final number = double.tryParse(value);
                      if (number == null) {
                        return 'Please enter a valid number';
                      }
                      if (number == 0) {
                        return 'Hours cannot be zero';
                      }
                      return null;
                    },
                    onChanged: (value) => tempHours = value,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: tempType,
                    items: ['Service', 'Tutoring', 'Meeting']
                        .map((type) =>
                            DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) => setState(() => tempType = value!),
                    decoration: const InputDecoration(labelText: 'Event Type'),
                  ),
                ],
              ),
            ),
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
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();

                  // Update values
                  _newEventName = tempEventName;
                  _newStartTime =
                      '${selectedTime!.hour}:${selectedTime!.minute}';
                  _newHours = double.tryParse(tempHours) ?? 0;
                  _newType = tempType;

                  Navigator.pop(context);
                  _updateSelectedEvents();
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Edit Custom Events'),
        actions: [
          if (_selectedEvents.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                _showUpdateDialog;
              },
              tooltip: 'Edit Selected',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                final hapticsProvider =
                    Provider.of<HapticsProvider>(context, listen: false);
                hapticsProvider.selection();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Selected Events'),
                    content: Text(
                      'Are you sure you want to delete ${_selectedEvents.length} events? This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          Navigator.pop(context);
                          _deleteSelectedEvents();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Delete Selected',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: AppDesign.paddingMedium,
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      labelText: 'Search Events',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: AppDesign.borderMedium,
                      ),
                    ),
                  ),
                ),
                // Selection Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectedEvents.length ==
                                _filteredEventGroups.length &&
                            _filteredEventGroups.isNotEmpty,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value ?? false) {
                              _selectedEvents = _filteredEventGroups
                                  .map((g) => g.eventName)
                                  .toSet();
                            } else {
                              _selectedEvents.clear();
                            }
                          });
                        },
                      ),
                      Text(
                        'Select All (${_selectedEvents.length}/${_filteredEventGroups.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                // Events List
                Expanded(
                  child: _filteredEventGroups.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No custom events found'
                                : 'No events match your search',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredEventGroups.length,
                          itemBuilder: (context, index) {
                            final group = _filteredEventGroups[index];
                            return _buildEventGroupTile(group);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEventGroupTile(CustomEventGroup group) {
    final isSelected = _selectedEvents.contains(group.eventName);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Checkbox(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value!) {
                  _selectedEvents.add(group.eventName);
                } else {
                  _selectedEvents.remove(group.eventName);
                }
              });
            },
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.eventName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.userCount} ${group.userCount == 1 ? 'user' : 'users'} • ${group.type} • ${group.hours} hours',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: AppDesign.borderMedium,
                ),
                child: Text(
                  group.userCount.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: AppDesign.paddingMedium,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time Slot:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(group.timeSlot),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Affected Users:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: group.affectedUsers.map((user) {
                      return Chip(
                        label: Text(user.name),
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceVariant,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
