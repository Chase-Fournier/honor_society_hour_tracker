import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import '../common/iconutils.dart';
import '../models/userprofile.dart';
import '../models/logactivity.dart';
import '../providers/hapticsprovider.dart';

final supabase = Supabase.instance.client;

class BulkCustomEventFormPage extends StatefulWidget {
  final List<UserProfile> users;

  const BulkCustomEventFormPage({super.key, required this.users});

  @override
  _BulkCustomEventFormPageState createState() =>
      _BulkCustomEventFormPageState();
}

class _BulkCustomEventFormPageState extends State<BulkCustomEventFormPage> {
  String eventName = '';
  TimeOfDay? selectedTime;
  double hours = 0;
  String type = 'Meeting';
  List<String> selectedUserIds = [];
  String searchQuery = '';
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  // Get available requirement types from society
  List<String> get _availableTypes {
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society == null)
      return ['Service', 'Tutoring', 'Meeting']; // Default fallback

    final types = ['Meeting']; // Always include Meeting

    // Add all active requirements from the society
    for (final req in society.hourRequirements) {
      if (req.isActive && !types.contains(req.type)) {
        types.add(req.type);
      }
    }

    if (types.length == 1) {
      types.add('Service');
    }

    print(types);
    return types;
  }

  List<UserProfile> get filteredUsers {
    return widget.users.where((user) {
      final lowercaseName = user.name.toLowerCase();
      final lowercaseQuery = searchQuery.toLowerCase();
      return lowercaseQuery.isEmpty || lowercaseName.contains(lowercaseQuery);
    }).toList();
  }

  void _validateAndSave() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct the errors in the form')),
      );
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time')),
      );
      return;
    }

    if (selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one user')),
      );
      return;
    }

    _saveBulkCustomEvent();
  }

  Future<void> _saveBulkCustomEvent() async {
    setState(() => _isLoading = true);

    try {
      // Get society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        throw Exception('No society selected');
      }

      final timeSlot = '${selectedTime!.hour}:${selectedTime!.minute}';

      final List<Map<String, dynamic>> bulkEvents =
          selectedUserIds.map((userId) {
        return {
          'user_id': userId,
          'event_name': eventName,
          'timeslot': timeSlot,
          'hours': hours.toDouble(),
          'type': type,
          'society_id': society.id, // Important: Include society ID
          'date': DateTime.now()
              .toIso8601String(), // Include date for better tracking
        };
      }).toList();

      // Insert all records in a single operation
      await supabase.from('Service hours').insert(bulkEvents);

      // Log activity for each user
      for (final userId in selectedUserIds) {
        await logactivity(
          eventName,
          timeSlot,
          hours,
          'manual_addition',
          userId,
          societyId: society.id,
        );
      }

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${hours.toStringAsFixed(1)} hours for ${selectedUserIds.length} users',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Return success
      Navigator.of(context).pop(true);
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving bulk events: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = _availableTypes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Bulk Custom Event'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Event Details Card
            Card(
              elevation: 0,
              margin: AppDesign.paddingMedium,
              shape: RoundedRectangleBorder(
                borderRadius: AppDesign.borderLarge,
              ),
              child: Padding(
                padding: AppDesign.paddingMedium,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event_note,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Event Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Event Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an event name';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          eventName = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Event Type Dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: type,
                            onChanged: (value) {
                              setState(() {
                                type = value ?? types[1];
                              });
                            },
                            items: types
                                .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ))
                                .toList(),
                            decoration: InputDecoration(
                              labelText: 'Event Type',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(getIconForType(type, context)),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select an event type';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Time Selector
                        Expanded(
                          flex: 1,
                          child: InkWell(
                            onTap: () async {
                              final hapticsProvider =
                                  Provider.of<HapticsProvider>(context,
                                      listen: false);
                              hapticsProvider.selection();
                              final TimeOfDay? pickedTime =
                                  await showTimePicker(
                                context: context,
                                initialTime: selectedTime ?? TimeOfDay.now(),
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  selectedTime = pickedTime;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Time',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.access_time),
                                suffixIcon: selectedTime != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          final hapticsProvider =
                                              Provider.of<HapticsProvider>(
                                                  context,
                                                  listen: false);
                                          hapticsProvider.selection();
                                          setState(() {
                                            selectedTime = null;
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              child: Text(
                                selectedTime != null
                                    ? selectedTime!.format(context)
                                    : 'Select',
                                style: selectedTime == null
                                    ? TextStyle(
                                        color: Theme.of(context).hintColor)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Hours Input
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Hours',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.timer),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: false, decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final hours = double.tryParse(value);
                              if (hours == null || hours <= 0) {
                                return 'Invalid';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                hours = double.tryParse(value) ?? 0.0;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Selection Header with Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Search Members',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Selection stats chip
                  Chip(
                    label: Text(
                      '${selectedUserIds.length} selected',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    avatar: Icon(
                      Icons.people,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            // Select All Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Checkbox(
                    value: selectedUserIds.length == filteredUsers.length &&
                        filteredUsers.isNotEmpty,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value ?? false) {
                          selectedUserIds =
                              filteredUsers.map((user) => user.id).toList();
                        } else {
                          selectedUserIds.clear();
                        }
                      });
                    },
                  ),
                  const Text('Select All'),
                  const Spacer(),
                  // Action buttons to select or clear all based on search results
                  if (searchQuery.isNotEmpty) ...[
                    TextButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Select Filtered'),
                      onPressed: () {
                        final hapticsProvider = Provider.of<HapticsProvider>(
                            context,
                            listen: false);
                        hapticsProvider.selection();
                        setState(() {
                          for (final user in filteredUsers) {
                            if (!selectedUserIds.contains(user.id)) {
                              selectedUserIds.add(user.id);
                            }
                          }
                        });
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Clear Filtered'),
                      onPressed: () {
                        final hapticsProvider = Provider.of<HapticsProvider>(
                            context,
                            listen: false);
                        hapticsProvider.selection();
                        setState(() {
                          selectedUserIds.removeWhere((id) =>
                              filteredUsers.any((user) => user.id == id));
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Users List
            Expanded(
              child: filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users match your search',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    )
                  : Scrollbar(
                      child: ListView.builder(
                        padding: AppDesign.paddingSmall,
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final isSelected = selectedUserIds.contains(user.id);

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.7)
                                : Theme.of(context).colorScheme.surface,
                            child: CheckboxListTile(
                              title: Text(
                                user.name,
                                style: TextStyle(
                                  fontWeight:
                                      isSelected ? FontWeight.bold : null,
                                ),
                              ),
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value ?? false) {
                                    selectedUserIds.add(user.id);
                                  } else {
                                    selectedUserIds.remove(user.id);
                                  }
                                });
                              },
                              dense: true,
                              secondary: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: CircleAvatar(
                                  child: Text(user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?'),
                                  backgroundColor: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  foregroundColor: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
        child: Padding(
          padding: AppDesign.paddingSmall,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _validateAndSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
