import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'JoinRequestsAdmin.dart';
import 'societyprovider.dart';
import 'package:provider/provider.dart';
import 'hourrequirement.dart';
import 'iconselector.dart';

class SocietyAdminPage extends StatefulWidget {
  const SocietyAdminPage({Key? key}) : super(key: key);

  @override
  _SocietyAdminPageState createState() => _SocietyAdminPageState();
}

class _SocietyAdminPageState extends State<SocietyAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _meetingRequirementController;
  bool _isLoading = false;
  File? _imageFile;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Get society from provider
    final society =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety;

    _nameController = TextEditingController(text: society?.name ?? '');
    _descriptionController =
        TextEditingController(text: society?.description ?? '');
    _meetingRequirementController = TextEditingController(
        text: society?.meetingRequirement.toString() ?? '5');
    _imageUrl = society?.imageUrl;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _meetingRequirementController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl;

    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(_imageFile!.path)}';
      final String storagePath = 'society_images/$fileName';

      await Supabase.instance.client.storage
          .from('society_images')
          .upload(storagePath, _imageFile!);

      // Get public URL
      final String publicUrl = Supabase.instance.client.storage
          .from('society_images')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  Future<void> _saveSocietyDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<SocietyProvider>(context, listen: false);
      final society = provider.currentSociety;

      if (society == null) {
        throw Exception('No society selected');
      }

      // Upload image if selected
      final imageUrl = await _uploadImage();

      // Update society details
      await Supabase.instance.client.from('honor_societies').update({
        'name': _nameController.text,
        'description': _descriptionController.text,
        'meeting_requirement': int.parse(_meetingRequirementController.text),
        if (imageUrl != null) 'image_url': imageUrl,
      }).eq('id', society.id);

      // Refresh provider data
      await provider.refreshCurrentSociety();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Society details updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating society: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SocietyProvider>(builder: (context, provider, _) {
      final society = provider.currentSociety;

      if (provider.isLoading || society == null) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Society Administration'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Society Details'),
              Tab(text: 'Hour Requirements'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSocietyDetailsTab(),
            const HourRequirementsPage(),
          ],
        ),
      );
    });
  }

  Widget _buildSocietyDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Society Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Society Logo
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!) as ImageProvider
                                  : (_imageUrl != null
                                      ? NetworkImage(_imageUrl!)
                                          as ImageProvider
                                      : const AssetImage(
                                          'assets/placeholder.png')),
                              child: _imageFile == null && _imageUrl == null
                                  ? const Icon(Icons.school, size: 60)
                                  : null,
                            ),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Society Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Society Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the society name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Society Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Meeting Requirements
                    TextFormField(
                      controller: _meetingRequirementController,
                      decoration: const InputDecoration(
                        labelText: 'Meeting Requirement (number of meetings)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the meeting requirement';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Join Requests Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JoinRequestsAdminPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Manage Join Requests'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Save Button
            Center(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveSocietyDetails,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Society Details'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Enhanced page for managing hour requirements
class HourRequirementsPage extends StatefulWidget {
  const HourRequirementsPage({Key? key}) : super(key: key);

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
    _loadRequirements();
  }

  void _loadRequirements() {
    final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;
    if (society != null) {
      setState(() {
        _requirements = List.from(society.hourRequirements);
      });
    }
  }

  void _showEditRequirementDialog(HourRequirement requirement) {
  String type = requirement.type;
  String description = requirement.description;
  double hours = requirement.hoursNeeded;
  bool isActive = requirement.isActive;
  String iconName = requirement.iconName; // New field for icon

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => hours = double.tryParse(value) ?? hours,
              ),
              const SizedBox(height: 16),
              // New icon selector component
              IconSelector(
                initialValue: iconName,
                onChanged: (value) {
                  setState(() {
                    iconName = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Inactive requirements won\'t be counted or displayed'),
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
              foregroundColor: Theme.of(context).colorScheme.error,
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
                    'icon_name': iconName, // Update the icon name
                  }).eq('id', requirement.id);

                  setState(() {
                    final index = _requirements.indexWhere((r) => r.id == requirement.id);
                    if (index != -1) {
                      _requirements[index] = HourRequirement(
                        id: requirement.id,
                        type: type,
                        description: description,
                        hoursNeeded: hours,
                        isActive: isActive,
                        iconName: iconName, // Include the icon name
                      );
                    }
                    _hasChanges = true;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Requirement updated successfully')),
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
                await Supabase.instance.client
                    .from('hour_requirements')
                    .delete()
                    .eq('id', requirement.id);

                setState(() {
                  _requirements.removeWhere((r) => r.id == requirement.id);
                  _hasChanges = true;
                });

                // Refresh the society provider
                await Provider.of<SocietyProvider>(context, listen: false)
                    .refreshCurrentSociety();

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
              backgroundColor: Theme.of(context).colorScheme.error,
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
  String iconName = 'workspaces'; // Default icon
  final society = Provider.of<SocietyProvider>(context, listen: false).currentSociety;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => hours = double.tryParse(value) ?? 0,
              ),
              const SizedBox(height: 16),
              // New icon selector component
              IconSelector(
                initialValue: iconName,
                onChanged: (value) {
                  setState(() {
                    iconName = value;
                  });
                },
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
                  final response = await supabase.from('hour_requirements').insert({
                    'society_id': society!.id,
                    'type': type,
                    'description': description,
                    'hours_needed': hours,
                    'is_active': true,
                    'icon_name': iconName, // Include the icon name
                  }).select().single();

                  setState(() {
                    _requirements.add(HourRequirement.fromJson(response));
                    _hasChanges = true;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Requirement added successfully')),
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
    ),
  );
}

  
  @override
  Widget build(BuildContext context) {
    return Consumer<SocietyProvider>(builder: (context, provider, _) {
      // Refresh requirements list when society changes
      if (_requirements.isEmpty && provider.currentSociety != null) {
        _requirements = List.from(provider.currentSociety!.hourRequirements);
      }

      return Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  // Refresh society data and update local requirements
                  await provider.refreshCurrentSociety();
                  if (provider.currentSociety != null) {
                    setState(() {
                      _requirements =
                          List.from(provider.currentSociety!.hourRequirements);
                    });
                  }
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
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
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
    });
  }
}
