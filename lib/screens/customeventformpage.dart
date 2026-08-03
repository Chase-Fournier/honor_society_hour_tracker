import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import '../common/app_widgets.dart';
import '../common/app_form.dart';
import '../common/nhsformatutils.dart';
import '../models/userprofile.dart';
import '../models/logactivity.dart';
import '../providers/hapticsprovider.dart';
import '../data/supabase_client.dart';


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
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _hoursController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    // Recipients are chosen on the Members page before this form opens.
    selectedUserIds = widget.users.map((user) => user.id).toList();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

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

    debugPrint(types.toString());
    return types;
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

      // Show success message and close the form.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${hours.toStringAsFixed(1)} hours for ${selectedUserIds.length} users',
          ),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ),
      );

      // Return success
      Navigator.of(context).pop(true);
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving bulk events: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = _availableTypes;
    final recipients =
        widget.users.where((u) => selectedUserIds.contains(u.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Hours'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Event Details
            Padding(
              padding: AppDesign.paddingMedium,
              child: AppFormSection(
                title: 'Event details',
                icon: Icons.event_note,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Event name',
                      onChanged: (value) => eventName = value,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please enter an event name'
                          : null,
                    ),
                    const SizedBox(height: AppDesign.spacingM),
                    AppTextField(
                      label: 'Hours',
                      controller: _hoursController,
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                      onChanged: (value) => setState(
                          () => hours = double.tryParse(value) ?? 0.0),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDesign.spacingM),
                    AppDropdownField<String>(
                      label: 'Event type',
                      value: type,
                      onChanged: (value) =>
                          setState(() => type = value ?? types[1]),
                      items: types
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              ))
                          .toList(),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please select an event type'
                          : null,
                    ),
                    const SizedBox(height: AppDesign.spacingM),
                    AppPickerField(
                      label: 'Time',
                      hint: 'Select',
                      value: selectedTime != null
                          ? NhsFormatUtils.formatTimeOfDay(selectedTime!, context)
                          : null,
                      icon: Icons.schedule,
                      onTap: () async {
                        final TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setState(() => selectedTime = pickedTime);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Recipients (chosen on the Members page)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Adding hours to ${recipients.length} '
                    '${recipients.length == 1 ? 'member' : 'members'}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Recipient list (read-only; remove to drop someone)
            Expanded(
              child: recipients.isEmpty
                  ? Center(
                      child: Text(
                        'No members selected',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                      ),
                    )
                  : Scrollbar(
                      child: ListView.builder(
                        padding: AppDesign.paddingSmall,
                        itemCount: recipients.length,
                        itemBuilder: (context, index) {
                          final user = recipients[index];

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            color: Theme.of(context).colorScheme.surface,
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                child: Text(user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?'),
                              ),
                              title: Text(user.name),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                tooltip: 'Remove',
                                onPressed: () {
                                  final hapticsProvider =
                                      Provider.of<HapticsProvider>(context,
                                          listen: false);
                                  hapticsProvider.selection();
                                  setState(() {
                                    selectedUserIds.remove(user.id);
                                  });
                                },
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
        padding: EdgeInsets.zero,
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _validateAndSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
