import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:intl/intl.dart';
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import '../models/activitylog.dart';

final supabase = Supabase.instance.client;

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  _ActivityLogPageState createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  DateTime _selectedDate = DateTime.now();
  List<ActivityLog> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final societyId = Provider.of<SocietyProvider>(context, listen: false)
          .currentSociety
          ?.id;
      if (societyId == null) {
        setState(() {
          _logs = [];
          _isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('activity_logs')
          .select('*, profiles:user_id(name)')
          .eq('society_id', societyId) // Filter by current society
          .gte(
              'created_at',
              DateTime(_selectedDate.year, _selectedDate.month,
                      _selectedDate.day)
                  .toIso8601String())
          .lte(
              'created_at',
              DateTime(_selectedDate.year, _selectedDate.month,
                      _selectedDate.day, 23, 59, 59)
                  .toIso8601String())
          .order('created_at', ascending: false);

      setState(() {
        _logs = response
            .map<ActivityLog>((log) => ActivityLog.fromJson(log))
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching logs: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: AppDesign.paddingMedium,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: AppDesign.borderXLarge,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Previous Day Button
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedDate =
                              _selectedDate.subtract(const Duration(days: 1));
                        });
                        _fetchLogs();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2025),
                        );
                        if (picked != null && picked != _selectedDate) {
                          setState(() {
                            _selectedDate = picked;
                          });
                          _fetchLogs();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMMM d, y').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    // Next Day Button
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _selectedDate.year == DateTime.now().year &&
                              _selectedDate.month == DateTime.now().month &&
                              _selectedDate.day == DateTime.now().day
                          ? null
                          : () {
                              setState(() {
                                _selectedDate =
                                    _selectedDate.add(const Duration(days: 1));
                              });
                              _fetchLogs();
                            },
                      // Gray out the icon when on current day
                      color: _selectedDate.year == DateTime.now().year &&
                              _selectedDate.month == DateTime.now().month &&
                              _selectedDate.day == DateTime.now().day
                          ? Colors.grey
                          : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Text(
                          'No activity for this date',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return _buildLogCard(log);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// Creates a card widget displaying activity log entry.
  ///
  /// Parameters:
  /// - log: ActivityLog - Log entry to display
  ///
  /// Returns:
  /// - Widget
  Widget _buildLogCard(ActivityLog log) {
    IconData iconData;
    Color iconColor;
    String actionText;

    switch (log.actionType) {
      case 'signup':
        iconData = Icons.person_add;
        iconColor = Colors.green;
        actionText = 'signed up for';
        break;
      case 'unsignup':
        iconData = Icons.person_remove;
        iconColor = Colors.red;
        actionText = 'removed from';
        break;
      case 'swap':
        iconData = Icons.swap_horiz;
        iconColor = Colors.orange;
        actionText = 'swapped for';
        break;
      case 'attendance_marked':
        iconData = Icons.check_box;
        iconColor = const Color.fromARGB(255, 53, 99, 1);
        actionText = 'marked attended for';
        break;
      case 'attendance_removed':
        iconData = Icons.check_box_outline_blank;
        iconColor = Color.fromARGB(255, 99, 24, 1);
        actionText = 'attendance removed for';
        break;
      case 'manual_addition':
        iconData = Icons.add_box;
        iconColor = Colors.purple;
        actionText = 'marked for manual event:';
        break;
      case 'manual_deletion':
        iconData = Icons.disabled_by_default;
        iconColor = Colors.red;
        actionText = 'removed from manual event:';
        break;

      default:
        iconData = Icons.info;
        iconColor = Colors.grey;
        actionText = 'modified';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(iconData, color: iconColor),
        ),
        title: RichText(
          text: TextSpan(
            style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSecondaryContainer),
            children: [
              TextSpan(
                text: log.userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: ' $actionText '),
              TextSpan(
                text: log.eventName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: ${log.timeslot}'),
            Text('Hours: ${log.hours}'),
            if (log.actionType == 'swap')
              Text('Swapped with: ${log.newUserName ?? 'Unknown'}'),
            Text('Time: ${DateFormat('h:mm a').format(log.createdAt)}'),
          ],
        ),
      ),
    );
  }
}
