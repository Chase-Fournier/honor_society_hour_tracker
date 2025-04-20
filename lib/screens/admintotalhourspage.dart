import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import '../common/app_design.dart';
import '../models/meetingnote.dart';
import 'activitylogpage.dart';

final supabase = Supabase.instance.client;

class AdminTotalHoursPage extends StatefulWidget {
  const AdminTotalHoursPage({super.key});

  @override
  _AdminTotalHoursPageState createState() => _AdminTotalHoursPageState();
}

class _AdminTotalHoursPageState extends State<AdminTotalHoursPage> {
  double _totalHours = 0;
  double _totalServiceHours = 0;
  double _totalTutoringHours = 0;
  double _totalMeetingHours = 0;
  String _notesTitle = '';
  String _notesText = '';
  List<MeetingNote> _meetingNotes = [];

  @override
  void initState() {
    super.initState();
    _fetchTotalHours();
    _fetchMeetingNotes();
  }

  void _showAddNotesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Meeting Notes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
                onChanged: (value) {
                  setState(() {
                    _notesTitle = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Notes',
                ),
                maxLines: 10,
                onChanged: (value) {
                  setState(() {
                    _notesText = value;
                  });
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
              child: const Text('Save'),
              onPressed: () {
                _saveNotes();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showMeetingNotesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Meeting Notes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _meetingNotes.map((note) {
                return ListTile(
                  title: Text(note.title),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showEditNotesDialog(note);
                    },
                  ),
                );
              }).toList(),
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

  void _showEditNotesDialog(MeetingNote note) {
    String updatedTitle = note.title;
    String updatedText = note.text;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Meeting Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
                controller: TextEditingController(text: note.title),
                onChanged: (value) {
                  updatedTitle = value;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Notes',
                ),
                maxLines: 10,
                controller: TextEditingController(text: note.text),
                onChanged: (value) {
                  updatedText = value;
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
              child: const Text('Save'),
              onPressed: () {
                _updateNotes(note.id, updatedTitle, updatedText);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _updateNotes(int noteId, String title, String text) async {
    await Supabase.instance.client.from('Notes').update({
      'title': title,
      'text': text,
    }).eq('id', noteId);

    _fetchMeetingNotes();
  }

  Future<void> _fetchMeetingNotes() async {
    final response = await Supabase.instance.client
        .from('Notes')
        .select('*')
        .order('created_at', ascending: false);

    final List<dynamic> data = response;
    if (mounted) {
      setState(() {
        _meetingNotes = data.map((json) => MeetingNote.fromJson(json)).toList();
      });
    }
  }

  /// Creates new meeting notes in the database.
  ///
  /// Returns:
  /// - Future<void>
  void _saveNotes() async {
    await Supabase.instance.client.from('Notes').insert({
      'title': _notesTitle,
      'text': _notesText,
      'created_at': DateTime.now().toIso8601String(),
    });

    _notesTitle = '';
    _notesText = '';

    _fetchMeetingNotes();
  }

  Future<void> _fetchTotalHours() async {
    final response = await Supabase.instance.client
        .from('Service hours')
        .select('hours, type');

    final data = response as List<dynamic>;
    double serviceHours = 0;
    double tutoringHours = 0;
    double meetingHours = 0;

    for (final entry in data) {
      final hours = entry['hours'];
      final eventType = entry['type'] as String?;

      if (eventType == 'Service') {
        serviceHours += hours;
      } else if (eventType == 'Tutoring') {
        tutoringHours += hours;
      } else if (eventType == 'Meeting') {
        meetingHours += hours;
      }
    }

    if (mounted) {
      setState(() {
        _totalServiceHours = serviceHours;
        _totalTutoringHours = tutoringHours;
        _totalMeetingHours = meetingHours;
        _totalHours = serviceHours + tutoringHours + meetingHours;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        elevation: 15,
        shadowColor: Theme.of(context).colorScheme.shadow,
        title: Text(
          'Total NHS Hours',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppDesign.radiusXLarge),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Main content area
            Padding(
              padding: EdgeInsets.all(isWideScreen ? 24.0 : 16.0),
              child: isWideScreen ? _buildWideLayout() : _buildCompactLayout(),
            ),

            // Quick Actions Panel
          ],
        ),
      ),
      bottomNavigationBar: _buildQuickActionsPanel(isWideScreen),
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      children: [
        // Total Hours Card
        _buildTotalHoursCard(isCompact: true),
        const SizedBox(height: 16),
        // Categories Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryCard(
                'Service',
                _totalServiceHours,
                Icons.volunteer_activism,
                Theme.of(context).colorScheme.primary,
                isCompact: true,
              ),
              const SizedBox(width: 12),
              _buildCategoryCard(
                'Tutoring',
                _totalTutoringHours,
                Icons.school,
                Theme.of(context).colorScheme.secondary,
                isCompact: true,
              ),
              const SizedBox(width: 12),
              _buildCategoryCard(
                'Meeting',
                _totalMeetingHours,
                Icons.groups,
                Theme.of(context).colorScheme.tertiary,
                isCompact: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildTotalHoursCard(isCompact: false),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  'Service',
                  _totalServiceHours,
                  Icons.volunteer_activism,
                  Theme.of(context).colorScheme.primary,
                  isCompact: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCategoryCard(
                  'Tutoring',
                  _totalTutoringHours,
                  Icons.school,
                  Theme.of(context).colorScheme.secondary,
                  isCompact: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCategoryCard(
                  'Meeting',
                  _totalMeetingHours,
                  Icons.groups,
                  Theme.of(context).colorScheme.tertiary,
                  isCompact: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalHoursCard({required bool isCompact}) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: AppDesign.borderXLarge,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Total Hours',
            style: TextStyle(
              fontSize: isCompact ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: isCompact ? 140 : 180,
            height: isCompact ? 140 : 180,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: _totalHours / 2000,
                  strokeWidth: isCompact ? 12 : 16,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _totalHours.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: isCompact ? 28 : 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Hours',
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 16,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
      String title, double hours, IconData icon, Color color,
      {required bool isCompact}) {
    return Container(
      width: isCompact ? 120 : null,
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppDesign.borderLarge,
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isCompact ? 24 : 32),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isCompact ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: isCompact ? 2 : 4),
          Text(
            '${hours.toStringAsFixed(1)}h',
            style: TextStyle(
              fontSize: isCompact ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsPanel(bool isWideScreen) {
    if (isWideScreen) {
      return Padding(
        padding: AppDesign.paddingLarge,
        child: Container(
          width: double.infinity,
          padding: AppDesign.paddingLarge,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: AppDesign.borderXLarge,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bolt,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                      child: _buildActionButton(
                          'Add Notes', Icons.note_add, _showAddNotesDialog)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildActionButton(
                          'View Notes', Icons.notes, _showMeetingNotesDialog)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      'Activity Log',
                      Icons.history,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ActivityLogPage()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      // Mobile version remains attached to bottom
      return Container(
        width: double.infinity,
        padding: AppDesign.paddingMedium,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDesign.radiusXLarge),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      children: [
                        _buildActionButton(
                            'Add Notes', Icons.note_add, _showAddNotesDialog),
                        const SizedBox(height: 8),
                        _buildActionButton(
                            'View Notes', Icons.notes, _showMeetingNotesDialog),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          'Activity Log',
                          Icons.history,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ActivityLogPage()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildActionButton(
      String label, IconData icon, VoidCallback onPressed) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 900;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          vertical: 16,
          horizontal: isWideScreen ? 32 : 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDesign.borderMedium,
        ),
        elevation: isWideScreen ? 2 : 0,
      ),
      child: isWideScreen
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isWideScreen ? 16 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isWideScreen ? 16 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }
}
