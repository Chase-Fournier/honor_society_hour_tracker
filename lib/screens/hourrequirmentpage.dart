import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../models/hourrequirement.dart';
import '../models/honorsociety.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

final supabase = Supabase.instance.client;

class HourRequirementsPage extends StatefulWidget {
  final HonorSociety society;

  const HourRequirementsPage({Key? key, required this.society})
      : super(key: key);

  @override
  _HourRequirementsPageState createState() => _HourRequirementsPageState();
}

class _HourRequirementsPageState extends State<HourRequirementsPage> {
  List<HourRequirement> _requirements = [];
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _requirements = List.from(widget.society.hourRequirements);
  }

  void _showEditRequirementDialog(HourRequirement requirement) {
    String type = requirement.type;
    String description = requirement.description;
    double hours = requirement.hoursNeeded;
    bool isActive = requirement.isActive;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Hour Requirement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Type Name',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: type),
                onChanged: (value) => type = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: description),
                maxLines: 2,
                onChanged: (value) => description = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Hours Required',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: hours.toString()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => hours = double.tryParse(value) ?? hours,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text(
                    'Inactive requirements won\'t be counted or displayed'),
                value: isActive,
                onChanged: (value) => setState(() => isActive = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _showDeleteConfirmation(requirement);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Delete'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (type.isNotEmpty && hours > 0) {
                setState(() => _isLoading = true);
                try {
                  await supabase.from('hour_requirements').update({
                    'type': type,
                    'description': description,
                    'hours_needed': hours,
                    'is_active': isActive,
                  }).eq('id', requirement.id);

                  setState(() {
                    final index =
                        _requirements.indexWhere((r) => r.id == requirement.id);
                    if (index != -1) {
                      _requirements[index] = HourRequirement(
                        id: requirement.id,
                        type: type,
                        description: description,
                        hoursNeeded: hours,
                        isActive: isActive,
                      );
                    }
                    _hasChanges = true;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Requirement updated successfully')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating requirement: $e')),
                    );
                  }
                } finally {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(HourRequirement requirement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Requirement'),
        content: Text(
          'Are you sure you want to delete the ${requirement.type} requirement? '
          'This will affect all historical records using this type.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                await supabase
                    .from('hour_requirements')
                    .delete()
                    .eq('id', requirement.id);

                setState(() {
                  _requirements.removeWhere((r) => r.id == requirement.id);
                  _hasChanges = true;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Requirement deleted successfully')),
                  );
                  Navigator.pop(context); // Close delete confirmation
                  Navigator.pop(context); // Close edit dialog
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting requirement: $e')),
                  );
                }
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddRequirementDialog() {
    String type = '';
    String description = '';
    double hours = 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Hour Requirement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Type Name',
                  hintText: 'E.g., Service, Tutoring, Leadership',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => type = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe what counts for this requirement',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (value) => description = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Hours Required',
                  hintText: 'E.g., 10.0',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => hours = double.tryParse(value) ?? 0,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (type.isNotEmpty && hours > 0) {
                setState(() => _isLoading = true);
                try {
                  final response = await supabase
                      .from('hour_requirements')
                      .insert({
                        'society_id': widget.society.id,
                        'type': type,
                        'description': description,
                        'hours_needed': hours,
                        'is_active': true,
                      })
                      .select()
                      .single();

                  setState(() {
                    _requirements.add(HourRequirement.fromJson(response));
                    _hasChanges = true;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Requirement added successfully')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding requirement: $e')),
                    );
                  }
                } finally {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(
                              child: CircularProgressIndicator(),
                          )
          : RefreshIndicator(
              onRefresh: () async {
                // Refresh requirements from the database
                final requirementsResponse = await supabase
                    .from('hour_requirements')
                    .select()
                    .eq('society_id', widget.society.id);

                setState(() {
                  _requirements = requirementsResponse
                      .map<HourRequirement>(
                          (json) => HourRequirement.fromJson(json))
                      .toList();
                });
              },
              child: _requirements.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.playlist_add,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No requirements defined',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the + button to add requirements',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _requirements.length,
                      itemBuilder: (context, index) {
                        final requirement = _requirements[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: requirement.isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                              foregroundColor: Colors.white,
                              child: const Icon(Icons.access_time),
                            ),
                            title: Text(
                              requirement.type,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    requirement.isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(requirement.description),
                                const SizedBox(height: 4),
                                Text(
                                  '${requirement.hoursNeeded} hours required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: requirement.isActive
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _showEditRequirementDialog(requirement),
                            ),
                            onTap: () =>
                                _showEditRequirementDialog(requirement),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRequirementDialog,
        tooltip: 'Add Requirement',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    // Notify parent if changes were made
    if (_hasChanges && ModalRoute.of(context)?.isCurrent == false) {
      // This would typically trigger a refresh of the parent's data
      // You could use callbacks or state management here
    }
    super.dispose();
  }
}
