import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:intl/intl.dart';
import '../providers/societyprovider.dart';
import '../common/app_design.dart';
import 'dart:ui';
import '../models/activitylog.dart';
import '../providers/hapticsprovider.dart';

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
          _buildDateSelector(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(),
                  )
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

  // In activitylogpage.dart - Replace the date selection UI
// Create a new expressive date selector component
  Widget _buildDateSelector() {
    final now = DateTime.now();
    final isCurrentDate = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final weekday = DateFormat('EEEE').format(_selectedDate);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              children: [
                // Date display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weekday,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMMM d, y').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (isCurrentDate)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Date controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Previous day button
                    _buildDateButton(
                      icon: Icons.chevron_left,
                      onPressed: () {
                        final hapticsProvider = Provider.of<HapticsProvider>(
                            context,
                            listen: false);
                        hapticsProvider.selection();
                        setState(() {
                          _selectedDate =
                              _selectedDate.subtract(const Duration(days: 1));
                        });
                        _fetchLogs();
                      },
                    ),

                    // Calendar button
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final hapticsProvider = Provider.of<HapticsProvider>(
                              context,
                              listen: false);
                          hapticsProvider.selection();
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary:
                                        Theme.of(context).colorScheme.primary,
                                    onPrimary:
                                        Theme.of(context).colorScheme.onPrimary,
                                    surface:
                                        Theme.of(context).colorScheme.surface,
                                    onSurface:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  dialogBackgroundColor:
                                      Theme.of(context).colorScheme.surface,
                                  dialogTheme: DialogThemeData(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );

                          if (picked != null && picked != _selectedDate) {
                            setState(() {
                              _selectedDate = picked;
                            });
                            _fetchLogs();
                          }
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Select Date'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),

                    // Next day button (disabled if current date)
                    _buildDateButton(
                      icon: Icons.chevron_right,
                      onPressed: isCurrentDate
                          ? null
                          : () {
                              setState(() {
                                _selectedDate =
                                    _selectedDate.add(const Duration(days: 1));
                              });
                              _fetchLogs();
                            },
                      disabled: isCurrentDate,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool disabled = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: disabled
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: disabled
            ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.3)
            : Theme.of(context).colorScheme.onPrimaryContainer,
        iconSize: 28,
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
      case 'continuous_submission_approved':
        iconData = Icons.verified;
        iconColor = Colors.green;
        actionText = 'submitted ongoing hours for';
        break;
      case 'continuous_submission_rejected':
        iconData = Icons.cancel;
        iconColor = Colors.red;
        actionText = 'submission rejected for';
        break;
      case 'continuous_submission_undone':
        iconData = Icons.undo;
        iconColor = Colors.orange;
        actionText = 'review undone for';
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
            if (log.timeslot.isNotEmpty) Text('Time: ${log.timeslot}'),
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
