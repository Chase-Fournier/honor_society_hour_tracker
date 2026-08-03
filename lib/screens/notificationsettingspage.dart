import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/app_design.dart';
import '../providers/hapticsprovider.dart';
import '../providers/notificationsprovider.dart';
import '../providers/societyprovider.dart';
import '../services/notification_service.dart';
import '../data/supabase_client.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  static const _reminderChoices = <int>[15, 30, 60, 120, 1440];

  // Toggling the master switch on iOS can block for several seconds while
  // we wait for the APNS token (see FirebaseMessagingService._waitForApnsToken),
  // so we show a spinner and disable the switch while the request is in flight.
  bool _togglingEnabled = false;

  String _reminderLabel(int minutes) {
    if (minutes < 60) return '$minutes minutes before';
    if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return '$hours hour${hours == 1 ? '' : 's'} before';
    }
    final days = minutes ~/ 1440;
    return '$days day${days == 1 ? '' : 's'} before';
  }

  // Flat, hairline-bordered card matching the Profile page's cards.
  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry padding = AppDesign.paddingMedium,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppDesign.borderLarge,
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  // Section title matching the Profile page (20px, bold, primary).
  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationsProvider>();
    final haptics = context.read<HapticsProvider>();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).bannerTheme.backgroundColor,
        scrolledUnderElevation: AppDesign.elevationSmall,
        centerTitle: true,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: AppDesign.paddingMedium,
        children: [
          // Master toggle
          _buildCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Notifications'),
              subtitle: const Text(
                  'Allow Wheeler NHS to send reminders and updates.'),
              secondary: _togglingEnabled
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.notifications_active_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              value: notifications.enabled,
              onChanged: _togglingEnabled
                  ? null
                  : (value) async {
                      haptics.selection();
                      setState(() => _togglingEnabled = true);
                      try {
                        final ok = await notifications.setEnabled(value);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Notification permission denied. Enable it in system settings.'),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _togglingEnabled = false);
                        }
                      }
                    },
            ),
          ),
          const SizedBox(height: AppDesign.spacingL),
          AbsorbPointer(
            absorbing: !notifications.enabled,
            child: Opacity(
              opacity: notifications.enabled ? 1.0 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader('What to notify me about'),
                        const SizedBox(height: AppDesign.spacingS),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Event reminders'),
                          subtitle:
                              const Text('Before time slots you signed up for'),
                          secondary: Icon(
                            Icons.event_available,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          value: notifications.eventReminders,
                          onChanged: (v) {
                            haptics.selection();
                            notifications.setEventReminders(v);
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('New meeting notes'),
                          subtitle: const Text('When an admin posts notes'),
                          secondary: Icon(
                            Icons.sticky_note_2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          value: notifications.meetingNotes,
                          onChanged: (v) {
                            haptics.selection();
                            notifications.setMeetingNotes(v);
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Hours updated by admin'),
                          subtitle: const Text(
                              'Attendance marked or hours adjusted'),
                          secondary: Icon(
                            Icons.timer,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          value: notifications.hourUpdates,
                          onChanged: (v) {
                            haptics.selection();
                            notifications.setHourUpdates(v);
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Swap requests'),
                          subtitle: const Text(
                              'When a swap involves you or you accept/decline'),
                          secondary: Icon(
                            Icons.swap_horiz,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          value: notifications.swapRequests,
                          onChanged: (v) {
                            haptics.selection();
                            notifications.setSwapRequests(v);
                          },
                        ),
                        // Admin-only: server-side preference for the
                        // "hours submitted for review" push.
                        if (context.watch<SocietyProvider>().isAdmin)
                          const _AdminSubmissionNotifyTile(),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDesign.spacingL),
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader('Event reminder timing'),
                        const SizedBox(height: AppDesign.spacingS),
                        for (final minutes in _reminderChoices)
                          RadioListTile<int>(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_reminderLabel(minutes)),
                            value: minutes,
                            groupValue: notifications.reminderMinutesBefore,
                            onChanged: (v) {
                              if (v == null) return;
                              haptics.selection();
                              notifications.setReminderMinutesBefore(v);
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDesign.spacingL),
                  _buildCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.send,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Send a test notification'),
                      subtitle: const Text(
                          'Useful to confirm everything is working.'),
                      onTap: () async {
                        haptics.selection();
                        await NotificationService.instance.showLocal(
                          id: 99999,
                          title: 'Test notification',
                          body: 'If you see this, notifications are working.',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Admin-only toggle for the "hours submitted for review" push. Backed by
/// user_society_memberships.notify_continuous_submissions for the current
/// society, so toggling it actually stops the server from sending the push.
class _AdminSubmissionNotifyTile extends StatefulWidget {
  const _AdminSubmissionNotifyTile();

  @override
  State<_AdminSubmissionNotifyTile> createState() =>
      _AdminSubmissionNotifyTileState();
}

class _AdminSubmissionNotifyTileState
    extends State<_AdminSubmissionNotifyTile> {
  bool _value = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = supabase.auth.currentUser?.id;
    final societyId = context.read<SocietyProvider>().currentSociety?.id;
    if (userId == null || societyId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final row = await supabase
          .from('user_society_memberships')
          .select('notify_continuous_submissions')
          .eq('user_id', userId)
          .eq('society_id', societyId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _value = (row?['notify_continuous_submissions'] as bool?) ?? true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _set(bool v) async {
    final userId = supabase.auth.currentUser?.id;
    final societyId = context.read<SocietyProvider>().currentSociety?.id;
    if (userId == null || societyId == null) return;

    context.read<HapticsProvider>().selection();
    setState(() => _value = v);
    try {
      await supabase
          .from('user_society_memberships')
          .update({'notify_continuous_submissions': v})
          .eq('user_id', userId)
          .eq('society_id', societyId);
    } catch (e) {
      if (mounted) {
        setState(() => _value = !v); // revert on failure
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update preference: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Ongoing event submissions'),
      subtitle: const Text(
          'When a member submits hours for review (admins only)'),
      secondary: Icon(
        Icons.assignment_turned_in,
        color: Theme.of(context).colorScheme.primary,
      ),
      value: _value,
      onChanged: _loading ? null : _set,
    );
  }
}
