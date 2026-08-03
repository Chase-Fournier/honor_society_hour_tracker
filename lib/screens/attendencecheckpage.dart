import 'dart:async';
import 'package:flutter/material.dart';
import '../common/app_design.dart';
import '../models/timeslot.dart';
import '../models/event.dart';
import '../models/userprofile.dart';
import '../models/attendee.dart';
import '../models/logactivity.dart';
import 'package:provider/provider.dart';
import '../providers/societyprovider.dart';
import '../providers/hapticsprovider.dart';
import '../data/supabase_client.dart';
import '../logic/hours.dart';
import '../logic/attendance.dart';

class AttendanceCheckPage extends StatefulWidget {
  final Event event;
  final TimeSlot timeSlot;

  const AttendanceCheckPage(
      {Key? key, required this.event, required this.timeSlot})
      : super(key: key);

  @override
  _AttendanceCheckPageState createState() => _AttendanceCheckPageState();
}

class _AttendanceCheckPageState extends State<AttendanceCheckPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Attendee> _allAttendees = [];
  List<Attendee> _presentAttendees = [];
  List<Attendee> _absentAttendees = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAttendees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Retrieves all attendees for a specific time slot.
  /// Separates into present and absent lists.
  ///
  /// Returns:
  /// - Future<void>
  ///
  /// Throws:
  /// - DatabaseException if attendee fetch fails
  Future<void> _fetchAttendees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('Attendees')
          .select('*, profiles:user_id(name)')
          .eq('timeslot_id', widget.timeSlot.id ?? 0);

      _allAttendees = response
          .map<Attendee>((json) => Attendee.fromJson({
                ...json,
                'name': json['profiles']['name'],
              }))
          .toList();

      _presentAttendees =
          _allAttendees.where((attendee) => attendee.isPresent).toList();
      _absentAttendees =
          _allAttendees.where((attendee) => !attendee.isPresent).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching attendees: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Attendee> _getFilteredAttendees(List<Attendee> attendees) {
    if (_searchQuery.isEmpty) {
      return attendees;
    }
    final lowercaseQuery = _searchQuery.toLowerCase();
    return attendees.where((attendee) {
      return attendee.name.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Updates attendance records for multiple attendees.
  /// Handles hour crediting and activity logging.
  ///
  /// Returns:
  /// - Future<void>
  ///
  /// Throws:
  /// - DatabaseException if attendance update fails
  Future<void> _saveAttendance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<Attendee> attendeesToUpdate = _tabController.index == 0
          ? _absentAttendees.where((a) => a.isPresent).toList()
          : _presentAttendees.where((a) => !a.isPresent).toList();

      if (attendeesToUpdate.isNotEmpty) {
        final society =
            Provider.of<SocietyProvider>(context, listen: false).currentSociety;
        final slotId = widget.timeSlot.id ?? 0;
        final userIds = attendeesToUpdate.map((a) => a.userId).toList();

        // One lookup for the whole roster. This used to be a select per
        // attendee inside the loop below.
        final existingRows = await supabase
            .from('Service hours')
            .select('user_id')
            .eq('timeslot_id', slotId)
            .inFilter('user_id', userIds);

        final existingUserIds = {
          for (final row in existingRows) row['user_id'] as String,
        };

        final changes = attendanceChangesFor(
          attendees: attendeesToUpdate,
          userIdsWithExistingHours: existingUserIds,
          event: widget.event,
          timeSlot: widget.timeSlot,
          societyId: society?.id,
        );

        // Batched writes, one query per kind of change.
        if (changes.hoursToInsert.isNotEmpty) {
          await supabase
              .from('Service hours')
              .insert([for (final row in changes.hoursToInsert) row.toJson()]);
        }

        if (changes.userIdsToClear.isNotEmpty) {
          await supabase
              .from('Service hours')
              .delete()
              .eq('timeslot_id', slotId)
              .inFilter('user_id', changes.userIdsToClear);
        }

        for (final entry in changes.presenceByAttendeeId.entries) {
          await supabase
              .from('Attendees')
              .update({'is_present': entry.value}).eq('id', entry.key);
        }

        // Activity logging stays per-member: each entry names one person.
        if (!mounted) return;
        final slotLabel =
            '${widget.timeSlot.time.format(context)} - ${widget.timeSlot.endTime.format(context)}';
        final hours = timeSlotHours(widget.timeSlot);

        for (final row in changes.hoursToInsert) {
          await logactivity(widget.event.name, slotLabel, hours,
              'attendance_marked', row.userId,
              societyId: society?.id);
        }
        for (final userId in changes.userIdsToClear) {
          await logactivity(widget.event.name, slotLabel, hours,
              'attendance_removed', userId,
              societyId: society?.id);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved successfully')),
      );

      // Refresh the attendees list
      await _fetchAttendees();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving attendance: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _searchQuery = '';
      });
    }
  }

  /// Syncs all society members to the attendance list for mandatory/meeting events
  Future<void> _syncAllMembers() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      // Get current society
      final society =
          Provider.of<SocietyProvider>(context, listen: false).currentSociety;
      if (society == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No society selected')),
        );
        return;
      }

      // Get all society members
      final membersResponse = await supabase
          .from('user_society_memberships')
          .select('user_id, profiles!inner(name)')
          .eq('society_id', society.id);

      // Get current attendees for this time slot
      final currentAttendees = _allAttendees.map((a) => a.userId).toSet();

      // Find members who aren't attendees yet
      final missingAttendees = <Map<String, dynamic>>[];
      for (final member in membersResponse) {
        final userId = member['user_id'] as String;
        if (!currentAttendees.contains(userId)) {
          missingAttendees.add({
            'timeslot_id': widget.timeSlot.id,
            'user_id': userId,
            'is_present': false,
            'forms_completed': false,
          });
        }
      }

      if (missingAttendees.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All members are already attendees')),
        );
        return;
      }

      // Add missing attendees
      await supabase.from('Attendees').insert(missingAttendees);

      // Log the sync action
      await logactivity(
        widget.event.name,
        '${widget.timeSlot.time.format(context)} - ${widget.timeSlot.endTime.format(context)}',
        timeSlotHours(widget.timeSlot),
        'sync_attendees',
        supabase.auth.currentUser?.id ?? '',
        societyId: society?.id,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Added ${missingAttendees.length} missing attendees')),
      );

      // Refresh the attendees list
      await _fetchAttendees();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error syncing members: $e')),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  /// Calculates duration in hours between start and end times.
  ///
  /// Parameters:
  /// - timeSlot: TimeSlot - Time slot to calculate duration for
  ///
  /// Returns:
  /// - double: Duration in hours


  void _showSwapDialog(Attendee currentAttendee) {
    List<UserProfile> allUsers = [];
    List<UserProfile> filteredUsers = [];
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Swap Attendee'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (value) {
                      setDialogState(() {
                        searchQuery = value;
                        filteredUsers = allUsers
                            .where((user) => user.name
                                .toLowerCase()
                                .contains(searchQuery.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<UserProfile>>(
                    future: _fetchAllUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          allUsers.isEmpty) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else {
                        if (snapshot.hasData && allUsers.isEmpty) {
                          allUsers = snapshot.data!;
                          filteredUsers = allUsers;
                        }
                        return SizedBox(
                          height: 300,
                          width: 300,
                          child: ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return ListTile(
                                title: Text(user.name),
                                subtitle: Text(user.id == currentAttendee.userId
                                    ? 'Current Attendee'
                                    : ''),
                                onTap: () {
                                  if (user.id != currentAttendee.userId) {
                                    _swapAttendee(currentAttendee, user);
                                    Navigator.of(context).pop();
                                  }
                                },
                              );
                            },
                          ),
                        );
                      }
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
              ],
            );
          },
        );
      },
    );
  }

  Future<List<UserProfile>> _fetchAllUsers() async {
    final societyId =
        Provider.of<SocietyProvider>(context, listen: false).currentSociety?.id;

    final response = await supabase
        .from('profiles')
        .select('user_id, name')
        .eq('society_id', societyId ?? 0)
        .order('name');

    return (response as List)
        .map((user) => UserProfile(
              id: user['user_id'],
              name: user['name'],
              completedHours: [], // You might want to fetch this information separately if needed
            ))
        .toList();
  }

  Future<void> _swapAttendee(
      Attendee currentAttendee, UserProfile newUser) async {
    try {
      // Remove the current attendee
      await supabase
          .from('Attendees')
          .delete()
          .eq('id', currentAttendee.id);

      // Add the new attendee
      final response = await supabase
          .from('Attendees')
          .insert({
            'timeslot_id': currentAttendee.timeSlotId,
            'user_id': newUser.id,
            'is_present': false,
            'forms_completed': false,
          })
          .select()
          .single();

      // Create a new Attendee object with the response data
      final newAttendee = Attendee(
        id: response['id'],
        timeSlotId: response['timeslot_id'],
        userId: response['user_id'],
        name: newUser.name,
        isPresent: response['is_present'],
        formsCompleted: response['forms_completed'],
      );

      // Update the UI
      setState(() {
        final timeSlotIndex = widget.event.timeSlots
            .indexWhere((ts) => ts.id == currentAttendee.timeSlotId);
        if (timeSlotIndex != -1) {
          final attendeeIndex = widget.event.timeSlots[timeSlotIndex].attendees
              .indexWhere((a) => a.id == currentAttendee.id);
          if (attendeeIndex != -1) {
            widget.event.timeSlots[timeSlotIndex].attendees[attendeeIndex] =
                newAttendee;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendee swapped successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error swapping attendee: $e')),
      );
    }
    refreshAttendeeList();
  }

  void refreshAttendeeList() {
    setState(() {
      _allAttendees = widget.event.timeSlots
          .expand((timeSlot) => timeSlot.attendees)
          .toList();
      _presentAttendees =
          _allAttendees.where((attendee) => attendee.isPresent).toList();
      _absentAttendees =
          _allAttendees.where((attendee) => !attendee.isPresent).toList();
    });
  }

  @override
  void didUpdateWidget(AttendanceCheckPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event != widget.event) {
      refreshAttendeeList();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is a mandatory or meeting event
    final shouldShowSyncButton = widget.event.isMandatory ||
        widget.event.type.toLowerCase() == 'meeting';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        title: Text(
          'Attendance: ${widget.event.name}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          if (shouldShowSyncButton)
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync),
              tooltip: 'Sync All Members',
              onPressed: _isSyncing ? null : _syncAllMembers,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mark Present'),
            Tab(text: 'Mark Absent'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Padding(
                  padding: AppDesign.paddingSmall,
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search Attendees',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAttendeeList(
                          _getFilteredAttendees(_absentAttendees), true),
                      _buildAttendeeList(
                          _getFilteredAttendees(_presentAttendees), false),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : _saveAttendance,
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.save),
      ),
    );
  }

  /// Creates a list view of attendees with attendance marking controls.
  ///
  /// Parameters:
  /// - attendees: List<Attendee> - Attendees to display
  /// - markPresent: bool - Whether list is for marking presence
  ///
  /// Returns:
  /// - Widget
  Widget _buildAttendeeList(List<Attendee> attendees, bool markPresent) {
    return ListView.builder(
      itemCount: attendees.length,
      itemBuilder: (context, index) {
        final attendee = attendees[index];
        return CheckboxListTile(
          title: Text(attendee.name),
          value: markPresent ? attendee.isPresent : !attendee.isPresent,
          onChanged: (bool? value) {
            setState(() {
              attendee.isPresent = markPresent ? value! : !value!;
            });
          },
          secondary: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => _showSwapDialog(attendee),
              ),
              if (widget.event.requiresForms)
                IconButton(
                  icon: Icon(attendee.formsCompleted
                      ? Icons.inventory
                      : Icons.pending_actions),
                  onPressed: () {
                    final hapticsProvider =
                        Provider.of<HapticsProvider>(context, listen: false);
                    hapticsProvider.selection();
                    _toggleFormCompletionStatus(attendee);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _toggleFormCompletionStatus(Attendee attendee) async {
    try {
      await supabase.from('Attendees').update(
          {'forms_completed': !attendee.formsCompleted}).eq('id', attendee.id);

      setState(() {
        attendee.formsCompleted = !attendee.formsCompleted;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Form status updated for ${attendee.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating form status: $e')),
      );
    }
  }
}
